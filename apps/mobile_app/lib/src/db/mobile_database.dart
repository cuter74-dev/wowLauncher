import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/pc_connection.dart';

/// SQLite storage for paired PCs on the mobile device.
class MobileDatabase {
  MobileDatabase._(this._db);

  final Database _db;

  static MobileDatabase? _instance;
  static MobileDatabase get instance {
    final i = _instance;
    if (i == null) throw StateError('MobileDatabase.open() not called.');
    return i;
  }

  static Future<MobileDatabase> open() async {
    if (_instance != null) return _instance!;
    final dir = await getDatabasesPath();
    final path = p.join(dir, 'remote_launcher_mobile.db');
    final db = await openDatabase(
      path,
      version: 2,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE pcs (
            id TEXT PRIMARY KEY,
            agentName TEXT NOT NULL,
            host TEXT NOT NULL,
            port INTEGER NOT NULL,
            accessToken TEXT NOT NULL,
            platform TEXT,
            addedAt TEXT NOT NULL,
            lastConnectedAt TEXT
          )
        ''');
        await _createSettings(db);
      },
      onUpgrade: (db, oldVersion, _) async {
        if (oldVersion < 2) await _createSettings(db);
      },
    );
    _instance = MobileDatabase._(db);
    return _instance!;
  }

  static Future<void> _createSettings(Database db) async {
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  static const _kLanguage = 'language';

  /// Selected UI language code (e.g. 'en', 'ko'), or null to follow the system.
  Future<String?> getLanguage() async {
    final rows = await _db.query('settings',
        where: 'key = ?', whereArgs: [_kLanguage], limit: 1);
    if (rows.isEmpty) return null;
    final v = rows.first['value'] as String?;
    return (v == null || v.isEmpty) ? null : v;
  }

  Future<void> setLanguage(String? code) async {
    await _db.insert(
      'settings',
      {'key': _kLanguage, 'value': code ?? ''},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<PcConnection>> getAll() async {
    final rows = await _db.query('pcs', orderBy: 'addedAt DESC');
    return rows.map(PcConnection.fromRow).toList();
  }

  Future<void> upsert(PcConnection pc) async {
    await _db.insert('pcs', pc.toRow(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> delete(String id) async {
    await _db.delete('pcs', where: 'id = ?', whereArgs: [id]);
  }
}
