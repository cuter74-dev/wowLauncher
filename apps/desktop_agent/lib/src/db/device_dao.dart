import 'package:shared/shared.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Data access for paired mobile devices.
class DeviceDao {
  DeviceDao(this.db);

  final Database db;

  Map<String, Object?> _toRow(PairedDevice d) => <String, Object?>{
        'id': d.id,
        'deviceName': d.deviceName,
        'deviceType': d.deviceType,
        'tokenHash': d.tokenHash,
        'createdAt': d.createdAt.toUtc().toIso8601String(),
        'lastSeenAt': d.lastSeenAt.toUtc().toIso8601String(),
        'blocked': d.blocked ? 1 : 0,
      };

  PairedDevice _fromRow(Map<String, Object?> row) => PairedDevice(
        id: row['id'] as String,
        deviceName: row['deviceName'] as String,
        deviceType: row['deviceType'] as String,
        tokenHash: row['tokenHash'] as String,
        createdAt: DateTime.parse(row['createdAt'] as String),
        lastSeenAt: DateTime.parse(row['lastSeenAt'] as String),
        blocked: (row['blocked'] as int? ?? 0) == 1,
      );

  Future<List<PairedDevice>> getAll() async {
    final rows = await db.query('devices', orderBy: 'lastSeenAt DESC');
    return rows.map(_fromRow).toList();
  }

  Future<PairedDevice?> findByTokenHash(String tokenHash) async {
    final rows = await db.query(
      'devices',
      where: 'tokenHash = ?',
      whereArgs: [tokenHash],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  Future<void> insert(PairedDevice device) async {
    await db.insert(
      'devices',
      _toRow(device),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> touch(String id, DateTime when) async {
    await db.update(
      'devices',
      {'lastSeenAt': when.toUtc().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> setBlocked(String id, bool blocked) async {
    await db.update(
      'devices',
      {'blocked': blocked ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> delete(String id) async {
    await db.delete('devices', where: 'id = ?', whereArgs: [id]);
  }
}
