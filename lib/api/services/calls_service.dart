import '../api_client.dart';

/// Voice/video calling — REST side, covering both 1:1 and group calls. See docs
/// §Voice Calls. All routes require `module:calls.use`, which is **feature-
/// flagged off by default** — stripped from every user (admins included) unless
/// the server has `CALLS_ENABLED=true` and a fully configured LiveKit media
/// server. If it isn't enabled, `calls.use` won't appear in anyone's modules and
/// these routes are unreachable.
///
/// Media runs through **LiveKit** (an SFU), not peer-to-peer WebRTC. The old
/// `GET /calls/ice-servers` endpoint and the `call:offer`/`call:answer`/
/// `call:ice` relay events were removed in that change. The Socket.IO
/// connection now only handles *ringing* (invite/accept/decline/hang-up — see
/// [RealtimeService]); joining the actual audio/video room uses a signed token
/// from [token], handed to LiveKit directly.
class CallsService {
  CallsService(this._api);
  final ApiClient _api;

  /// `POST /calls/:id/token` — a short-lived token letting this device join the
  /// call's LiveKit room. Returns `{ token, url, room }` where `url` is the
  /// LiveKit server URL and `room` the derived room name. Eligibility is
  /// re-checked every call (direct: caller or callee; group: active membership);
  /// 400 if the call has already ended. Call this after accepting/starting a
  /// call, then connect to LiveKit with the returned token.
  Future<Map<String, dynamic>> token(String callId) async =>
      Map<String, dynamic>.from(
          await _api.post('/calls/$callId/token') as Map);

  /// `GET /calls?before=&limit=&userId=` — your call history (direct calls you
  /// were on + group calls you took part in), newest first. [before] is an ISO
  /// `startedAt` cursor; [limit] default 30 (max 100). [userId] is **admin
  /// only** — everyone else only ever sees calls they were actually on. A direct
  /// row's `peer` names the *other* party; a group row carries `group`/
  /// `participants` instead.
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
