import 'package:flutter/foundation.dart';
import 'package:shared/shared.dart';
import 'package:uuid/uuid.dart';

import '../db/device_dao.dart';
import '../server/auth.dart';

/// A pending pairing request awaiting user approval in the desktop UI.
class PendingPairing {
  PendingPairing({
    required this.requestId,
    required this.deviceName,
    required this.deviceType,
    required this.createdAt,
    this.status = PairStatus.pending,
    this.accessToken,
    this.deviceId,
  });

  final String requestId;
  final String deviceName;
  final String deviceType;
  final DateTime createdAt;
  PairStatus status;

  /// Plaintext token, only held transiently until the mobile polls once.
  String? accessToken;
  String? deviceId;
}

/// Coordinates device pairing between the HTTP server and the desktop UI.
///
/// Extends [ChangeNotifier] so the UI can react to new requests and approvals.
class PairingService extends ChangeNotifier {
  PairingService(this._deviceDao) {
    rotateCode();
  }

  final DeviceDao _deviceDao;
  static final Uuid _uuid = Uuid();

  /// The single-use pairing code currently embedded in the QR.
  String _currentCode = '';
  String get currentCode => _currentCode;

  final Map<String, PendingPairing> _requests = <String, PendingPairing>{};

  /// Pending (not yet decided) requests, newest first — drives the UI banner.
  List<PendingPairing> get pendingRequests => _requests.values
      .where((r) => r.status == PairStatus.pending)
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// Generates a fresh pairing code (also called after each successful pairing
  /// so a code is genuinely single-use).
  void rotateCode() {
    _currentCode = AuthTokens.generatePairingCode();
    notifyListeners();
  }

  /// Called by the HTTP layer when a mobile device submits a pairing request.
  /// Returns the created request, or null if the pairing code is wrong.
  PendingPairing? submitRequest({
    required String pairingCode,
    required String deviceName,
    required String deviceType,
    required DateTime now,
  }) {
    if (pairingCode.isEmpty || pairingCode != _currentCode) {
      return null; // invalid / stale code
    }
    final req = PendingPairing(
      requestId: _uuid.v4(),
      deviceName: deviceName.isEmpty ? 'Unknown device' : deviceName,
      deviceType: deviceType,
      createdAt: now,
    );
    _requests[req.requestId] = req;
    notifyListeners();
    return req;
  }

  PendingPairing? statusOf(String requestId) => _requests[requestId];

  /// User approved a request in the UI. Issues a token, stores only its hash,
  /// and rotates the pairing code so it cannot be reused.
  Future<void> approve(String requestId, {required DateTime now}) async {
    final req = _requests[requestId];
    if (req == null || req.status != PairStatus.pending) return;

    final token = AuthTokens.generateToken();
    final deviceId = _uuid.v4();
    final device = PairedDevice(
      id: deviceId,
      deviceName: req.deviceName,
      deviceType: req.deviceType,
      tokenHash: AuthTokens.hashToken(token),
      createdAt: now,
      lastSeenAt: now,
    );
    await _deviceDao.insert(device);

    req
      ..status = PairStatus.approved
      ..accessToken = token
      ..deviceId = deviceId;

    rotateCode(); // single-use: invalidate the code that was just used
    notifyListeners();
  }

  void reject(String requestId) {
    final req = _requests[requestId];
    if (req == null) return;
    req.status = PairStatus.rejected;
    notifyListeners();
  }

  /// Builds the status response for a polling mobile client.
  ///
  /// The token is returned while the request is approved so a lost HTTP
  /// response simply gets retried (LAN MVP). The plaintext is held only in
  /// memory and is dropped when the request is cleared.
  PairStatusResponse buildStatusResponse(String requestId) {
    final req = _requests[requestId];
    if (req == null) {
      return const PairStatusResponse(status: PairStatus.rejected);
    }
    if (req.status == PairStatus.approved) {
      return PairStatusResponse(
        status: PairStatus.approved,
        accessToken: req.accessToken,
      );
    }
    return PairStatusResponse(status: req.status);
  }

  /// Forgets a finished request (called after the mobile confirms receipt by
  /// re-polling, or periodically). Keeps the in-memory map from growing.
  void clearRequest(String requestId) {
    _requests.remove(requestId);
  }
}
