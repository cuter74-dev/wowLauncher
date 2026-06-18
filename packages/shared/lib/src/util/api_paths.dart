/// Centralised definition of the HTTP API surface so the desktop server and the
/// mobile client never disagree on paths.
class ApiPaths {
  ApiPaths._();

  static const String health = '/api/health';
  static const String apps = '/api/apps';
  static const String pairRequest = '/api/pair/request';

  /// `POST /api/apps/{id}/launch`
  static String launch(String appId) => '/api/apps/$appId/launch';

  /// `GET /api/pair/status/{requestId}`
  static String pairStatus(String requestId) => '/api/pair/status/$requestId';
}
