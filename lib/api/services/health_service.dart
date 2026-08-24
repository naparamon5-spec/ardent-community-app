import '../api_client.dart';

/// Health & Presence — liveness and "who's online".
///
/// See docs §Health & Presence. Both routes are public (no token).
class HealthService {
  HealthService(this._api);
  final ApiClient _api;

  /// `GET /health` — liveness + DB connectivity + current online-user count.
  Future<Map<String, dynamic>> health() async =>
      Map<String, dynamic>.from(await _api.get('/health') as Map);

  /// `GET /presence` — `{ online: [userId, ...] }`, ids currently connected
  /// over WebSocket.
  Future<List<String>> presence() async {
    final data = await _api.get('/presence');
    final online = (data is Map ? data['online'] : data) as List? ?? const [];
    return online.map((e) => '$e').toList();
  }
}
