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

  /// Tears down the connection. Call on sign-out; reconnect with fresh auth via
  /// [connect] afterwards.
  void disconnect() {
    _socket?.dispose();
    _socket = null;
  }
}
