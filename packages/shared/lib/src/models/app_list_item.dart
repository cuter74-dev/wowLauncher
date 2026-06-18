import '../util/json_utils.dart';

/// The safe, public representation of an app that is sent to mobile clients.
///
/// Deliberately omits [executablePath], [arguments] and [workingDirectory] so a
/// compromised mobile device can never learn or influence what actually runs.
class AppListItem {
  const AppListItem({
    required this.id,
    required this.name,
    this.iconBase64,
    this.enabled = true,
  });

  final String id;
  final String name;

  /// PNG/JPEG icon encoded as base64 (no data: prefix), or null if none.
  final String? iconBase64;
  final bool enabled;

  factory AppListItem.fromJson(Map<String, Object?> json) {
    return AppListItem(
      id: JsonUtils.asString(json['id']),
      name: JsonUtils.asString(json['name']),
      iconBase64: JsonUtils.asStringOrNull(json['iconBase64']),
      enabled: JsonUtils.asBool(json['enabled'], fallback: true),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'name': name,
        'iconBase64': iconBase64,
        'enabled': enabled,
      };
}
