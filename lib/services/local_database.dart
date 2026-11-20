import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' as cipher;

import '../domain/gold_assessment.dart';
import 'orphan_sweep.dart';

/// Hutupwa wakati database ipo lakini ufunguo wake haupo (mf. simu mpya au
/// data ya Keystore imefutwa). Data HAIFUTWI kimya kimya.
class DatabaseKeyLostException implements Exception {
  DatabaseKeyLostException(this.detail);
  final String detail;
  @override
  String toString() =>
      'Database ipo lakini ufunguo wake wa usalama haupo kwenye kifaa hiki. $detail';
}

/// Database imefunguka lakini ukaguzi wa uadilifu (PRAGMA quick_check) umeshindwa.
class DatabaseCorruptedException implements Exception {
  DatabaseCorruptedException(this.detail);
  final String detail;
  @override
  String toString() =>
      'Database imeharibika (ukaguzi wa uadilifu umeshindwa). $detail';
}

/// SQLCipher-backed local store. Random key lives in Keystore-backed secure
/// storage. Legacy plaintext v2 data is migrated once and verified.
class LocalDatabase {
  LocalDatabase._();
  static final LocalDatabase instance = LocalDatabase._();

  static const _storage = FlutterSecureStorage();
  static const _keyName = 'madini_sqlcipher_key_v1';

  cipher.Database? _database;
  Future<cipher.Database>? _opening;

  /// Huongezeka kila data inapobadilika; skrini husikiliza ili zijisasishe.
  final ValueNotifier<int> changes = ValueNotifier<int>(0);
  void _notify() => changes.value++;

  /// Wito wa pamoja: skrini nyingi zikiomba wakati mmoja, database inafunguliwa
  /// (na migration inaendeshwa) mara moja tu.
  Future<cipher.Database> get database async {
    _opening ??= _open();
    try {
      return await _opening!;
    } catch (_) {
      _opening = null;
      rethrow;
    }
  }

  Future<String> _dbPath() async => '${await cipher.getDatabasesPath()}/madini.db';

  static const _sidecars = ['-wal', '-shm', '-journal'];

  /// Husogeza faili za SQLite za pembeni (-wal/-shm/-journal) pamoja na
  /// database kuu; zikibaki kwenye njia ile ile zingeambatana na database
  /// mpya iliyosimbwa na kuiharibu.
  Future<void> _moveSidecars(String from, String to) async {
    for (final suffix in _sidecars) {
      final source = File('$from$suffix');
      if (await source.exists()) {
        final target = File('$to$suffix');
        if (await target.exists()) await target.delete();
        await source.rename(target.path);
      }
    }
  }

  Future<void> _deleteSidecars(String base) async {
    for (final suffix in _sidecars) {
      final f = File('$base$suffix');
      if (await f.exists()) {
        try {
          await f.delete();
        } catch (_) {}
      }
    }
  }

