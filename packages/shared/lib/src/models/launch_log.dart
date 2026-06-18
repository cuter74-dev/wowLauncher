import '../util/json_utils.dart';

/// An audit record: which device launched which app, when, and the result.
class LaunchLog {
  const LaunchLog({
    required this.id,
    this.deviceId,
    required this.deviceName,
    required this.appId,
    required this.appName,
    required this.timestamp,
    required this.success,
    this.message = '',
  });

  final String id;
  final String? deviceId;
  final String deviceName;
  final String appId;
  final String appName;
  final DateTime timestamp;
  final bool success;
  final String message;

  factory LaunchLog.fromJson(Map<String, Object?> json) {
    return LaunchLog(
      id: JsonUtils.asString(json['id']),
      deviceId: JsonUtils.asStringOrNull(json['deviceId']),
      deviceName: JsonUtils.asString(json['deviceName']),
      appId: JsonUtils.asString(json['appId']),
      appName: JsonUtils.asString(json['appName']),
      timestamp: JsonUtils.asDateTime(json['timestamp']),
      success: JsonUtils.asBool(json['success']),
      message: JsonUtils.asString(json['message']),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'deviceId': deviceId,
        'deviceName': deviceName,
        'appId': appId,
        'appName': appName,
        'timestamp': timestamp.toUtc().toIso8601String(),
        'success': success,
        'message': message,
      };
}
