import '../util/json_utils.dart';

/// `GET /api/health` response. Unauthenticated, used by mobile to verify a PC
/// is reachable and to read its display name/platform.
class HealthResponse {
  const HealthResponse({
    required this.ok,
    required this.agentName,
    required this.platform,
    required this.version,
  });

  final bool ok;
  final String agentName;

  /// `windows` | `macos` | `linux`.
  final String platform;
  final String version;

  factory HealthResponse.fromJson(Map<String, Object?> json) {
    return HealthResponse(
      ok: JsonUtils.asBool(json['ok']),
      agentName: JsonUtils.asString(json['agentName']),
      platform: JsonUtils.asString(json['platform']),
      version: JsonUtils.asString(json['version']),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'ok': ok,
        'agentName': agentName,
        'platform': platform,
        'version': version,
      };
}
