import 'package:socket_io_client/socket_io_client.dart' as io;

import '../api_config.dart';
import '../auth_store.dart';

/// Real-time presence + group chat over Socket.IO. See docs §Real-time.
///
/// Connects to the API origin (not the `/api` REST base) with the JWT in the
/// handshake `auth`. Emits:
/// * `presence:snapshot` `{ online: [...] }` — ids online right now
/// * `presence:update`   `{ online: [...] }` — ids changed
///
/// Group chat events share this same authenticated connection and are scoped to
/// group membership; register handlers for them via [on].
class RealtimeService {
  RealtimeService({AuthStore? authStore})
      : _auth = authStore ?? AuthStore.instance;

  final AuthStore _auth;
  io.Socket? _socket;

  /// Whether a live socket connection currently exists.
  bool get isConnected => _socket?.connected ?? false;

  /// Opens the socket using the current [AuthStore] token. No-op if already
  /// connected. Safe to call again after [disconnect].
  void connect() {
    if (_socket != null) return;
    final token = _auth.token;
    _socket = io.io(
      ApiConfig.origin,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );
    _socket!.connect();
  }

  /// Registers [handler] for a server event (e.g. `presence:snapshot`,
  /// `presence:update`, or a group-chat event).
  void on(String event, void Function(dynamic data) handler) =>
      _socket?.on(event, handler);

  /// Removes handler(s) for [event].
  void off(String event) => _socket?.off(event);

  /// Emits [event] to the server (e.g. joining a group room, if supported).
  void emit(String event, [dynamic data]) => _socket?.emit(event, data);

  /// Convenience: subscribe to presence snapshots + updates in one call. The
  /// callback receives the list of online user ids.
  void onPresence(void Function(List<String> online) handler) {
    List<String> ids(dynamic data) {
      final online = (data is Map ? data['online'] : data) as List? ?? const [];
      return online.map((e) => '$e').toList();
    }

    on('presence:snapshot', (d) => handler(ids(d)));
    on('presence:update', (d) => handler(ids(d)));
  }

  // ---- Voice / video calls (LiveKit) ----------------------------------------
  //
  // Media runs through LiveKit (an SFU), not peer-to-peer WebRTC — so this
  // socket now only handles *ringing*. The old `call:offer`/`call:answer`/
  // `call:ice` relay events were removed; after accepting or starting a call,
  // fetch a room token via `POST /calls/:id/token` (see [CallsService.token])
  // and connect to LiveKit directly. Client → server events take an
  // acknowledgement callback with `{ ok: true, ... }` or
  // `{ ok: false, error: '<code>' }`. Register the server → client events
  // (`call:incoming`, `call:accepted`, `call:taken`, `call:ended`) with [on].
  //
  // Calling is feature-flagged off unless the server has `CALLS_ENABLED=true`
  // and LiveKit configured — these emits are no-ops otherwise.

  /// `call:invite` — start ringing [calleeId] (1:1). Ack:
  /// `{ ok, callId, status: 'ringing' | 'missed' }` or `{ ok: false, error }`
  /// (`not_allowed`, `invalid_callee`, `no_such_user`, `busy`, `failed`).
  void callInvite(String calleeId, {void Function(dynamic ack)? ack}) =>
      _socket?.emitWithAck('call:invite', {'calleeId': calleeId}, ack: ack);

  /// `call:accept` — callee accepts a 1:1 ring. Ack
  /// `{ ok: false, error: 'too_late' }` if another of the callee's own tabs
  /// already answered. After accepting, call `POST /calls/:id/token` to join.
  void callAccept(String callId, {void Function(dynamic ack)? ack}) =>
      _socket?.emitWithAck('call:accept', {'callId': callId}, ack: ack);

  /// `call:group-start` — start (or rejoin + re-ring) a group call for
  /// [groupId]. Requires active membership. Ack
  /// `{ ok, callId, joined, invited? }` or `{ ok: false, error }`
  /// (`not_allowed`, `invalid_group`, `not_a_member`, `busy`, `failed`). Group
  /// calls have no ring timeout. Join via `POST /calls/:id/token` afterwards.
  void callGroupStart(String groupId, {void Function(dynamic ack)? ack}) =>
      _socket?.emitWithAck('call:group-start', {'groupId': groupId}, ack: ack);

  /// `call:group-join` — join a group call already in progress for [groupId]
  /// without a fresh invite. Ack `{ ok, callId }` or
  /// `{ ok: false, error: 'not_a_member' | 'no_call' | 'failed' }`.
  void callGroupJoin(String groupId, {void Function(dynamic ack)? ack}) =>
      _socket?.emitWithAck('call:group-join', {'groupId': groupId}, ack: ack);

  /// `call:decline` — decline a ringing 1:1 call, or (on a group call) dismiss
  /// only your own invitation without ending it for anyone else.
  void callDecline(String callId, {void Function(dynamic ack)? ack}) =>
      _socket?.emitWithAck('call:decline', {'callId': callId}, ack: ack);

  /// `call:end` — hang up a 1:1 call (either party), or (on a group call) leave
  /// it. A group room only closes once LiveKit reports it empty.
  void callEnd(String callId, {void Function(dynamic ack)? ack}) =>
      _socket?.emitWithAck('call:end', {'callId': callId}, ack: ack);

  /// Tears down the connection. Call on sign-out; reconnect with fresh auth via
  /// [connect] afterwards.
  void disconnect() {
    _socket?.dispose();
    _socket = null;
  }
}
