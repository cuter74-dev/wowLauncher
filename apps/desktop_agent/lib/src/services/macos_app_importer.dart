import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// A macOS application discovered on disk (the picker list shows these).
class InstalledApp {
  const InstalledApp({required this.name, required this.path});

  final String name;

  /// Absolute path to the `.app` bundle.
  final String path;
}

/// Fields extracted from an application bundle, ready to seed a [LaunchApp]
/// (name, executable path, and an optional PNG icon path).
class ImportedApp {
  const ImportedApp({
    required this.name,
    required this.executablePath,
    this.iconPath,
  });

  final String name;
  final String executablePath;
  final String? iconPath;
}

/// Discovers installed macOS `.app` bundles and extracts their display name and
/// icon, so a program can be registered in one step.
///
/// We scan the standard Applications folders instead of using a file picker:
/// on macOS a `.app` is a *bundle* (directory) that the system file/dir pickers
/// treat as an opaque package, making it effectively unselectable. Listing the
/// bundles ourselves is both more reliable and a better fit for "add from
/// Applications".
///
/// Icon extraction is best-effort: the bundle's `.icns` (from `CFBundleIconFile`,
/// falling back to the first `.icns` in `Resources/`) is converted to PNG via
/// macOS `sips`, since Flutter / the mobile client cannot render `.icns`.
class MacAppImporter {
  const MacAppImporter();

  static const _uuid = Uuid();

  /// Cache of small preview PNGs for the picker list, keyed by `.app` path
  /// (value is null when extraction failed, to avoid retrying every rebuild).
  static final Map<String, String?> _previewCache = {};

  /// Only meaningful on macOS, where applications are `.app` bundles.
  bool get isSupported => Platform.isMacOS;

  /// The standard locations macOS apps are installed into.
  List<String> get _searchDirs {
    final home = Platform.environment['HOME'];
    return [
      '/Applications',
      '/Applications/Utilities',
      '/System/Applications',
      '/System/Applications/Utilities',
      if (home != null) p.join(home, 'Applications'),
    ];
  }

  /// Returns installed `.app` bundles, de-duplicated and sorted by name.
  List<InstalledApp> listInstalledApps() {
    if (!isSupported) return const [];

    final seenPaths = <String>{};
    final apps = <InstalledApp>[];
    for (final dirPath in _searchDirs) {
      final dir = Directory(dirPath);
      if (!dir.existsSync()) continue;
      for (final entity in dir.listSync(followLinks: false)) {
        if (!entity.path.toLowerCase().endsWith('.app')) continue;
        if (!seenPaths.add(entity.path)) continue;
        apps.add(InstalledApp(
          name: p.basenameWithoutExtension(entity.path),
          path: entity.path,
        ));
      }
    }
    apps.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return apps;
  }

  /// Small (64px) icon PNG for showing in the picker list. Cached per app and
  /// written to a temporary directory (these are previews, not the saved icon).
  /// Returns null if no icon could be produced.
  Future<String?> iconPreviewPng(String appPath) async {
    if (_previewCache.containsKey(appPath)) return _previewCache[appPath];

    String? out;
    try {
      final resources = p.join(appPath, 'Contents', 'Resources');
      final icns = await _findIcns(appPath, resources);
      if (icns != null) {
        final tmp = await getTemporaryDirectory();
        final dir = Directory(p.join(tmp.path, 'app_icon_previews'));
        await dir.create(recursive: true);
        final dest = p.join(dir.path, '${_uuid.v4()}.png');
        final res = await Process.run(
          'sips',
          ['-s', 'format', 'png', '-Z', '64', icns, '--out', dest],
        );
        if (res.exitCode == 0 && File(dest).existsSync()) out = dest;
      }
    } catch (_) {
      out = null;
    }
    _previewCache[appPath] = out;
    return out;
  }

  /// Builds the importable fields (name + icon) for a chosen `.app` path.
  Future<ImportedApp> extractFrom(String appPath) async {
    final name = p.basenameWithoutExtension(appPath);
    String? iconPath;
    try {
      iconPath = await _extractIconAsPng(appPath);
    } catch (_) {
      iconPath = null; // icon is optional; never block registration on it
    }
    return ImportedApp(name: name, executablePath: appPath, iconPath: iconPath);
  }

  Future<String?> _extractIconAsPng(String appPath) async {
    final resources = p.join(appPath, 'Contents', 'Resources');
    final icns = await _findIcns(appPath, resources);
    if (icns == null) return null;

    final supportDir = await getApplicationSupportDirectory();
    final iconsDir = Directory(p.join(supportDir.path, 'app_icons'));
    await iconsDir.create(recursive: true);
    final out = p.join(iconsDir.path, '${_uuid.v4()}.png');

    final res = await Process.run(
      'sips',
      ['-s', 'format', 'png', '-Z', '256', icns, '--out', out],
    );
    if (res.exitCode == 0 && File(out).existsSync()) return out;
    return null;
  }

  Future<String?> _findIcns(String appPath, String resources) async {
    // Preferred: the bundle's declared icon file (may omit the .icns suffix).
    final infoPlist = p.join(appPath, 'Contents', 'Info');
    final read = await Process.run('defaults', ['read', infoPlist, 'CFBundleIconFile']);
    if (read.exitCode == 0) {
      var icon = (read.stdout as String).trim();
      if (icon.isNotEmpty) {
        if (!icon.toLowerCase().endsWith('.icns')) icon = '$icon.icns';
        final candidate = p.join(resources, icon);
        if (File(candidate).existsSync()) return candidate;
      }
    }

    // Fallback: first .icns found in Resources/.
    final dir = Directory(resources);
    if (dir.existsSync()) {
      for (final entity in dir.listSync()) {
        if (entity is File && entity.path.toLowerCase().endsWith('.icns')) {
          return entity.path;
        }
      }
    }
    return null;
  }
}
