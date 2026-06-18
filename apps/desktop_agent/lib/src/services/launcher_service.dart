import 'dart:io';

import 'package:shared/shared.dart';

/// Result of attempting to launch an app.
class LaunchResult {
  const LaunchResult({required this.ok, required this.message});

  final bool ok;
  final String message;
}

/// Safely launches a *pre-registered* app.
///
/// SECURITY: This service NEVER accepts a command string from the network. It
/// only ever receives a [LaunchApp] that was looked up from the local database
/// by id. The executable path and arguments come exclusively from PC-side
/// configuration. `shell: true` is never used, so there is no shell
/// interpolation / injection surface.
class LauncherService {
  const LauncherService();

  Future<LaunchResult> launch(LaunchApp app) async {
    final path = app.executablePath.trim();
    if (path.isEmpty) {
      return const LaunchResult(ok: false, message: '실행 파일 경로가 비어 있습니다.');
    }

    // Validate the working directory up-front for a clear error.
    final workingDir = app.workingDirectory?.trim();
    if (workingDir != null && workingDir.isNotEmpty) {
      if (!Directory(workingDir).existsSync()) {
        return LaunchResult(ok: false, message: '작업 폴더가 존재하지 않습니다: $workingDir');
      }
    }

    try {
      if (Platform.isMacOS) {
        return await _launchMacOS(path, app.arguments, workingDir);
      } else if (Platform.isWindows) {
        return await _launchGeneric(path, app.arguments, workingDir, requireExists: true);
      } else {
        // Linux and any other POSIX-like platform.
        return await _launchGeneric(path, app.arguments, workingDir, requireExists: true);
      }
    } on ProcessException catch (e) {
      return LaunchResult(ok: false, message: '실행 실패: ${e.message}');
    } catch (e) {
      return LaunchResult(ok: false, message: '실행 중 오류가 발생했습니다: $e');
    }
  }

  /// Generic Process.start launch used for Windows/Linux and raw macOS binaries.
  Future<LaunchResult> _launchGeneric(
    String path,
    List<String> args,
    String? workingDir, {
    required bool requireExists,
  }) async {
    if (requireExists && !File(path).existsSync()) {
      return LaunchResult(ok: false, message: '실행 파일을 찾을 수 없습니다: $path');
    }

    // mode: detached so the launched program keeps running independently of the
    // agent and we don't block on it.
    await Process.start(
      path,
      args,
      workingDirectory: (workingDir != null && workingDir.isNotEmpty) ? workingDir : null,
      mode: ProcessStartMode.detached,
      runInShell: false, // never use a shell
    );
    return const LaunchResult(ok: true, message: 'started');
  }

  /// macOS: `.app` bundles are directories and must be launched via `open`.
  /// Regular Unix executables fall back to the generic path.
  Future<LaunchResult> _launchMacOS(
    String path,
    List<String> args,
    String? workingDir,
  ) async {
    final isAppBundle = path.toLowerCase().endsWith('.app');
    if (isAppBundle) {
      if (!Directory(path).existsSync()) {
        return LaunchResult(ok: false, message: '.app 번들을 찾을 수 없습니다: $path');
      }
      // `open -a <bundle> --args <args...>` launches the bundle. Arguments are
      // still fully PC-controlled, so this is safe.
      final openArgs = <String>['-a', path];
      if (args.isNotEmpty) {
        openArgs..add('--args')..addAll(args);
      }
      await Process.start(
        'open',
        openArgs,
        workingDirectory: (workingDir != null && workingDir.isNotEmpty) ? workingDir : null,
        mode: ProcessStartMode.detached,
        runInShell: false,
      );
      return const LaunchResult(ok: true, message: 'started');
    }
    return _launchGeneric(path, args, workingDir, requireExists: true);
  }
}
