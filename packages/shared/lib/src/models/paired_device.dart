import '../util/json_utils.dart';

/// A mobile device that has been paired with the desktop agent.
///
/// The agent stores only the SHA-256 [tokenHash] of the access token, never the
/// token itself. The plaintext token lives only on the mobile device.
class PairedDevice {
  const PairedDevice({
    required this.id,
    required this.deviceName,
    required this.deviceType,
    required this.tokenHash,
    required this.createdAt,
    required this.lastSeenAt,
    this.blocked = false,
  });

  final String id;
  final String deviceName;

  /// `ios` | `android`.
  final String deviceType;

  /// SHA-256 hash of the bearer token issued to this device.
  final String tokenHash;
  final DateTime createdAt;
  final DateTime lastSeenAt;
  final bool blocked;

  PairedDevice copyWith({
    String? deviceName,
    DateTime? lastSeenAt,
    bool? blocked,
  }) {
    return PairedDevice(
      id: id,
      deviceName: deviceName ?? this.deviceName,
      deviceType: deviceType,
      tokenHash: tokenHash,
      createdAt: createdAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      blocked: blocked ?? this.blocked,
    );
  }

  factory PairedDevice.fromJson(Map<String, Object?> json) {
    return PairedDevice(
      id: JsonUtils.asString(json['id']),
      deviceName: JsonUtils.asString(json['deviceName']),
      deviceType: JsonUtils.asString(json['deviceType']),
      tokenHash: JsonUtils.asString(json['tokenHash']),
      createdAt: JsonUtils.asDateTime(json['createdAt']),
      lastSeenAt: JsonUtils.asDateTime(json['lastSeenAt']),
      blocked: JsonUtils.asBool(json['blocked']),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'deviceName': deviceName,
        'deviceType': deviceType,
        'tokenHash': tokenHash,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'lastSeenAt': lastSeenAt.toUtc().toIso8601String(),
        'blocked': blocked,
      };
}
