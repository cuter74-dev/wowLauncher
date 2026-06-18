import '../util/json_utils.dart';

/// `POST /api/pair/request` body.
class PairRequest {
  const PairRequest({
    required this.pairingCode,
    required this.deviceName,
    required this.deviceType,
  });

  final String pairingCode;
  final String deviceName;

  /// `ios` | `android`.
  final String deviceType;

  factory PairRequest.fromJson(Map<String, Object?> json) {
    return PairRequest(
      pairingCode: JsonUtils.asString(json['pairingCode']),
      deviceName: JsonUtils.asString(json['deviceName']),
      deviceType: JsonUtils.asString(json['deviceType']),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'pairingCode': pairingCode,
        'deviceName': deviceName,
        'deviceType': deviceType,
      };
}

/// `POST /api/pair/request` response.
class PairRequestResponse {
  const PairRequestResponse({required this.requestId, required this.status});

  final String requestId;
  final String status; // pending

  factory PairRequestResponse.fromJson(Map<String, Object?> json) {
    return PairRequestResponse(
      requestId: JsonUtils.asString(json['requestId']),
      status: JsonUtils.asString(json['status'], fallback: 'pending'),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'requestId': requestId,
        'status': status,
      };
}
