import 'package:shared/shared.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Data access for launch audit logs.
class LogDao {
  LogDao(this.db);

  final Database db;

  Future<void> insert(LaunchLog log) async {
    await db.insert('logs', <String, Object?>{
      'id': log.id,
      'deviceId': log.deviceId,
      'deviceName': log.deviceName,
      'appId': log.appId,
      'appName': log.appName,
      'timestamp': log.timestamp.toUtc().toIso8601String(),
      'success': log.success ? 1 : 0,
      'message': log.message,
    });
  }

  Future<List<LaunchLog>> getRecent({int limit = 100}) async {
    final rows = await db.query('logs', orderBy: 'timestamp DESC', limit: limit);
    return rows
        .map((row) => LaunchLog(
              id: row['id'] as String,
              deviceId: row['deviceId'] as String?,
              deviceName: row['deviceName'] as String,
              appId: row['appId'] as String,
              appName: row['appName'] as String,
              timestamp: DateTime.parse(row['timestamp'] as String),
              success: (row['success'] as int? ?? 0) == 1,
              message: (row['message'] as String?) ?? '',
            ))
        .toList();
  }

  Future<void> clear() async {
    await db.delete('logs');
  }
}