  Future<cipher.Database> _open() async {
    final path = await _dbPath();
    final file = File(path);
    final migrationBackup = File('$path.plaintext-migration-backup');
    var key = await _storage.read(key: _keyName);

    // Android ilikatisha app baada ya faili la legacy kuhamishwa lakini kabla
    // ya database iliyosimbwa kukamilika.
    if (!await file.exists() && await migrationBackup.exists()) {
      await migrationBackup.rename(path);
      await _moveSidecars(migrationBackup.path, path);
      await _storage.delete(key: _keyName);
      key = null;
    }

    if (key == null && await file.exists()) {
      final legacyRows = await _readLegacyOrThrow(path);
      if (await migrationBackup.exists()) await migrationBackup.delete();
      await _deleteSidecars(migrationBackup.path);
      await file.rename(migrationBackup.path);
      await _moveSidecars(path, migrationBackup.path);
      key = _newKey();
      cipher.Database? migratingDb;
      try {
        await _storage.write(key: _keyName, value: key);
        migratingDb = await _openEncrypted(path, key);
        for (final row in legacyRows) {
          final assessment = GoldAssessment.fromMap(row);
          await migratingDb.transaction((txn) => _upsertAssessment(txn, assessment));
        }
        final count = _firstInt(
                await migratingDb.rawQuery('SELECT COUNT(*) FROM assessments')) ??
            0;
        if (count != legacyRows.length) {
          throw StateError('Legacy migration verification failed.');
        }
        await _assertIntegrity(migratingDb);
        await migrationBackup.delete();
        await _deleteSidecars(migrationBackup.path);
        _database = migratingDb;
        return migratingDb;
      } catch (_) {
        await migratingDb?.close();
        _database = null;
        try {
          await File(path).delete();
        } catch (_) {}
        await _deleteSidecars(path);
        if (await migrationBackup.exists()) {
          await migrationBackup.rename(path);
          await _moveSidecars(migrationBackup.path, path);
        }
        await _storage.delete(key: _keyName);
        rethrow;
      }
    }

    if (key == null) {
      key = _newKey();
      await _storage.write(key: _keyName, value: key);
    }
    final opened = await _openEncrypted(path, key);
    try {
      await _assertIntegrity(opened);
    } catch (_) {
      await opened.close();
      _database = null;
      rethrow;
    }
    _database = opened;
    if (await migrationBackup.exists()) await migrationBackup.delete();
    await _deleteSidecars(migrationBackup.path);
    return _database!;
  }

  /// Ukaguzi wa haraka wa uadilifu kila database inapofunguliwa. Hauiharibu
  /// wala kuifuta database; ikishindwa, mtumiaji anaelekezwa kwenye backup.
  Future<void> _assertIntegrity(cipher.Database db) async {
    final rows = await db.rawQuery('PRAGMA quick_check');
    final first = rows.isEmpty ? null : rows.first.values.first;
    if (first != 'ok') {
      throw DatabaseCorruptedException('Maelezo: ${rows.take(3).map((r) => r.values.first).join('; ')}');
    }
    final foreignKeyErrors = await db.rawQuery('PRAGMA foreign_key_check');
    if (foreignKeyErrors.isNotEmpty) {
      throw DatabaseCorruptedException(
          'Foreign-key check imepata ${foreignKeyErrors.length} rekodi zisizo na uhusiano sahihi.');
    }
  }

  /// Futa mafaili ya vyeti yaliyosimbwa ambayo hayamo kwenye database (yatima),
  /// kwa sheria salama za `OrphanSweep` (jina la faili, umri wa saa 24+, kinga).
  Future<int> sweepOrphanCertificateFiles() async {
    final db = await database;
    final rows = await db.query('certificate_attachments', columns: ['private_path']);
    final known = rows.map((r) => r['private_path'] as String).toList();
    final dir = Directory('${(await getApplicationSupportDirectory()).path}/certificates');
    if (!await dir.exists()) return 0;
    final files = <String, DateTime>{};
    await for (final e in dir.list()) {
      if (e is! File) continue;
      try {
        files[e.path] = await e.lastModified();
      } catch (_) {}
    }
    // Uamuzi wote uko kwenye OrphanSweep.plan (jina la faili, umri, kinga).
    final toDelete = OrphanSweep.plan(files: files, knownPaths: known, now: DateTime.now());
    var deleted = 0;
    for (final path in toDelete) {
      try {
        await File(path).delete();
        deleted++;
      } catch (_) {}
    }
    return deleted;
  }

  String _newKey() {
    final random = Random.secure();
    return List<int>.generate(32, (_) => random.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  Future<List<Map<String, Object?>>> _readLegacyOrThrow(String path) async {
    cipher.Database? legacy;
    try {
      legacy = await cipher.openDatabase(path, readOnly: true);
      return await legacy.query('assessments');
    } catch (e) {
      throw DatabaseKeyLostException(
          'Si legacy database inayoweza kuhamishwa. Data haijafutwa. Sababu: $e');
    } finally {
      await legacy?.close();
    }
  }

  Future<cipher.Database> _openEncrypted(String path, String key) {
    return cipher.openDatabase(
      path,
      password: key,
      version: 5,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async => _createSchema(db),
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 5) await _migrateAssessmentsToV5(db);
        if (oldVersion < 3) await _createExtendedSchema(db);
        if (oldVersion < 4) {
          await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_assay_samples_assessment ON assay_samples(assessment_id)');
          await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_price_records_time ON gold_price_records(recorded_at DESC)');
        }
      },
    );
  }

