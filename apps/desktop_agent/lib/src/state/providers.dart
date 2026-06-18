import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../db/app_dao.dart';
import '../db/database.dart';
import '../db/device_dao.dart';
import '../db/log_dao.dart';
import '../server/agent_server.dart';
import '../services/launcher_service.dart';
import '../services/network_info.dart';
import '../services/pairing_service.dart';
import '../services/settings_store.dart';

/// Bundle of all initialised services. Created once during bootstrap and
/// injected via [servicesProvider] (overridden in `main`).
class AppServices {
  AppServices({
    required this.database,
    required this.appDao,
    required this.deviceDao,
    required this.logDao,
    required this.settings,
    required this.pairingService,
    required this.launcher,
    required this.server,
    required this.agentName,
  });

  final AppDatabase database;
  final AppDao appDao;
  final DeviceDao deviceDao;
  final LogDao logDao;
  final SettingsStore settings;
  final PairingService pairingService;
  final LauncherService launcher;
  final AgentServer server;
  String agentName;

  /// Builds the fully wired set of services and opens the database.
  static Future<AppServices> bootstrap() async {
    final database = await AppDatabase.open();
    final db = database.db;

    final appDao = AppDao(db);
    final deviceDao = DeviceDao(db);
    final logDao = LogDao(db);
    final settings = SettingsStore(db);
    final agentName = await settings.getAgentName();

    final pairingService = PairingService(deviceDao);
    const launcher = LauncherService();

    final server = AgentServer(
      appDao: appDao,
      deviceDao: deviceDao,
      logDao: logDao,
      pairingService: pairingService,
      launcher: launcher,
      agentName: agentName,
    );

    return AppServices(
      database: database,
      appDao: appDao,
      deviceDao: deviceDao,
      logDao: logDao,
      settings: settings,
      pairingService: pairingService,
      launcher: launcher,
      server: server,
      agentName: agentName,
    );
  }
}

/// Overridden in `main()` after [AppServices.bootstrap].
final servicesProvider = Provider<AppServices>(
  (ref) => throw UnimplementedError('servicesProvider must be overridden'),
);

final pairingServiceProvider = Provider<PairingService>(
  (ref) => ref.watch(servicesProvider).pairingService,
);

/// Local host name + usable LAN IPv4 addresses, refreshed on demand.
final networkInfoProvider = FutureProvider<({String host, List<String> ips})>((ref) async {
  final ips = await NetworkInfo.localIpv4Addresses();
  return (host: NetworkInfo.hostName(), ips: ips);
});

// ---- Server status ------------------------------------------------------

class ServerState {
  const ServerState({required this.running, required this.port});
  final bool running;
  final int port;

  ServerState copyWith({bool? running, int? port}) =>
      ServerState(running: running ?? this.running, port: port ?? this.port);
}

class ServerNotifier extends Notifier<ServerState> {
  @override
  ServerState build() {
    final server = ref.read(servicesProvider).server;
    return ServerState(running: server.isRunning, port: server.boundPort ?? 8765);
  }

  Future<void> startWith(int port) async {
    final server = ref.read(servicesProvider).server;
    await server.start(port: port);
    state = ServerState(running: server.isRunning, port: server.boundPort ?? port);
  }

  Future<void> stop() async {
    final server = ref.read(servicesProvider).server;
    await server.stop();
    state = ServerState(running: false, port: state.port);
  }

  Future<void> restart(int port) async {
    await stop();
    await startWith(port);
  }
}

final serverProvider = NotifierProvider<ServerNotifier, ServerState>(ServerNotifier.new);

// ---- Apps ---------------------------------------------------------------

class AppsNotifier extends AsyncNotifier<List<LaunchApp>> {
  AppDao get _dao => ref.read(servicesProvider).appDao;

  @override
  Future<List<LaunchApp>> build() => _dao.getAll();

  Future<void> _reload() async {
    state = await AsyncValue.guard(_dao.getAll);
  }

  Future<void> save(LaunchApp app) async {
    final existing = await _dao.getById(app.id);
    if (existing == null) {
      await _dao.insert(app);
    } else {
      await _dao.update(app);
    }
    await _reload();
  }

  Future<void> delete(String id) async {
    await _dao.delete(id);
    await _reload();
  }

  Future<void> toggleEnabled(LaunchApp app) async {
    await _dao.update(app.copyWith(enabled: !app.enabled, updatedAt: DateTime.now()));
    await _reload();
  }
}

final appsProvider =
    AsyncNotifierProvider<AppsNotifier, List<LaunchApp>>(AppsNotifier.new);

// ---- Devices ------------------------------------------------------------

class DevicesNotifier extends AsyncNotifier<List<PairedDevice>> {
  DeviceDao get _dao => ref.read(servicesProvider).deviceDao;

  @override
  Future<List<PairedDevice>> build() => _dao.getAll();

  Future<void> _reload() async {
    state = await AsyncValue.guard(_dao.getAll);
  }

  Future<void> setBlocked(String id, bool blocked) async {
    await _dao.setBlocked(id, blocked);
    await _reload();
  }

  Future<void> delete(String id) async {
    await _dao.delete(id);
    await _reload();
  }

  Future<void> refresh() => _reload();
}

final devicesProvider =
    AsyncNotifierProvider<DevicesNotifier, List<PairedDevice>>(DevicesNotifier.new);

// ---- Logs ---------------------------------------------------------------

class LogsNotifier extends AsyncNotifier<List<LaunchLog>> {
  LogDao get _dao => ref.read(servicesProvider).logDao;

  @override
  Future<List<LaunchLog>> build() => _dao.getRecent();

  Future<void> refresh() async {
    state = await AsyncValue.guard(() => _dao.getRecent());
  }

  Future<void> clear() async {
    await _dao.clear();
    await refresh();
  }
}

final logsProvider =
    AsyncNotifierProvider<LogsNotifier, List<LaunchLog>>(LogsNotifier.new);
