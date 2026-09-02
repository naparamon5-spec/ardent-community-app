import '../api_client.dart';

/// 1:1 voice calling — REST side. See docs §Voice Calls. All routes require
/// `module:calls.use` (on by default for everyone).
///
/// Only ICE configuration and call history live over REST. Everything about a
/// call *in progress* (ringing, answering, hanging up, and the WebRTC
/// handshake) happens over the Socket.IO connection — see [RealtimeService]'s
/// call helpers. The audio itself never passes through the server; once both
/// peers exchange SDP/ICE they connect peer-to-peer (or via TURN if configured).
class CallsService {
  CallsService(this._api);
  final ApiClient _api;

  /// `GET /calls/ice-servers` — what the browser needs to find a path to its
  /// peer: `{ iceServers: [...], turnConfigured }`. STUN is always included; a
  /// TURN relay is added only if configured server-side, with time-limited
  /// credentials.
  Future<Map<String, dynamic>> iceServers() async =>
      Map<String, dynamic>.from(await _api.get('/calls/ice-servers') as Map);

  /// `GET /calls?before=&limit=&userId=` — your call history (both directions),
  /// newest first. [before] is an ISO `startedAt` cursor; [limit] default 30
  /// (max 100). [userId] is **admin only** — everyone else only ever sees calls
  /// they were actually on. Each row's `peer` names the *other* party.
  Future<List<dynamic>> history({
    String? before,
    int? limit,
    String? userId,
  }) async {
    final data = await _api.get('/calls', query: {
      'before': before,
      'limit': limit,
      'userId': userId,
    });
    return data is List ? data : const [];
  }
}
