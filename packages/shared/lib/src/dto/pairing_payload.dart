import 'dart:convert';

import '../util/json_utils.dart';

/// The JSON payload encoded inside the pairing QR code shown by the desktop
/// agent and scanned by the mobile app.
class PairingPayload {
  const PairingPayload({
    required this.agentName,
    required this.host,
    required this.port,
    required this.pairingCode,
  });

  final String agentName;
  final String host;
  final int port;

  /// A random, single-use code that must be presented back via
  /// `POST /api/pair/request` to start pairing.
  final String pairingCode;

  factory PairingPayload.fromJson(Map<String, Object?> json) {
    return PairingPayload(
      agentName: JsonUtils.asString(json['agentName']),
      host: JsonUtils.asString(json['host']),
      port: JsonUtils.asInt(json['port'], fallback: 8765),
      pairingCode: JsonUtils.asString(json['pairingCode']),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'agentName': agentName,
        'host': host,
        'port': port,
        'pairingCode': pairingCode,
      };

  String encode() => jsonEncode(toJson());

  static PairingPayload? tryDecode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, Object?>) {
        return PairingPayload.fromJson(decoded);
      }
      if (decoded is Map) {
        return PairingPayload.fromJson(decoded.cast<String, Object?>());
      }
    } catch (_) {
      // Not a valid pairing QR.
    }
    return null;
  }
}
