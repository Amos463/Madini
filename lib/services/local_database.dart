import 'dart:convert';
import 'dart:io';

import 'package:sqflite/sqflite.dart';

import '../domain/gold_assessment.dart';

class LocalDatabase {
  LocalDatabase._();

  static final LocalDatabase instance = LocalDatabase._();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }
    final dbPath = await getDatabasesPath();
    final path = '$dbPath/madini.db';
    _database = await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
    return _database!;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE assessments (
        id TEXT PRIMARY KEY,
        title TEXT,
        mode TEXT,
        assessmentType TEXT,
        createdAt TEXT,
        formulaVersion TEXT,
        values TEXT,
        result TEXT,
        notes TEXT
      )
    ''');

    await db.execute('''
      CREATE VIRTUAL TABLE assessments_fts USING fts5(
        id UNINDEXED,
        title,
        notes,
        mode,
        content,
        tokenize = 'unicode61 remove_diacritics 2'
      )
    ''');
  }

  Future<String> insertAssessment(GoldAssessment assessment) async {
    final db = await database;
    await db.insert(
      'assessments',
      assessment.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    final searchContent = [
      assessment.title,
      assessment.mode,
      assessment.assessmentType,
      assessment.notes,
      jsonEncode(assessment.values),
      jsonEncode(assessment.result),
    ].join(' ');

    await db.rawInsert(
      'INSERT INTO assessments_fts(rowid, id, title, notes, mode, content) VALUES ((SELECT rowid FROM assessments WHERE id = ?), ?, ?, ?, ?, ?)',
      [assessment.id, assessment.id, assessment.title, assessment.notes, assessment.mode, searchContent],
    );
    return assessment.id;
  }

  Future<List<GoldAssessment>> listAssessments({int limit = 20}) async {
    final db = await database;
    final rows = await db.query(
      'assessments',
      orderBy: 'createdAt DESC',
      limit: limit,
    );
    return rows.map(GoldAssessment.fromMap).toList();
  }

  Future<List<GoldAssessment>> searchAssessments(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      return listAssessments();
    }

    final db = await database;
    try {
      final rows = await db.rawQuery(
        '''
        SELECT a.*
        FROM assessments_fts f
        JOIN assessments a ON a.id = f.id
        WHERE assessments_fts MATCH ?
        ORDER BY rowid DESC
        LIMIT 20
        ''',
        [q],
      );
      if (rows.isNotEmpty) {
        return rows.map(GoldAssessment.fromMap).toList();
      }
    } catch (_) {
      // Fall back to LIKE search when FTS is unavailable.
    }

    final likeQuery = '%$q%';
    final rows = await db.rawQuery(
      '''
      SELECT * FROM assessments
      WHERE LOWER(title) LIKE LOWER(?)
      OR LOWER(notes) LIKE LOWER(?)
      OR LOWER(mode) LIKE LOWER(?)
      OR LOWER(values) LIKE LOWER(?)
      OR LOWER(result) LIKE LOWER(?)
      ORDER BY createdAt DESC
      LIMIT 20
      ''',
      [likeQuery, likeQuery, likeQuery, likeQuery, likeQuery],
    );
    return rows.map(GoldAssessment.fromMap).toList();
  }

  Future<void> clearAssessments() async {
    final db = await database;
    await db.delete('assessments');
    await db.delete('assessments_fts');
  }

  Future<String> backupDatabase(String destinationName) async {
    final db = await database;
    final dbPath = db.path;
    final file = File(dbPath);
    final dir = Directory('/tmp');
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    final backupFile = File('${dir.path}/$destinationName');
    await file.copy(backupFile.path);
    return backupFile.path;
  }

  Future<void> restoreDatabase(String backupPath) async {
    final db = await database;
    await db.close();
    final backupFile = File(backupPath);
    final dbPath = db.path;
    await backupFile.copy(dbPath);
    _database = await openDatabase(dbPath, version: 1, onCreate: _onCreate);
  }
}