  /// Database za zamani (v<5) zinaweza kuwa na safu `values` (neno la SQL
  /// lililohifadhiwa) badala ya `values_json`, au bila jedwali la FTS.
  Future<void> _migrateAssessmentsToV5(cipher.Database db) async {
    final cols = await db.rawQuery('PRAGMA table_info(assessments)');
    final names = cols.map((c) => c['name']).toSet();
    if (cols.isEmpty) {
      await db.execute('''CREATE TABLE IF NOT EXISTS assessments (
        id TEXT PRIMARY KEY, title TEXT, mode TEXT, assessmentType TEXT,
        createdAt TEXT, formulaVersion TEXT, values_json TEXT, result TEXT, notes TEXT
      )''');
    } else if (!names.contains('values_json')) {
      await db.execute('ALTER TABLE assessments ADD COLUMN values_json TEXT');
      if (names.contains('values')) {
        await db.execute('UPDATE assessments SET values_json = "values" WHERE values_json IS NULL');
      }
    }
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_assessments_created ON assessments(createdAt DESC)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_assessments_mode ON assessments(mode)');
    try {
      await db.execute('''CREATE VIRTUAL TABLE IF NOT EXISTS assessments_fts USING fts5(
        id UNINDEXED, title, notes, mode, content,
        tokenize = 'unicode61 remove_diacritics 2'
      )''');
      await db.execute('''INSERT INTO assessments_fts(rowid,id,title,notes,mode,content)
        SELECT rowid, id, title, ifnull(notes,''), mode,
               ifnull(title,'') || ' ' || ifnull(notes,'') || ' ' || ifnull(values_json,'') || ' ' || ifnull(result,'')
        FROM assessments WHERE id NOT IN (SELECT id FROM assessments_fts)''');
    } catch (_) {
      // LIKE search remains available on SQLite builds without FTS5.
    }
  }

  Future<void> _createSchema(cipher.Database db) async {
    // `values` ni neno lililohifadhiwa la SQL; safu inaitwa values_json.
    await db.execute('''CREATE TABLE assessments (
      id TEXT PRIMARY KEY, title TEXT, mode TEXT, assessmentType TEXT,
      createdAt TEXT, formulaVersion TEXT, values_json TEXT, result TEXT, notes TEXT
    )''');
    await db.execute('CREATE INDEX idx_assessments_created ON assessments(createdAt DESC)');
    await db.execute('CREATE INDEX idx_assessments_mode ON assessments(mode)');
    await _createExtendedSchema(db);
    try {
      await db.execute('''CREATE VIRTUAL TABLE assessments_fts USING fts5(
        id UNINDEXED, title, notes, mode, content,
        tokenize = 'unicode61 remove_diacritics 2'
      )''');
    } catch (_) {
      // LIKE search remains available on SQLite builds without FTS5.
    }
  }

