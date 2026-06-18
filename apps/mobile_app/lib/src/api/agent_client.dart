import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared/shared.dart';

import '../models/pc_connection.dart';

/// Thrown when an agent API call fails, with a user-friendly [message].
class AgentApiException implements Exception {
  AgentApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// HTTP client for the desktop agent API.
class AgentClient {
  AgentClient({http.Client? client, this.timeout = const Duration(seconds: 6)})
      : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;

  // ---- Unauthenticated (health + pairing) -------------------------------

  Future<HealthResponse> health(String baseUrl) async {
    final res = await _get(Uri.parse('$baseUrl${ApiPaths.health}'));
    return HealthResponse.fromJson(_decodeMap(res.body));
  }

  Future<PairRequestResponse> requestPair(String baseUrl, PairRequest req) async {
    final res = await _post(
      Uri.parse('$baseUrl${ApiPaths.pairRequest}'),
      body: req.toJson(),
    );
    if (res.statusCode == 403) {
      throw AgentApiException('페어링 코드가 올바르지 않거나 만료되었습니다.');
    }
    if (res.statusCode != 200) {
      throw AgentApiException('페어링 요청 실패 (${res.statusCode}).');
    }
    return PairRequestResponse.fromJson(_decodeMap(res.body));
  }

  Future<PairStatusResponse> pairStatus(String baseUrl, String requestId) async {
    final res = await _get(Uri.parse('$baseUrl${ApiPaths.pairStatus(requestId)}'));
    return PairStatusResponse.fromJson(_decodeMap(res.body));
  }

  // ---- Authenticated ----------------------------------------------------

  Future<List<AppListItem>> listApps(PcConnection pc) async {
    final res = await _get(
      Uri.parse('${pc.baseUrl}${ApiPaths.apps}'),
      token: pc.accessToken,
    );
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw AgentApiException('인증에 실패했습니다. PC를 다시 연결하세요.');
    }
    if (res.statusCode != 200) {
      throw AgentApiException('앱 목록을 불러오지 못했습니다 (${res.statusCode}).');
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! List) throw AgentApiException('잘못된 응답 형식입니다.');
    return decoded
        .whereType<Map>()
        .map((m) => AppListItem.fromJson(m.cast<String, Object?>()))
        .toList();
  }

  Future<LaunchResponse> launch(PcConnection pc, String appId) async {
    final res = await _post(
      Uri.parse('${pc.baseUrl}${ApiPaths.launch(appId)}'),
      token: pc.accessToken,
    );
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw AgentApiException('인증/권한 오류로 실행하지 못했습니다.');
    }
    final map = _decodeMap(res.body);
    final result = LaunchResponse.fromJson(map);
    if (!result.ok && res.statusCode >= 400) {
      throw AgentApiException(result.message.isEmpty ? '실행에 실패했습니다.' : result.message);
    }
    return result;
  }

  // ---- Internals --------------------------------------------------------

  Future<http.Response> _get(Uri uri, {String? token}) async {
    try {
      return await _client.get(uri, headers: _headers(token)).timeout(timeout);
    } catch (_) {
      throw AgentApiException('PC에 연결할 수 없습니다. 같은 와이파이인지 확인하세요.');
    }
  }

  Future<http.Response> _post(Uri uri, {Map<String, Object?>? body, String? token}) async {
    try {
      return await _client
          .post(uri, headers: _headers(token), body: body == null ? null : jsonEncode(body))
          .timeout(timeout);
    } catch (_) {
      throw AgentApiException('PC에 연결할 수 없습니다. 같은 와이파이인지 확인하세요.');
    }
  }

  Map<String, String> _headers(String? token) => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Map<String, Object?> _decodeMap(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) return decoded.cast<String, Object?>();
    } catch (_) {}
    return <String, Object?>{};
  }

  void close() => _client.close();
}
