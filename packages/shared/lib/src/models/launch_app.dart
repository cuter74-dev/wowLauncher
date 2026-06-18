import '../util/json_utils.dart';

/// A program that the desktop agent is allowed to launch.
///
/// This is the full record stored on the PC. Sensitive fields such as the
/// executable path and arguments are NEVER sent to the mobile client — the
/// mobile side only ever references an app by its [id]. See [AppListItem] for
/// the trimmed-down representation that leaves the PC.
class LaunchApp {
  const LaunchApp({
    required this.id,
    required this.name,
    required this.executablePath,
    this.arguments = const <String>[],
    this.workingDirectory,
    this.iconPath,
    this.enabled = true,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Internal UUID. The only identifier ever exposed to mobile devices.
  final String id;
  final String name;

  /// Absolute path to the executable / .app bundle. PC-only, never sent out.
  final String executablePath;

  /// Fixed launch arguments configured on the PC. Mobile clients cannot
  /// override these — they can only trigger a launch by [id].
  final List<String> arguments;
  final String? workingDirectory;
  final String? iconPath;

  /// Whether the app is visible to / launchable by mobile devices.
  final bool enabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  LaunchApp copyWith({
    String? name,
    String? executablePath,
    List<String>? arguments,
    String? workingDirectory,
    bool clearWorkingDirectory = false,
    String? iconPath,
    bool clearIconPath = false,
    bool? enabled,
    DateTime? updatedAt,
  }) {
    return LaunchApp(
      id: id,
      name: name ?? this.name,
      executablePath: executablePath ?? this.executablePath,
      arguments: arguments ?? this.arguments,
      workingDirectory:
          clearWorkingDirectory ? null : (workingDirectory ?? this.workingDirectory),
      iconPath: clearIconPath ? null : (iconPath ?? this.iconPath),
      enabled: enabled ?? this.enabled,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory LaunchApp.fromJson(Map<String, Object?> json) {
    return LaunchApp(
      id: JsonUtils.asString(json['id']),
      name: JsonUtils.asString(json['name']),
      executablePath: JsonUtils.asString(json['executablePath']),
      arguments: JsonUtils.asStringList(json['arguments']),
      workingDirectory: JsonUtils.asStringOrNull(json['workingDirectory']),
      iconPath: JsonUtils.asStringOrNull(json['iconPath']),
      enabled: JsonUtils.asBool(json['enabled'], fallback: true),
      createdAt: JsonUtils.asDateTime(json['createdAt']),
      updatedAt: JsonUtils.asDateTime(json['updatedAt']),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'name': name,
        'executablePath': executablePath,
        'arguments': arguments,
        'workingDirectory': workingDirectory,
        'iconPath': iconPath,
        'enabled': enabled,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };
}
