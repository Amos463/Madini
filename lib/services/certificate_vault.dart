import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

class EncryptedCertificate {
  const EncryptedCertificate({required this.id, required this.path, required this.sha256});
  final String id;
  final String path;
  final String sha256;
}

/// Stores certificate files encrypted (AES-256-GCM) in app-private storage.
/// File keys are derived (HKDF) from the random SQLCipher key held in secure
/// storage. This class only handles files; database rows are written by
/// LocalDatabase.saveBundle inside one transaction.
class CertificateVault {
  static const _storage = FlutterSecureStorage();
  static const _keyName = 'madini_sqlcipher_key_v1';
  static const _headerText = 'MADINI-CERT-1\n';
  static final _aes = AesGcm.with256bits();
  static final _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

  static Future<SecretKey> _certificateKey() async {
    final storedKey = await _storage.read(key: _keyName);
    if (storedKey == null || storedKey.length != 64) {
      throw StateError('Ufunguo salama wa database haupatikani.');
    }
    final keyBytes = <int>[];
    for (var i = 0; i < storedKey.length; i += 2) {
      keyBytes.add(int.parse(storedKey.substring(i, i + 2), radix: 16));
    }
    return _hkdf.deriveKey(
      secretKey: SecretKey(keyBytes),
      nonce: const <int>[],
      info: utf8.encode('MADINI-CERTIFICATE-VAULT-V1'),
    );
  }

  static Future<Directory> _directory() async {
    final dir = await getApplicationSupportDirectory();
    final target = Directory('${dir.path}/certificates');
    await target.create(recursive: true);
    return target;
  }

  static String _hex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  static Future<String> sha256Hex(Uint8List bytes) async =>
      _hex((await Sha256().hash(bytes)).bytes);

  /// Husimba [bytes] na kuviandika kwenye faili. Haigusi database; mwitaji
  /// ana wajibu wa kufuta faili (`deleteFile`) kama muamala wa DB ukishindwa.
  static Future<EncryptedCertificate> encryptToFile(Uint8List bytes, {String? id}) async {
    if (bytes.isEmpty) throw ArgumentError('Faili la cheti halina maudhui.');
    final key = await _certificateKey();
    final random = Random.secure();
    final nonce = List<int>.generate(12, (_) => random.nextInt(256));
    final box = await _aes.encrypt(bytes, secretKey: key, nonce: nonce);
    final envelope = Uint8List.fromList([
      ...utf8.encode(_headerText),
      ...nonce,
      ...box.mac.bytes,
      ...box.cipherText,
    ]);
    final dir = await _directory();
    final fileId = id ??
        '${DateTime.now().microsecondsSinceEpoch}${random.nextInt(1 << 20)}';
    final target = File('${dir.path}/$fileId.mcert');
    await target.writeAsBytes(envelope, flush: true);
    return EncryptedCertificate(
        id: fileId, path: target.path, sha256: await sha256Hex(bytes));
  }

  static Future<void> deleteFile(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  static Future<Uint8List> decryptFile(String path) async {
    final bytes = await File(path).readAsBytes();
    final header = utf8.encode(_headerText);
    if (bytes.length < header.length + 12 + 16) {
      throw const FormatException('Faili la cheti lililosimbwa si sahihi.');
    }
    for (var i = 0; i < header.length; i++) {
      if (bytes[i] != header[i]) {
        throw const FormatException('Faili la cheti lililosimbwa si sahihi.');
      }
    }
    final offset = header.length;
    final nonce = bytes.sublist(offset, offset + 12);
    final mac = Mac(bytes.sublist(offset + 12, offset + 28));
    final ciphertext = bytes.sublist(offset + 28);
    final key = await _certificateKey();
    try {
      return Uint8List.fromList(await _aes.decrypt(
          SecretBox(ciphertext, nonce: nonce, mac: mac),
          secretKey: key));
    } on SecretBoxAuthenticationError {
      throw const FormatException('Cheti kimeharibika au kimebadilishwa.');
    }
  }
}
