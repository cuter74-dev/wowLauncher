import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../services/network_info.dart';

/// Persisted agent configuration (single-row key/value table).
class SettingsStore {
  SettingsStore(this.db);

  final Database db;

  static const _kAgentName = 'agentName';
  static const _kPort = 'port';
  static const _kLanguage = 'language';

  Future<String?> _get(String key) async {
    final rows = await db.query('settings', where: 'key = ?', whereArgs: [key], limit: 1);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> _set(String key, String value) async {
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String> getAgentName() async {
    final existing = await _get(_kAgentName);
    if (existing != null && existing.isNotEmpty) return existing;
    // Default to the machine hostname on first run.
    final name = NetworkInfo.hostName();
    await _set(_kAgentName, name);
    return name;
  }

  Future<void> setAgentName(String value) => _set(_kAgentName, value);

  Future<int> getPort() async {
    final raw = await _get(_kPort);
    return int.tryParse(raw ?? '') ?? 8765;
  }

  Future<void> setPort(int port) => _set(_kPort, port.toString());

  /// Selected UI language code (e.g. 'en', 'ko'). Empty/null means "follow the
  /// system locale".
  Future<String?> getLanguage() async {
    final raw = await _get(_kLanguage);
    return (raw == null || raw.isEmpty) ? null : raw;
  }

  Future<void> setLanguage(String? code) => _set(_kLanguage, code ?? '');
}
