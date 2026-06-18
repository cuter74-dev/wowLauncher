import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shared/shared.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';

import '../db/app_dao.dart';
import '../db/device_dao.dart';
import '../db/log_dao.dart';
import '../services/launcher_service.dart';
import '../services/network_info.dart';
import '../services/pairing_service.dart';
import 'auth.dart';

/// The embedded HTTP API served by the desktop agent.
///
/// Exposes only a tiny, fixed surface (health, pairing, list apps, launch by
/// id). There is deliberately no endpoint that accepts an arbitrary command,
/// path or argument from the network.
class AgentServer {
  AgentServer({
    required this.appDao,
    required this.deviceDao,
    required this.logDao,
    required this.pairingService,
    required this.launcher,
    required this.agentName,
  });

  final AppDao appDao;
  final DeviceDao deviceDao;
  final LogDao logDao;
  final PairingService pairingService;
  final LauncherService launcher;
  final String agentName;

  static final Uuid _uuid = Uuid();
  static const String version = '0.1.0';

  HttpServer? _server;
  bool get isRunning => _server != null;
  int? get boundPort => _server?.port;

  Future<void> start({int port = 8765}) async {
    if (_server != null) return;

    final router = Router()
      ..get(ApiPaths.health, _health)
      ..post(ApiPaths.pairRequest, _pairRequest)
      ..get('/api/pair/status/<requestId>', _pairStatus)
      ..get(ApiPaths.apps, _listApps)
      ..post('/api/apps/<id>/launch', _launchApp);

    final handler = const Pipeline()
        .addMiddleware(logRequests())
        .addMiddleware(_securityHeaders())
        .addHandler(router.call);

    // Bind to all IPv4 interfaces so other LAN devices can connect.
    _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
    _server!.autoCompress = true;
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  // ---- Middleware --------------------------------------------------------

  /// Adds minimal security-relevant headers. CORS is intentionally NOT enabled:
  /// the API is meant for the native mobile app on the LAN, not browsers.
  Middleware _securityHeaders() {
    return (Handler inner) {
      return (Request request) async {
        final response = await inner(request);
        return response.change(headers: {
          'X-Content-Type-Options': 'nosniff',
          'Cache-Control': 'no-store',
        });
      };
    };
  }

  /// Validates `Authorization: Bearer <token>`. Returns the matched device, or
  /// an error Response to short-circuit the handler. Done as an inline helper
  /// (not middleware) so it composes cleanly with shelf_router path params.
  Future<({PairedDevice? device, Response? errorResponse})> _authenticate(
    Request request,
  ) async {
    final auth = request.headers['authorization'] ?? request.headers['Authorization'];
    if (auth == null || !auth.startsWith('Bearer ')) {
      return (device: null, errorResponse: _json({'error': 'unauthorized'}, status: 401));
    }
    final token = auth.substring('Bearer '.length).trim();
    if (token.isEmpty) {
      return (device: null, errorResponse: _json({'error': 'unauthorized'}, status: 401));
    }
    final device = await deviceDao.findByTokenHash(AuthTokens.hashToken(token));
    if (device == null) {
      return (device: null, errorResponse: _json({'error': 'unauthorized'}, status: 401));
    }
    if (device.blocked) {
      return (device: null, errorResponse: _json({'error': 'blocked'}, status: 403));
    }
    // Record activity.
    unawaited(deviceDao.touch(device.id, DateTime.now()));
    return (device: device, errorResponse: null);
  }

  // ---- Handlers ----------------------------------------------------------

  Future<Response> _health(Request request) async {
    final body = HealthResponse(
      ok: true,
      agentName: agentName,
      platform: NetworkInfo.platformName(),
      version: version,
    );
    return _json(body.toJson());
  }

  Future<Response> _pairRequest(Request request) async {
    final payload = await _readJson(request);
    if (payload == null) {
      return _json({'error': 'invalid_body'}, status: 400);
    }
    final req = PairRequest.fromJson(payload);
    final pending = pairingService.submitRequest(
      pairingCode: req.pairingCode,
      deviceName: req.deviceName,
      deviceType: req.deviceType,
      now: DateTime.now(),
    );
    if (pending == null) {
      // Wrong or stale pairing code.
      return _json({'error': 'invalid_pairing_code'}, status: 403);
    }
    return _json(
      PairRequestResponse(requestId: pending.requestId, status: 'pending').toJson(),
    );
  }

  Future<Response> _pairStatus(Request request, String requestId) async {
    final body = pairingService.buildStatusResponse(requestId);
    return _json(body.toJson());
  }

  Future<Response> _listApps(Request request) async {
    final auth = await _authenticate(request);
    if (auth.errorResponse != null) return auth.errorResponse!;

    final apps = await appDao.getEnabled();
    final items = <Map<String, Object?>>[];
    for (final app in apps) {
      items.add(AppListItem(
        id: app.id,
        name: app.name,
        iconBase64: await _readIconBase64(app.iconPath),
        enabled: app.enabled,
      ).toJson());
    }
    return _json(items);
  }

  Future<Response> _launchApp(Request request, String id) async {
    final auth = await _authenticate(request);
    if (auth.errorResponse != null) return auth.errorResponse!;
    final device = auth.device;

    final app = await appDao.getById(id);

    // Only registered, enabled apps may be launched.
    if (app == null) {
      await _log(device, id, '(unknown)', false, '등록되지 않은 앱입니다.');
      return _json(LaunchResponse(ok: false, message: '등록되지 않은 앱입니다.').toJson(), status: 404);
    }
    if (!app.enabled) {
      await _log(device, id, app.name, false, '비활성화된 앱입니다.');
      return _json(LaunchResponse(ok: false, message: '비활성화된 앱입니다.').toJson(), status: 403);
    }

    final result = await launcher.launch(app);
    await _log(device, app.id, app.name, result.ok, result.message);
    return _json(
      LaunchResponse(ok: result.ok, message: result.message).toJson(),
      status: result.ok ? 200 : 500,
    );
  }

  // ---- Helpers -----------------------------------------------------------

  Future<void> _log(
    PairedDevice? device,
    String appId,
    String appName,
    bool success,
    String message,
  ) async {
    await logDao.insert(LaunchLog(
      id: _uuid.v4(),
      deviceId: device?.id,
      deviceName: device?.deviceName ?? '(unknown)',
      appId: appId,
      appName: appName,
      timestamp: DateTime.now(),
      success: success,
      message: message,
    ));
  }

  Future<String?> _readIconBase64(String? iconPath) async {
    if (iconPath == null || iconPath.isEmpty) return null;
    try {
      final file = File(iconPath);
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      // Guard against very large icons bloating the response.
      if (bytes.length > 512 * 1024) return null;
      return base64Encode(bytes);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, Object?>?> _readJson(Request request) async {
    try {
      final body = await request.readAsString();
      if (body.isEmpty) return null;
      final decoded = jsonDecode(body);
      if (decoded is Map<String, Object?>) return decoded;
      if (decoded is Map) return decoded.cast<String, Object?>();
      return null;
    } catch (_) {
      return null;
    }
  }

  Response _json(Object? body, {int status = 200}) {
    return Response(
      status,
      body: jsonEncode(body),
      headers: {'Content-Type': 'application/json; charset=utf-8'},
    );
  }
}
