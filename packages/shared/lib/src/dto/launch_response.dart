import '../util/json_utils.dart';

/// `POST /api/apps/{id}/launch` response.
class LaunchResponse {
  const LaunchResponse({required this.ok, this.message = ''});

  final bool ok;
  final String message;

  factory LaunchResponse.fromJson(Map<String, Object?> json) {
    return LaunchResponse(
      ok: JsonUtils.asBool(json['ok']),
      message: JsonUtils.asString(json['message']),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'ok': ok,
        'message': message,
      };
}
