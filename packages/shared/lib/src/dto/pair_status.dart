import '../util/json_utils.dart';

/// Possible states of a pairing request.
enum PairStatus {
  pending,
  approved,
  rejected;

  static PairStatus fromName(String value) {
    return PairStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => PairStatus.pending,
    );
  }
}

/// `GET /api/pair/status/{requestId}` response.
class PairStatusResponse {
  const PairStatusResponse({required this.status, this.accessToken});

  final PairStatus status;

  /// Present only when [status] is [PairStatus.approved].
  final String? accessToken;

  factory PairStatusResponse.fromJson(Map<String, Object?> json) {
    return PairStatusResponse(
      status: PairStatus.fromName(JsonUtils.asString(json['status'], fallback: 'pending')),
      accessToken: JsonUtils.asStringOrNull(json['accessToken']),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'status': status.name,
        if (accessToken != null) 'accessToken': accessToken,
      };
}
