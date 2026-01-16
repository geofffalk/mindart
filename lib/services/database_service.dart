import 'dart:typed_data';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/saved_session.dart';

/// Database service for saving and loading meditation sessions
class DatabaseService {
  static const String _databaseName = 'mindart_sessions.db';
  static const int _databaseVersion = 2;
  static const String _tableName = 'sessions';

  Database? _database;

  /// Get the database, initializing if necessary
  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        meditation_id INTEGER NOT NULL,
        meditation_title TEXT NOT NULL,
        session_time INTEGER NOT NULL,
        location_x INTEGER,
        location_y INTEGER,
        drawing1 BLOB,
        drawing1_label TEXT,
        drawing2 BLOB,
        drawing2_label TEXT,
        drawing3 BLOB,
        drawing3_label TEXT,
        drawing4 BLOB,
        drawing4_label TEXT,
        drawing5 BLOB,
        drawing5_label TEXT,
        drawing6 BLOB,
        drawing6_label TEXT,
        drawing7 BLOB,
        drawing7_label TEXT,
        drawing8 BLOB,
        drawing8_label TEXT,
        drawing9 BLOB,
        drawing9_label TEXT,
        drawing10 BLOB,
        drawing10_label TEXT,
        audio1 BLOB,
        audio2 BLOB,
        audio3 BLOB,
        audio4 BLOB,
        audio5 BLOB,
        audio6 BLOB,
        audio7 BLOB,
        audio8 BLOB,
        audio9 BLOB,
        audio10 BLOB
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add audio columns for version 2
      for (int i = 1; i <= 10; i++) {
        await db.execute('ALTER TABLE $_tableName ADD COLUMN audio$i BLOB');
      }
    }
  }

  /// Save or update a session
  Future<int> saveSession(SavedSession session) async {
    final db = await database;
    final values = session.toMap();

    if (session.id != null) {
      // Update existing session
      await db.update(
        _tableName,
        values,
        where: 'id = ?',
        whereArgs: [session.id],
      );
      return session.id!;
    } else {
      // Check if session with same timestamp exists
      final existing = await db.query(
        _tableName,
        where: 'session_time = ?',
        whereArgs: [session.sessionTime],
      );

      if (existing.isNotEmpty) {
        final id = existing.first['id'] as int;
        await db.update(
          _tableName,
          values,
          where: 'id = ?',
          whereArgs: [id],
        );
        return id;
      } else {
        return await db.insert(_tableName, values);
      }
    }
  }

  /// Save a drawing to an existing session
  Future<void> saveDrawing({
    required int meditationId,
    required String meditationTitle,
    required int sessionTime,
    required int drawingIndex,
    required String? drawingName,
    required Uint8List drawing,
    Uint8List? audio,
  }) async {
    final db = await database;
    
    final values = <String, dynamic>{
      'drawing$drawingIndex': drawing,
      'drawing${drawingIndex}_label': drawingName,
    };

    if (audio != null) {
      values['audio$drawingIndex'] = audio;
    }

    // Check if session exists
    final existing = await db.query(
      _tableName,
      where: 'session_time = ?',
      whereArgs: [sessionTime],
    );

    if (existing.isNotEmpty) {
      await db.update(
        _tableName,
        values,
        where: 'session_time = ?',
        whereArgs: [sessionTime],
      );
    } else {
      values['meditation_id'] = meditationId;
      values['meditation_title'] = meditationTitle;
      values['session_time'] = sessionTime;
      await db.insert(_tableName, values);
    }
  }

  /// Get all saved sessions
  Future<List<SavedSession>> getAllSessions() async {
    final db = await database;
    final results = await db.query(
      _tableName,
      orderBy: 'session_time DESC',
    );
    return results.map((row) => SavedSession.fromMap(row)).toList();
  }

  /// Get sessions for a specific meditation
  Future<List<SavedSession>> getSessionsForMeditation(int meditationId) async {
    final db = await database;
    final results = await db.query(
      _tableName,
      where: 'meditation_id = ?',
      whereArgs: [meditationId],
      orderBy: 'session_time DESC',
    );
    return results.map((row) => SavedSession.fromMap(row)).toList();
  }

  /// Get a specific session
  Future<SavedSession?> getSession(int sessionTime) async {
    final db = await database;
    final results = await db.query(
      _tableName,
      where: 'session_time = ?',
      whereArgs: [sessionTime],
    );
    if (results.isEmpty) return null;
    return SavedSession.fromMap(results.first);
  }

  /// Delete a session
  Future<bool> deleteSession(int sessionTime) async {
    final db = await database;
    final count = await db.delete(
      _tableName,
      where: 'session_time = ?',
      whereArgs: [sessionTime],
    );
    return count > 0;
  }

  /// Close the database
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
