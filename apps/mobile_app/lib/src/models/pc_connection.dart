/// A paired PC stored on the mobile device, including its access token.
///
/// The token lives only here on the device; the PC keeps only its hash.
class PcConnection {
  const PcConnection({
    required this.id,
    required this.agentName,
    required this.host,
    required this.port,
    required this.accessToken,
    this.platform = '',
    required this.addedAt,
    this.lastConnectedAt,
  });

  final String id;
  final String agentName;
  final String host;
  final int port;
  final String accessToken;
  final String platform;
  final DateTime addedAt;
  final DateTime? lastConnectedAt;

  /// Base URL of the agent, e.g. `http://192.168.0.10:8765`.
  String get baseUrl => 'http://$host:$port';

  PcConnection copyWith({
    String? agentName,
    String? platform,
    DateTime? lastConnectedAt,
  }) {
    return PcConnection(
      id: id,
      agentName: agentName ?? this.agentName,
      host: host,
      port: port,
      accessToken: accessToken,
      platform: platform ?? this.platform,
      addedAt: addedAt,
      lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
    );
  }

  Map<String, Object?> toRow() => <String, Object?>{
        'id': id,
        'agentName': agentName,
        'host': host,
        'port': port,
        'accessToken': accessToken,
        'platform': platform,
        'addedAt': addedAt.toUtc().toIso8601String(),
        'lastConnectedAt': lastConnectedAt?.toUtc().toIso8601String(),
      };

  factory PcConnection.fromRow(Map<String, Object?> row) {
    return PcConnection(
      id: row['id'] as String,
      agentName: row['agentName'] as String,
      host: row['host'] as String,
      port: row['port'] as int,
      accessToken: row['accessToken'] as String,
      platform: (row['platform'] as String?) ?? '',
      addedAt: DateTime.parse(row['addedAt'] as String),
      lastConnectedAt: row['lastConnectedAt'] == null
          ? null
          : DateTime.parse(row['lastConnectedAt'] as String),
    );
  }
}
