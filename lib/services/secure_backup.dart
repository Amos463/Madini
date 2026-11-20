import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'certificate_vault.dart';
import 'local_database.dart';

class BackupCreated {
  const BackupCreated(this.bytes, this.includedCertificates, this.excludedCertificates);
  final Uint8List bytes;
  final int includedCertificates;
  final int excludedCertificates;
}

class BackupRestored {
  const BackupRestored(this.assessments, this.certificates);
  final int assessments;
  final int certificates;
}

class BackupVerified {
  const BackupVerified(this.assessments, this.certificates, this.createdAt);
  final int assessments;
  final int certificates;
  final String? createdAt;
}

/// Portable passphrase-encrypted backup (v2). PBKDF2-HMAC-SHA256 derives an
/// AES-256-GCM key; authentication failure stops restore before any write.
/// v2 includes assessments, assay samples, price records and certificate files
/// (up to [maxCertificateBytes] in total; the rest are reported as excluded).
class SecureBackup {
  static const _formatV1 = 'MADINI-ENCRYPTED-BACKUP-1';
  static const _formatV2 = 'MADINI-ENCRYPTED-BACKUP-2';
  static const _iterations = 310000;
  static const maxCertificateBytes = 30 * 1024 * 1024;
  static const maxBackupFileBytes = 120 * 1024 * 1024;
  static final _pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: _iterations,
    bits: 256,
  );
  static final _aes = AesGcm.with256bits();

  /// [includeCertificates] = false huunda backup NYEPESI (rekodi, assay, bei na
  /// audit tu; bila faili za vyeti): matumizi madogo ya kumbukumbu, inafaa
  /// simu zenye RAM ndogo. Vyeti vitahitaji kuambatishwa upya.
  static Future<BackupCreated> create(String passphrase, {bool includeCertificates = true}) async {
    final weak = passphraseProblem(passphrase);
    if (weak != null) throw ArgumentError(weak);
    final db = LocalDatabase.instance;
    final assessments = await db.exportAssessmentRows();
    final samples = await db.exportAssaySamples();
    final prices = await db.exportPriceRecords();
    final certRows = includeCertificates
        ? await db.exportCertificateRows()
        : const <Map<String, Object?>>[];
    final audit = await db.exportAuditEvents();

    final certs = <Map<String, Object?>>[];
    var total = 0;
    var excluded = 0;
    for (final row in certRows) {
      try {
        // Angalia ukubwa wa faili LILILOSIMBWA kabla ya kulisoma/kulifungua ili
        // vyeti vikubwa visijaze kumbukumbu bila sababu.
        final onDisk = await File(row['private_path'] as String).length();
        if (total + onDisk > maxCertificateBytes + 64) {
          excluded++;
          continue;
        }
        final clear = await CertificateVault.decryptFile(row['private_path'] as String);
        if (total + clear.length > maxCertificateBytes) {
          excluded++;
          continue;
        }
        total += clear.length;
        certs.add({
          'id': row['id'],
          'assessment_id': row['assessment_id'],
          'sample_code': row['sample_code'],
          'file_name': row['file_name'],
          'sha256': row['sha256'],
          'added_at': row['added_at'],
          'dataBase64': base64Encode(clear),
        });
      } catch (_) {
        excluded++;
      }
    }

    final payload = jsonEncode({
      'format': _formatV2,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'assessments': assessments,
      'assaySamples': samples,
      'priceRecords': prices,
      'auditEvents': audit,
      'certificates': certs,
      'excludedCertificates': excluded,
    });
    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    final nonce = List<int>.generate(12, (_) => random.nextInt(256));
    final key = await _pbkdf2.deriveKey(
        secretKey: SecretKey(utf8.encode(passphrase)), nonce: salt);
    final box = await _aes.encrypt(utf8.encode(payload), secretKey: key, nonce: nonce);
    final envelope = {
      'format': _formatV2,
      'kdf': 'PBKDF2-HMAC-SHA256',
      'iterations': _iterations,
      'cipher': 'AES-256-GCM',
      'salt': base64Encode(salt),
      'nonce': base64Encode(nonce),
      'ciphertext': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
    };
    final output = Uint8List.fromList(utf8.encode(jsonEncode(envelope)));
    if (output.length > maxBackupFileBytes) {
      throw StateError(
          'Backup imezidi kikomo cha 120 MB. Tengeneza backup bila vyeti au gawanya data kwa mafungu.');
    }
    return BackupCreated(output, certs.length, excluded);
  }

  /// Hufungua na kuthibitisha (MAC) bila kuandika chochote.
  static Future<({String format, Map<String, dynamic> payload})> _open(
      Uint8List bytes, String passphrase) async {
    if (passphrase.isEmpty) {
      throw ArgumentError('Weka nenosiri la backup.');
    }
    if (bytes.isEmpty || bytes.length > maxBackupFileBytes) {
      throw const FormatException('Ukubwa wa backup si sahihi (kikomo ni 120 MB).');
    }
    final Map<String, dynamic> envelope;
    try {
      envelope = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    } catch (_) {
      throw const FormatException('Faili si backup ya MADINI inayotambulika.');
    }
    final format = envelope['format'];
    if ((format != _formatV1 && format != _formatV2) ||
        envelope['kdf'] != 'PBKDF2-HMAC-SHA256' ||
        envelope['iterations'] != _iterations ||
        envelope['cipher'] != 'AES-256-GCM') {
      throw const FormatException('Aina/version ya backup haitumiki.');
    }
    try {
      final salt = base64Decode(envelope['salt'] as String);
      final nonce = base64Decode(envelope['nonce'] as String);
      final ciphertext = base64Decode(envelope['ciphertext'] as String);
      final macBytes = base64Decode(envelope['mac'] as String);
      if (salt.length != 16 ||
          nonce.length != 12 ||
          macBytes.length != 16 ||
          ciphertext.length > 120 * 1024 * 1024) {
        throw const FormatException('Vipimo vya backup si sahihi.');
      }
      final key = await _pbkdf2.deriveKey(
          secretKey: SecretKey(utf8.encode(passphrase)), nonce: salt);
      final clear = await _aes.decrypt(
          SecretBox(ciphertext, nonce: nonce, mac: Mac(macBytes)),
          secretKey: key);
      final payload = jsonDecode(utf8.decode(clear)) as Map<String, dynamic>;
      if (payload['format'] != format || payload['assessments'] is! List) {
        throw const FormatException('Maudhui ya backup si sahihi.');
      }
      return (format: format as String, payload: payload);
    } on SecretBoxAuthenticationError {
      throw const FormatException('Nenosiri si sahihi au backup imebadilishwa.');
    } on FormatException {
      rethrow;
    } catch (e) {
      throw FormatException('Backup haiwezi kusomwa: $e');
    }
  }

  /// Hakiki backup (nenosiri + uadilifu) bila kuirejesha. Tumia mara tu baada
  /// ya kuunda backup ili kuhakikisha itafunguka siku ya dharura.
  static Future<BackupVerified> verify(Uint8List bytes, String passphrase) async {
    final opened = await _open(bytes, passphrase);
    final payload = opened.payload;
    final certs = payload['certificates'] is List ? (payload['certificates'] as List).length : 0;
    return BackupVerified((payload['assessments'] as List).length, certs,
        payload['createdAt'] as String?);
  }

  static Future<BackupRestored> restore(Uint8List bytes, String passphrase) async {
    final opened = await _open(bytes, passphrase);
    final payload = opened.payload;
    final written = <String>[];
    try {
      List<Map<String, Object?>> listOf(String name) {
        final raw = payload[name];
        if (raw == null) return <Map<String, Object?>>[];
        if (raw is! List) throw FormatException('Sehemu ya $name si orodha sahihi.');
        return raw.map((item) {
          if (item is! Map) throw FormatException('Kuna rekodi isiyo sahihi kwenye $name.');
          return Map<String, Object?>.from(item);
        }).toList();
      }

      final assessments = listOf('assessments');
      final assessmentIds = <String>{};
      for (final row in assessments) {
        final id = row['id'];
        final rawValues = row['values'] ?? row['values_json'];
        if (id is! String || id.trim().isEmpty || !assessmentIds.add(id) ||
            rawValues is! String || row['result'] is! String) {
          throw const FormatException('Kuna assessment yenye ID inayojirudia au muundo usio sahihi.');
        }
        try {
          final values = jsonDecode(rawValues);
          final result = jsonDecode(row['result'] as String);
          if (values is! Map || result is! Map) {
            throw const FormatException('Values/result za assessment lazima ziwe objects.');
          }
        } catch (_) {
          throw const FormatException('Values au result ya assessment imeharibika.');
        }
      }

      final samples = listOf('assaySamples');
      final sampleIds = <String>{};
      for (final sample in samples) {
        final id = sample['id'];
        final assessmentId = sample['assessment_id'];
        final grade = sample['grade_gpt'];
        if (id is! String || id.trim().isEmpty || !sampleIds.add(id) ||
            assessmentId is! String || !assessmentIds.contains(assessmentId) ||
            sample['sample_code'] is! String || grade is! num ||
            !grade.toDouble().isFinite || grade < 0) {
          throw const FormatException('Kuna assay sample yenye ID inayojirudia, grade batili au assessment isiyokuwepo.');
        }
      }

      final prices = listOf('priceRecords');
      final priceIds = <String>{};
      for (final price in prices) {
        final id = price['id'];
        final amount = price['price_tzs_g'];
        if (id is! String || id.trim().isEmpty || !priceIds.add(id) ||
            amount is! num || !amount.toDouble().isFinite || amount <= 0 ||
            price['source'] is! String || (price['source'] as String).trim().isEmpty ||
            price['recorded_at'] is! String || (price['recorded_at'] as String).trim().isEmpty) {
          throw const FormatException('Kuna rekodi ya bei yenye ID au thamani isiyo sahihi.');
        }
      }

      final auditEvents = listOf('auditEvents');
      for (final event in auditEvents) {
        if (event['entity_type'] is! String || event['entity_id'] is! String ||
            event['action'] is! String || event['occurred_at'] is! String) {
          throw const FormatException('Kuna audit event isiyo sahihi ndani ya backup.');
        }
      }

      // Rejesha faili za vyeti (zisizokuwepo) kabla ya muamala wa DB.
      final existing = await LocalDatabase.instance.existingCertificateIds();
      final certRows = <Map<String, Object?>>[];
      final certificateIds = <String>{};
      var restoredCertificateBytes = 0;
      for (final c in listOf('certificates')) {
        final id = c['id'];
        final aid = c['assessment_id'];
        final data = c['dataBase64'];
        final fileName = c['file_name'];
        final expectedDigest = c['sha256'];
        if (id is! String || aid is! String || data is! String ||
            fileName is! String || fileName.trim().isEmpty ||
            expectedDigest is! String ||
            !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(expectedDigest)) {
          throw const FormatException('Kuna cheti kisicho na taarifa zote muhimu ndani ya backup.');
        }
        if (!RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(id) ||
            !certificateIds.add(id) || !assessmentIds.contains(aid)) {
          throw const FormatException('ID ya cheti inajirudia au assessment yake haipo.');
        }
        if (data.length > ((maxCertificateBytes * 4 / 3).ceil() + 8)) {
          throw const FormatException('Cheti kimoja kimezidi kikomo cha ukubwa.');
        }
        final clearBytes = base64Decode(data);
        restoredCertificateBytes += clearBytes.length;
        if (clearBytes.isEmpty || restoredCertificateBytes > maxCertificateBytes) {
          throw const FormatException('Vyeti kwenye backup vimezidi kikomo cha jumla cha 30 MB.');
        }
        final clear = Uint8List.fromList(clearBytes);
        final digest = await CertificateVault.sha256Hex(clear);
        if (expectedDigest.toLowerCase() != digest.toLowerCase()) {
          throw const FormatException('Cheti kwenye backup kimeharibika (sha256 hailingani).');
        }
        if (existing.contains(id)) continue;
        final enc = await CertificateVault.encryptToFile(clear, id: id);
        written.add(enc.path);
        certRows.add({...c, 'private_path': enc.path, 'sha256': digest});
      }

      final count = await LocalDatabase.instance.importBackup(
        assessments: assessments,
        samples: samples,
        prices: prices,
        certificates: certRows,
        auditEvents: auditEvents,
      );
      return BackupRestored(count, certRows.length);
    } on FormatException {
      for (final p in written) {
        await CertificateVault.deleteFile(p);
      }
      rethrow;
    } catch (e) {
      for (final p in written) {
        await CertificateVault.deleteFile(p);
      }
      throw FormatException('Backup haikuweza kurejeshwa: $e');
    }
  }

  /// Hurudisha maelezo ya tatizo la nenosiri, au null kama linakubalika.
  /// Sheria: angalau herufi 12, angalau herufi 6 tofauti, si tarakimu tupu,
  /// na aina 2+ za herufi (ndogo/kubwa/tarakimu/alama) AU urefu >= 20 (sentensi).
  static String? passphraseProblem(String passphrase) {
    if (passphrase.length < 12) {
      return 'Tumia nenosiri la backup lenye angalau herufi 12.';
    }
    if (passphrase.split('').toSet().length < 6) {
      return 'Nenosiri lina herufi zinazojirudia sana; tumia herufi tofauti zaidi.';
    }
    if (RegExp(r'^\d+$').hasMatch(passphrase)) {
      return 'Nenosiri lisiwe tarakimu pekee.';
    }
    final classes = [
      RegExp(r'[a-z]'),
      RegExp(r'[A-Z]'),
      RegExp(r'\d'),
      RegExp(r'[^A-Za-z0-9]'),
    ].where((r) => r.hasMatch(passphrase)).length;
    if (classes < 2 && passphrase.length < 20) {
      return 'Changanya angalau aina mbili za herufi (ndogo/kubwa/tarakimu/alama) au tumia sentensi ndefu (herufi 20+).';
    }
    return null;
  }
}
