import 'dart:convert';

import 'package:shared/shared.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Data access for the registered launchable apps.
class AppDao {
  AppDao(this.db);

  final Database db;

  Map<String, Object?> _toRow(LaunchApp app) => <String, Object?>{
        'id': app.id,
        'name': app.name,
        'executablePath': app.executablePath,
        'arguments': jsonEncode(app.arguments),
        'workingDirectory': app.workingDirectory,
        'iconPath': app.iconPath,
        'enabled': app.enabled ? 1 : 0,
        'createdAt': app.createdAt.toUtc().toIso8601String(),
        'updatedAt': app.updatedAt.toUtc().toIso8601String(),
      };

  LaunchApp _fromRow(Map<String, Object?> row) {
    final argsRaw = row['arguments'];
    List<String> args = const <String>[];
    if (argsRaw is String && argsRaw.isNotEmpty) {
      final decoded = jsonDecode(argsRaw);
      if (decoded is List) {
        args = decoded.map((e) => e.toString()).toList();
      }
    }
    return LaunchApp(
      id: row['id'] as String,
      name: row['name'] as String,
      executablePath: row['executablePath'] as String,
      arguments: args,
      workingDirectory: row['workingDirectory'] as String?,
      iconPath: row['iconPath'] as String?,
      enabled: (row['enabled'] as int? ?? 1) == 1,
      createdAt: DateTime.parse(row['createdAt'] as String),
      updatedAt: DateTime.parse(row['updatedAt'] as String),
    );
  }

  Future<List<LaunchApp>> getAll() async {
    final rows = await db.query('apps', orderBy: 'name COLLATE NOCASE ASC');
    return rows.map(_fromRow).toList();
  }

  Future<List<LaunchApp>> getEnabled() async {
    final rows = await db.query(
      'apps',
      where: 'enabled = 1',
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map(_fromRow).toList();
  }

  Future<LaunchApp?> getById(String id) async {
    final rows = await db.query('apps', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  Future<void> insert(LaunchApp app) async {
    await db.insert(
      'apps',
      _toRow(app),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> update(LaunchApp app) async {
    await db.update('apps', _toRow(app), where: 'id = ?', whereArgs: [app.id]);
  }

  Future<void> delete(String id) async {
    await db.delete('apps', where: 'id = ?', whereArgs: [id]);
  }
}
