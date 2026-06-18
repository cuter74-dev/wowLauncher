import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Owns the SQLite database connection and schema for the desktop agent.
///
/// Uses `sqflite_common_ffi` which works on Windows/macOS/Linux desktop.
class AppDatabase {
  AppDatabase._(this.db);

  final Database db;

  static AppDatabase? _instance;
  static AppDatabase get instance {
    final inst = _instance;
    if (inst == null) {
      throw StateError('AppDatabase.open() must be called before use.');
    }
    return inst;
  }

  /// Initialises the FFI backend and opens (creating if needed) the database.
  static Future<AppDatabase> open() async {
    if (_instance != null) return _instance!;

    // Required for desktop: register the FFI implementation.
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final dir = await getApplicationSupportDirectory();
    await Directory(dir.path).create(recursive: true);
    final path = p.join(dir.path, 'remote_launcher.db');

    final db = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: _createSchema,
      ),
    );

    _instance = AppDatabase._(db);
    return _instance!;
  }

  static Future<void> _createSchema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE apps (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        executablePath TEXT NOT NULL,
        arguments TEXT NOT NULL,          -- JSON array of strings
        workingDirectory TEXT,
        iconPath TEXT,
        enabled INTEGER NOT NULL DEFAULT 1,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE devices (
        id TEXT PRIMARY KEY,
        deviceName TEXT NOT NULL,
        deviceType TEXT NOT NULL,
        tokenHash TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        lastSeenAt TEXT NOT NULL,
        blocked INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE logs (
        id TEXT PRIMARY KEY,
        deviceId TEXT,
        deviceName TEXT NOT NULL,
        appId TEXT NOT NULL,
        appName TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        success INTEGER NOT NULL,
        message TEXT NOT NULL DEFAULT ''
      )
    ''');

    // A single-row settings table holding the agent's persistent config.
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }
}