  Future<void> _createExtendedSchema(cipher.Database db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS assay_samples (
      id TEXT PRIMARY KEY, assessment_id TEXT NOT NULL, sample_code TEXT NOT NULL,
      laboratory TEXT, certificate_number TEXT, grade_gpt REAL NOT NULL,
      sampled_at TEXT, created_at TEXT NOT NULL,
      FOREIGN KEY(assessment_id) REFERENCES assessments(id) ON DELETE CASCADE
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS gold_price_records (
      id TEXT PRIMARY KEY, price_tzs_g REAL NOT NULL, source TEXT NOT NULL,
      recorded_at TEXT NOT NULL, is_manual INTEGER NOT NULL DEFAULT 1,
      note TEXT
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS certificate_attachments (
      id TEXT PRIMARY KEY, assessment_id TEXT NOT NULL, sample_code TEXT,
      file_name TEXT NOT NULL, private_path TEXT NOT NULL, sha256 TEXT,
      added_at TEXT NOT NULL,
      FOREIGN KEY(assessment_id) REFERENCES assessments(id) ON DELETE CASCADE
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS audit_events (
      id INTEGER PRIMARY KEY AUTOINCREMENT, entity_type TEXT NOT NULL,
      entity_id TEXT NOT NULL, action TEXT NOT NULL, occurred_at TEXT NOT NULL,
      details TEXT
    )''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_assay_samples_assessment ON assay_samples(assessment_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_price_records_time ON gold_price_records(recorded_at DESC)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_audit_entity ON audit_events(entity_type, entity_id, occurred_at DESC)');
  }

  static int? _firstInt(List<Map<String, Object?>> rows) {
    if (rows.isEmpty) return null;
    final value = rows.first.values.first;
    return value is int ? value : (value as num?)?.toInt();
  }

  /// UPDATE kisha INSERT (si REPLACE): REPLACE ingefuta safu ya zamani na
  /// ON DELETE CASCADE ingefuta assay samples na vyeti vya rekodi hiyo.
  Future<void> _upsertAssessment(
      cipher.DatabaseExecutor ex, GoldAssessment assessment,
      {String action = 'created_or_updated', String? details}) async {
    final map = assessment.toDbMap();
    final updated = await ex.update('assessments', map,
        where: 'id = ?', whereArgs: [assessment.id]);
    if (updated == 0) await ex.insert('assessments', map);
    try {
      await ex.delete('assessments_fts', where: 'id = ?', whereArgs: [assessment.id]);
      final content = [
        assessment.title,
        assessment.mode,
        assessment.assessmentType,
        assessment.notes,
        jsonEncode(assessment.values),
        jsonEncode(assessment.result)
      ].join(' ');
      await ex.rawInsert(
        'INSERT INTO assessments_fts(rowid,id,title,notes,mode,content) VALUES ((SELECT rowid FROM assessments WHERE id=?),?,?,?,?,?)',
        [assessment.id, assessment.id, assessment.title, assessment.notes, assessment.mode, content],
      );
    } catch (_) {}
    await ex.insert('audit_events', {
      'entity_type': 'assessment',
      'entity_id': assessment.id,
      'action': action,
      'occurred_at': DateTime.now().toUtc().toIso8601String(),
      if (details != null) 'details': details,
    });
  }

  /// Huhifadhi assessment + assay samples + bei + metadata ya cheti KWA MUAMALA
  /// MMOJA: ama vyote vinaingia au hakuna kinachoingia.
  Future<void> saveBundle({
    required GoldAssessment assessment,
    List<Map<String, Object?>> samples = const [],
    Map<String, Object?>? priceRecord,
    Map<String, Object?>? certificate,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      await _upsertAssessment(txn, assessment);
      for (final sample in samples) {
        await txn.insert('assay_samples', {...sample, 'assessment_id': assessment.id});
      }
      if (priceRecord != null) await txn.insert('gold_price_records', priceRecord);
      if (certificate != null) {
        await txn.insert('certificate_attachments', {
          ...certificate,
          'assessment_id': assessment.id,
          'added_at': DateTime.now().toUtc().toIso8601String(),
        });
      }
    });
    _notify();
  }

  /// Huhifadhi matokeo halisi (na ulinganisho) kwenye rekodi iliyopo, kwa
  /// muamala mmoja, bila kugusa samples/vyeti. Audit inarekodi kitendo.
  Future<void> recordActualOutcome(GoldAssessment updated, {Map<String, dynamic>? auditDetails}) async {
    final db = await database;
    await db.transaction((txn) async {
      final exists = await txn.query('assessments',
          columns: ['id'], where: 'id = ?', whereArgs: [updated.id]);
      if (exists.isEmpty) throw StateError('Assessment haipo.');
      await _upsertAssessment(txn, updated,
          action: 'actual_outcome_recorded',
          details: auditDetails == null ? null : jsonEncode(auditDetails));
    });
    _notify();
  }

  /// Hufuta assessment (samples/vyeti-metadata hufutwa kwa cascade) kisha
  /// hufuta faili za vyeti zilizosimbwa ili zisibaki yatima.
  Future<void> deleteAssessment(String id) async {
    final db = await database;
    final certs = await db.query('certificate_attachments',
        columns: ['private_path'], where: 'assessment_id = ?', whereArgs: [id]);
    await db.transaction((txn) async {
      try {
        await txn.delete('assessments_fts', where: 'id = ?', whereArgs: [id]);
      } catch (_) {}
      await txn.delete('assessments', where: 'id = ?', whereArgs: [id]);
      await txn.insert('audit_events', {
        'entity_type': 'assessment',
        'entity_id': id,
        'action': 'deleted',
        'occurred_at': DateTime.now().toUtc().toIso8601String(),
      });
    });
    for (final row in certs) {
      final p = row['private_path'] as String?;
      if (p == null) continue;
      try {
        final f = File(p);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
    _notify();
  }

  Future<int> countAssessments() async {
    final db = await database;
    return _firstInt(await db.rawQuery('SELECT COUNT(*) FROM assessments')) ?? 0;
  }

  Future<List<GoldAssessment>> listAssessments({int limit = 20}) async {
    final db = await database;
    final rows = await db.query('assessments', orderBy: 'createdAt DESC', limit: limit);
    return rows.map(GoldAssessment.fromMap).toList();
  }

  Future<List<GoldAssessment>> searchAssessments(String query) async {
    final q = query.trim();
    if (q.isEmpty) return listAssessments();
    final db = await database;
    final like = '%$q%';
    final args = <Object?>[_ftsQuote(q), ...List<Object?>.filled(13, like)];
    try {
      final rows = await db.rawQuery('''
        SELECT DISTINCT a.* FROM assessments a
        WHERE a.id IN (
          SELECT id FROM assessments_fts WHERE assessments_fts MATCH ?
        )
        OR a.id IN (
          SELECT assessment_id FROM assay_samples
          WHERE LOWER(sample_code) LIKE LOWER(?)
             OR LOWER(IFNULL(laboratory,'')) LIKE LOWER(?)
             OR LOWER(IFNULL(certificate_number,'')) LIKE LOWER(?)
             OR CAST(grade_gpt AS TEXT) LIKE ?
             OR LOWER(IFNULL(sampled_at,'')) LIKE LOWER(?)
        )
        OR a.id IN (
          SELECT assessment_id FROM certificate_attachments
          WHERE LOWER(IFNULL(sample_code,'')) LIKE LOWER(?)
             OR LOWER(file_name) LIKE LOWER(?)
             OR LOWER(IFNULL(sha256,'')) LIKE LOWER(?)
             OR LOWER(added_at) LIKE LOWER(?)
        )
        OR a.id IN (
          SELECT entity_id FROM audit_events
          WHERE entity_type = 'assessment'
            AND (LOWER(entity_id) LIKE LOWER(?)
              OR LOWER(action) LIKE LOWER(?)
              OR LOWER(IFNULL(details,'')) LIKE LOWER(?)
              OR LOWER(occurred_at) LIKE LOWER(?))
        )
        ORDER BY a.createdAt DESC
      ''', args);
      return rows.map(GoldAssessment.fromMap).toList();
    } catch (_) {
      // FTS5 inaweza kutokuwepo kwenye baadhi ya SQLite builds.
      final fallbackArgs = List<Object?>.filled(18, like);
      final rows = await db.rawQuery('''
        SELECT DISTINCT a.* FROM assessments a
        WHERE LOWER(a.title) LIKE LOWER(?)
           OR LOWER(a.notes) LIKE LOWER(?)
           OR LOWER(a.mode) LIKE LOWER(?)
           OR LOWER(a.values_json) LIKE LOWER(?)
           OR LOWER(a.result) LIKE LOWER(?)
           OR a.id IN (
             SELECT assessment_id FROM assay_samples
             WHERE LOWER(sample_code) LIKE LOWER(?)
                OR LOWER(IFNULL(laboratory,'')) LIKE LOWER(?)
                OR LOWER(IFNULL(certificate_number,'')) LIKE LOWER(?)
                OR CAST(grade_gpt AS TEXT) LIKE ?
                OR LOWER(IFNULL(sampled_at,'')) LIKE LOWER(?)
           )
           OR a.id IN (
             SELECT assessment_id FROM certificate_attachments
             WHERE LOWER(IFNULL(sample_code,'')) LIKE LOWER(?)
                OR LOWER(file_name) LIKE LOWER(?)
                OR LOWER(IFNULL(sha256,'')) LIKE LOWER(?)
                OR LOWER(added_at) LIKE LOWER(?)
           )
           OR a.id IN (
             SELECT entity_id FROM audit_events
             WHERE entity_type = 'assessment'
               AND (LOWER(entity_id) LIKE LOWER(?)
                 OR LOWER(action) LIKE LOWER(?)
                 OR LOWER(IFNULL(details,'')) LIKE LOWER(?)
                 OR LOWER(occurred_at) LIKE LOWER(?))
           )
        ORDER BY a.createdAt DESC
      ''', fallbackArgs);
      return rows.map(GoldAssessment.fromMap).toList();
    }
  }

  /// Huvunja punctuation kuwa tokens salama kabla ya kuunda phrase za FTS.
  String _ftsQuote(String q) => q
      .split(RegExp(r'[^A-Za-z0-9]+'))
      .where((t) => t.isNotEmpty)
      .map((t) => '"$t"')
      .join(' ');

  Future<List<Map<String, Object?>>> listAssaySamples(String assessmentId) async {
    final db = await database;
    return db.query('assay_samples',
        where: 'assessment_id = ?', whereArgs: [assessmentId], orderBy: 'created_at ASC');
  }

  Future<List<Map<String, Object?>>> listCertificates(String assessmentId) async {
    final db = await database;
    return db.query('certificate_attachments',
        where: 'assessment_id = ?', whereArgs: [assessmentId], orderBy: 'added_at ASC');
  }

  // ---------------------------------------------------------------- backup

  Future<List<Map<String, Object?>>> exportAssessmentRows() async {
    final db = await database;
    final rows = await db.query('assessments', orderBy: 'createdAt ASC');
    return rows.map((r) => Map<String, Object?>.from(GoldAssessment.fromMap(r).toMap())).toList();
  }

  Future<List<Map<String, Object?>>> exportAssaySamples() async {
    final db = await database;
    return db.query('assay_samples', orderBy: 'created_at ASC');
  }

  Future<List<Map<String, Object?>>> exportPriceRecords() async {
    final db = await database;
    return db.query('gold_price_records', orderBy: 'recorded_at ASC');
  }

  Future<List<Map<String, Object?>>> exportAuditEvents() async {
    final db = await database;
    return db.query('audit_events', orderBy: 'id ASC');
  }

  Future<List<Map<String, Object?>>> exportCertificateRows() async {
    final db = await database;
    return db.query('certificate_attachments', orderBy: 'added_at ASC');
  }

  Future<Set<String>> existingCertificateIds() async {
    final db = await database;
    final rows = await db.query('certificate_attachments', columns: ['id', 'private_path']);
    final valid = <String>{};
    for (final row in rows) {
      final id = row['id'] as String?;
      final path = row['private_path'] as String?;
      if (id == null || path == null) continue;
      try {
        if (await File(path).exists()) valid.add(id);
      } catch (_) {}
    }
    return valid;
  }

  /// Huingiza backup kwa muamala mmoja. Rekodi zenye ID sawa husasishwa BILA
  /// kufuta samples/vyeti vilivyopo. Samples/bei/vyeti vyenye ID iliyopo
  /// huachwa kama vilivyo.
  Future<int> importBackup({
    required List<Map<String, Object?>> assessments,
    List<Map<String, Object?>> samples = const [],
    List<Map<String, Object?>> prices = const [],
    List<Map<String, Object?>> certificates = const [],
    List<Map<String, Object?>> auditEvents = const [],
  }) async {
    final db = await database;
    var imported = 0;
    await db.transaction((txn) async {
      final ids = <String>{};
      for (final row in assessments) {
        final assessment = GoldAssessment.fromMap(row);
        await _upsertAssessment(txn, assessment, action: 'backup_import');
        ids.add(assessment.id);
        imported++;
      }
      for (final s in samples) {
        if (!ids.contains(s['assessment_id'])) continue;
        await txn.insert(
            'assay_samples',
            {
              'id': s['id'],
              'assessment_id': s['assessment_id'],
              'sample_code': s['sample_code'],
              'laboratory': s['laboratory'],
              'certificate_number': s['certificate_number'],
              'grade_gpt': s['grade_gpt'],
              'sampled_at': s['sampled_at'],
              'created_at': s['created_at'] ?? DateTime.now().toUtc().toIso8601String(),
            },
            conflictAlgorithm: cipher.ConflictAlgorithm.ignore);
      }
      for (final p in prices) {
        await txn.insert(
            'gold_price_records',
            {
              'id': p['id'],
              'price_tzs_g': p['price_tzs_g'],
              'source': p['source'],
              'recorded_at': p['recorded_at'],
              'is_manual': p['is_manual'] ?? 1,
              'note': p['note'],
            },
            conflictAlgorithm: cipher.ConflictAlgorithm.ignore);
      }
      for (final c in certificates) {
        if (!ids.contains(c['assessment_id'])) continue;
        final cert = {
          'id': c['id'],
          'assessment_id': c['assessment_id'],
          'sample_code': c['sample_code'],
          'file_name': c['file_name'],
          'private_path': c['private_path'],
          'sha256': c['sha256'],
          'added_at': c['added_at'] ?? DateTime.now().toUtc().toIso8601String(),
        };
        final existingCert = await txn.query('certificate_attachments',
            columns: ['id'], where: 'id = ?', whereArgs: [c['id']]);
        if (existingCert.isEmpty) {
          await txn.insert('certificate_attachments', cert);
        } else {
          // Backup inaweza kurekebisha metadata ya cheti kilichokuwepo lakini
          // faili lake la ndani limepotea; usiache njia ya zamani iliyovunjika.
          await txn.update('certificate_attachments', {
            'private_path': c['private_path'],
            'sha256': c['sha256'],
            'file_name': c['file_name'],
            'added_at': cert['added_at'],
          }, where: 'id = ?', whereArgs: [c['id']]);
        }
      }
      // Audit kutoka backup: epuka nakala (entity+action+wakati).
      final seen = <String>{
        for (final e in await txn.query('audit_events',
            columns: ['entity_type', 'entity_id', 'action', 'occurred_at']))
          '${e['entity_type']}|${e['entity_id']}|${e['action']}|${e['occurred_at']}'
      };
      for (final e in auditEvents) {
        final k = '${e['entity_type']}|${e['entity_id']}|${e['action']}|${e['occurred_at']}';
        if (seen.add(k)) {
          await txn.insert('audit_events', {
            'entity_type': e['entity_type'],
            'entity_id': e['entity_id'],
            'action': e['action'],
            'occurred_at': e['occurred_at'],
            'details': e['details'],
          });
        }
      }
      await txn.insert('audit_events', {
        'entity_type': 'assessment',
        'entity_id': '*',
        'action': 'encrypted_backup_import',
        'occurred_at': DateTime.now().toUtc().toIso8601String(),
        'details': jsonEncode({'count': imported}),
      });
    });
    _notify();
    return imported;
  }

  // ----------------------------------------------------------------- reset

  /// KITENDO CHA KUHARIBU: hufuta database, vyeti vilivyosimbwa na ufunguo.
  /// Hutumika tu mtumiaji akithibitisha baada ya ufunguo kupotea.
  Future<void> resetAll() async {
    try {
      await _database?.close();
    } catch (_) {}
    _database = null;
    _opening = null;
    final path = await _dbPath();
    for (final suffix in ['', '-journal', '-wal', '-shm', '.plaintext-migration-backup']) {
      final f = File('$path$suffix');
      if (await f.exists()) await f.delete();
    }
    final support = await getApplicationSupportDirectory();
    final certs = Directory('${support.path}/certificates');
    if (await certs.exists()) await certs.delete(recursive: true);
    await _storage.delete(key: _keyName);
    _notify();
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
    _opening = null;
  }
}
