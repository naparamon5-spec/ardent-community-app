import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as webrtc;
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';

import '../api/api.dart';
import '../data/mappers.dart';
import '../data/seed.dart';
import '../theme/ardent_colors.dart';
import '../screens/call_screen.dart';
import '../screens/mini_call_bar.dart';

/// Where a call is in its lifecycle.
enum CallPhase { idle, outgoing, incoming, active, ended }

/// App-wide voice/video call coordinator. Bridges the Socket.IO ringing events
/// (invite/accept/decline/end — see docs §Voice Calls) to a single full-screen
/// [CallScreen], and runs the actual media over **LiveKit** once a call is
/// answered: after reaching the `active` phase it fetches a room token
/// (`POST /calls/:id/token`) and connects, publishing the microphone (and the
/// camera on request).
///
/// Works for both 1:1 and group calls — a direct call rings one callee, a group
/// call rings every other member; both join the same LiveKit room.
class CallController extends ChangeNotifier {
  CallController._();
  static final CallController instance = CallController._();

  GlobalKey<NavigatorState>? _navKey;
  bool _routeOpen = false;

  // ---- Public call state (read by CallScreen) --------------------------------
  CallPhase phase = CallPhase.idle;
  String callId = '';
  String kind = 'direct'; // 'direct' | 'group'
  bool outgoing = true;

  /// The other party for a direct call, or the caller for an incoming one.
  String peerName = '';
  String peerInitials = '';
  String peerAvatarUrl = '';
  Color peerColor = ArdentColors.navy700;

  /// The group, for a group call.
  String groupName = '';

  /// A human-readable error/status shown briefly on failure.
  String? statusMessage;

  // ---- Media state -----------------------------------------------------------
  Room? room;
  EventsListener<RoomEvent>? _roomEvents;
  bool connectingMedia = false;
  bool micEnabled = true;
  bool cameraEnabled = false;
  bool speakerOn = true;
  bool screenShareEnabled = false;
  String? mediaError;

  /// Whether the full-screen call UI is minimized to a floating bar.
  bool minimized = false;

  bool _bgInitialized = false;
  String _pendingGroupId = '';

  bool get isBusy => phase != CallPhase.idle;

  LocalParticipant? get localParticipant => room?.localParticipant;
  List<RemoteParticipant> get remoteParticipants =>
      room?.remoteParticipants.values.toList() ?? const [];

  /// Wire the socket listeners, after the realtime connection is up. Safe to call
  /// repeatedly. [navKey] is the app's root navigator, used to show the call UI
  /// from outside any screen's own context.
  void init(GlobalKey<NavigatorState> navKey) {
    _navKey = navKey;
    // Re-wire every time — a sign-out/-in creates a fresh socket, so handlers
    // must be re-registered onto it. `off` first avoids stacking duplicates.
    final rt = Api.instance.realtime;
    for (final e in const [
      'call:incoming',
      'call:accepted',
      'call:taken',
      'call:ended'
    ]) {
      rt.off(e);
    }
    rt.on('call:incoming', _onIncoming);
    rt.on('call:accepted', _onAccepted);
    rt.on('call:taken', _onTaken);
    rt.on('call:ended', _onEnded);
  }

  // ---- Outgoing --------------------------------------------------------------

  /// Start a 1:1 call to [callee]. Rings their devices via `call:invite`.
  Future<void> startDirect(Person callee, {bool video = false}) async {
    if (isBusy || callee.id.isEmpty) return;
    _reset();
    kind = 'direct';
    outgoing = true;
    cameraEnabled = video;
    phase = CallPhase.outgoing;
    peerName = callee.name;
    peerInitials = callee.initials;
    peerAvatarUrl = callee.avatarUrl;
    peerColor = callee.color;
    _showUi();
    notifyListeners();

    Api.instance.realtime.callInvite(callee.id, ack: (ack) {
      final map = _asMap(ack);
      if (map['ok'] == true) {
        callId = '${map['callId'] ?? ''}';
        if ('${map['status']}' == 'missed') {
          _fail('${callee.name} isn\'t available right now.');
        }
      } else {
        _fail(_errorText('${map['error']}', callee.name));
      }
    });
  }

  /// Start a group call for [group]. Rings every other active member via
  /// `call:group-start`.
  Future<void> startGroup(Group group, {bool video = false}) async {
    if (isBusy || group.id.isEmpty) return;
    _reset();
    kind = 'group';
    outgoing = true;
    cameraEnabled = video;
    phase = CallPhase.outgoing;
    groupName = group.name;
    peerName = group.name;
    peerInitials = initialsFrom(group.name);
    peerColor = group.color;
    _showUi();
    notifyListeners();

    Api.instance.realtime.callGroupStart(group.id, ack: (ack) {
      final map = _asMap(ack);
      if (map['ok'] == true) {
        callId = '${map['callId'] ?? ''}';
        // A group call has no single callee to "accept" — the starter is in the
        // room as soon as it's created; others ring and join independently.
        _goActive();
      } else {
        _fail(_errorText('${map['error']}', group.name));
      }
    });
  }

  // ---- Callee actions --------------------------------------------------------

  /// Accept an incoming call and join the media room.
  void accept() {
    if (phase != CallPhase.incoming || callId.isEmpty) return;
    if (kind == 'group') {
      Api.instance.realtime.callGroupJoin(_pendingGroupId);
    } else {
      Api.instance.realtime.callAccept(callId);
    }
    _goActive();
  }

  /// Decline an incoming call (or dismiss your own ring on a group call).
  void decline() {
    if (callId.isNotEmpty) Api.instance.realtime.callDecline(callId);
    _end();
  }

  /// Hang up / leave the current call.
  void hangUp() {
    if (callId.isNotEmpty) Api.instance.realtime.callEnd(callId);
    _end();
  }

  // ---- Media controls --------------------------------------------------------

  Future<void> toggleMic() async {
    micEnabled = !micEnabled;
    notifyListeners();
    try {
      await room?.localParticipant?.setMicrophoneEnabled(micEnabled);
    } catch (_) {}
  }

  Future<void> toggleCamera() async {
    final turningOn = !cameraEnabled;
    if (turningOn) {
      final cam = await Permission.camera.request();
      if (!cam.isGranted) {
        mediaError = 'Camera permission denied.';
        notifyListeners();
        return;
      }
    }
    cameraEnabled = turningOn;
    notifyListeners();
    try {
      await room?.localParticipant?.setCameraEnabled(cameraEnabled);
    } catch (_) {}
  }

  Future<void> toggleSpeaker() async {
    speakerOn = !speakerOn;
    notifyListeners();
    try {
      // ignore: deprecated_member_use
      await Hardware.instance.setSpeakerphoneOn(speakerOn);
    } catch (_) {}
  }

  /// Start/stop sharing this device's screen into the call (like the web app's
  /// "Share screen"). On Android this runs a media-projection foreground
  /// service so capture survives backgrounding; on iOS it needs a Broadcast
  /// Upload Extension (a native target) — without one, this fails gracefully.
  Future<void> toggleScreenShare() async {
    final lp = room?.localParticipant;
    if (lp == null) return;

    if (screenShareEnabled) {
      try {
        await lp.setScreenShareEnabled(false);
      } catch (_) {}
      screenShareEnabled = false;
      if (Platform.isAndroid) {
        try {
          await FlutterBackground.disableBackgroundExecution();
        } catch (_) {}
      }
      notifyListeners();
      return;
    }

    try {
      if (Platform.isAndroid) {
        // Android: ask for screen-capture consent, then bring up the
        // media-projection foreground service before publishing.
        final granted = await webrtc.Helper.requestCapturePermission();
        if (!granted) {
          mediaError = 'Screen share was not allowed.';
          notifyListeners();
          return;
        }
        final ready = await _ensureBackgroundService();
        if (!ready) {
          mediaError = 'Couldn\'t start screen sharing.';
          notifyListeners();
          return;
        }
      }
      // iOS presents the system broadcast picker here (needs the Broadcast
      // Upload Extension configured — see ios/BroadcastExtension/README.md).
      await lp.setScreenShareEnabled(true);
      screenShareEnabled = true;
      mediaError = null;
      notifyListeners();
    } catch (e) {
      screenShareEnabled = false;
      if (Platform.isAndroid) {
        try {
          await FlutterBackground.disableBackgroundExecution();
        } catch (_) {}
      }
      mediaError = Platform.isIOS
          ? 'Screen sharing on iOS needs a broadcast extension.'
          : 'Screen share unavailable.';
      notifyListeners();
    }
  }

  Future<bool> _ensureBackgroundService() async {
    if (!_bgInitialized) {
      const config = FlutterBackgroundAndroidConfig(
        notificationTitle: 'Ardent call',
        notificationText: 'Sharing your screen',
        notificationImportance: AndroidNotificationImportance.normal,
        notificationIcon: AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
        shouldRequestBatteryOptimizationsOff: false,
      );
      _bgInitialized = await FlutterBackground.initialize(androidConfig: config);
    }
    if (!_bgInitialized) return false;
    if (FlutterBackground.isBackgroundExecutionEnabled) return true;
    return FlutterBackground.enableBackgroundExecution();
  }

  // ---- Minimize / full screen ------------------------------------------------

  /// Collapse the full-screen call UI to a floating bar over the app, keeping
  /// the call live. Tapping the bar (or [maximize]) restores full screen.
  void minimize() {
    if (minimized || !isBusy) return;
    minimized = true;
    // Pop the full-screen route without ending the call (a programmatic pop
    // does not trip CallScreen's back-to-hang-up guard), then float the bar.
    if (_routeOpen) {
      _navKey?.currentState?.pop();
      _routeOpen = false;
    }
    _showMiniBar();
    notifyListeners();
  }

  /// Restore the full-screen call UI from the minimized bar.
  void maximize() {
    if (!minimized) return;
    minimized = false;
    _removeMiniBar();
    _showUi();
    notifyListeners();
  }

  OverlayEntry? _miniBar;

  void _showMiniBar() {
    final overlay = _navKey?.currentState?.overlay;
    if (overlay == null || _miniBar != null) return;
    _miniBar = OverlayEntry(builder: (_) => const MiniCallBar());
    overlay.insert(_miniBar!);
  }

  void _removeMiniBar() {
    _miniBar?.remove();
    _miniBar = null;
  }

  // ---- Media connection ------------------------------------------------------

  void _goActive() {
    phase = CallPhase.active;
    statusMessage = null;
    notifyListeners();
    _connectMedia();
  }

  Future<void> _connectMedia() async {
    if (callId.isEmpty || room != null) return;
    connectingMedia = true;
    mediaError = null;
    notifyListeners();

    // Runtime permissions (Android needs an explicit prompt before capture).
    final mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      mediaError = 'Microphone permission is required for calls.';
      connectingMedia = false;
      notifyListeners();
      return;
    }
    if (cameraEnabled) await Permission.camera.request();

    // 1) Fetch a LiveKit room token from the API.
    String url;
    String token;
    try {
      final res = await Api.instance.calls.token(callId);
      url = _adjustLiveKitUrl('${res['url'] ?? ''}'.trim());
      token = '${res['token'] ?? ''}'.trim();
      debugPrint('[Call] token ok: url=$url room=${res['room']} '
          'tokenLen=${token.length}');
    } catch (e, st) {
      debugPrint('[Call] token fetch failed: $e\n$st');
      _mediaFail(e is ApiException
          ? e.message
          : 'Couldn\'t reach the call server.');
      return;
    }
    if (url.isEmpty || token.isEmpty) {
      _mediaFail('Calling isn\'t configured on the server.');
      return;
    }
    // Bail out if the call was cancelled while the token was in flight.
    if (phase != CallPhase.active) return;

    // 2) Connect to the LiveKit room and publish local media.
    final r = Room(
      roomOptions: const RoomOptions(adaptiveStream: true, dynacast: true),
    );
    _roomEvents = r.createListener();
    _roomEvents!
      ..on<RoomDisconnectedEvent>((_) => _end())
      ..on<ParticipantConnectedEvent>((_) => notifyListeners())
      ..on<ParticipantDisconnectedEvent>((_) => notifyListeners())
      ..on<TrackSubscribedEvent>((_) => notifyListeners())
      ..on<TrackUnsubscribedEvent>((_) => notifyListeners())
      ..on<TrackMutedEvent>((_) => notifyListeners())
      ..on<TrackUnmutedEvent>((_) => notifyListeners());
    r.addListener(_onRoomChange);

    try {
      await r.connect(url, token);
      // The call may have ended while connecting — don't leave a live room.
      if (phase != CallPhase.active) {
        await r.disconnect();
        await r.dispose();
        return;
      }
      room = r;
      await r.localParticipant?.setMicrophoneEnabled(micEnabled);
      if (cameraEnabled) {
        await r.localParticipant?.setCameraEnabled(true);
      }
      try {
        // ignore: deprecated_member_use
        await Hardware.instance.setSpeakerphoneOn(speakerOn);
      } catch (_) {}
      connectingMedia = false;
      notifyListeners();
    } catch (e, st) {
      debugPrint('[Call] LiveKit connect failed (url=$url): $e\n$st');
      try {
        await _roomEvents?.dispose();
      } catch (_) {}
      _roomEvents = null;
      r.removeListener(_onRoomChange);
      try {
        await r.dispose();
      } catch (_) {}
      _mediaFail(_connectErrorText(e));
    }
  }

  void _mediaFail(String message) {
    mediaError = message;
    connectingMedia = false;
    notifyListeners();
  }

  /// Normalizes the LiveKit URL for the device: LiveKit expects a WebSocket URL
  /// (`ws://`/`wss://`), and the Android emulator can't reach the host machine's
  /// `localhost` (10.0.2.2 is its alias). A correct production `wss://…` URL is
  /// left as-is.
  String _adjustLiveKitUrl(String url) {
    var u = url.trim();
    if (u.isEmpty) return u;
    // LiveKit's client wants a ws(s) scheme, not http(s).
    if (u.startsWith('https://')) {
      u = 'wss://${u.substring(8)}';
    } else if (u.startsWith('http://')) {
      u = 'ws://${u.substring(7)}';
    } else if (!u.contains('://')) {
      u = 'wss://$u';
    }
    if (Platform.isAndroid) {
      u = u
          .replaceFirst('localhost', '10.0.2.2')
          .replaceFirst('127.0.0.1', '10.0.2.2');
    }
    return u;
  }

  /// A short, human-readable reason for a LiveKit connection failure.
  String _connectErrorText(Object e) {
    final s = e.toString().toLowerCase();
    // Microphone/audio-engine failures (e.g. the iOS Simulator's missing
    // voice-processing unit, code -4010, or a denied mic permission). Check
    // this first: these are NOT authorization problems.
    if (s.contains('audioprocessingexception') ||
        s.contains('audio engine') ||
        s.contains('-4010') ||
        s.contains('startcapture')) {
      return 'Microphone unavailable. Check mic permission, or try a real '
          'device — the iOS Simulator can\'t capture call audio.';
    }
    if (s.contains('timeout') || s.contains('timed out')) {
      return 'Call server timed out. Check your connection.';
    }
    // Only treat this as an auth failure on a genuine auth signal. (A plain
    // 'token' substring is too broad — LiveKit connection/signaling errors
    // mention "token" without being authorization failures.)
    if (s.contains('unauthorized') ||
        s.contains('401') ||
        s.contains('invalid token') ||
        s.contains('token expired') ||
        s.contains('token is invalid')) {
      return 'Call authorization failed.';
    }
    return 'Couldn\'t connect the call audio.';
  }

  void _onRoomChange() => notifyListeners();

  Future<void> _teardownMedia() async {
    final r = room;
    final listener = _roomEvents;
    room = null;
    _roomEvents = null;
    r?.removeListener(_onRoomChange);
    try {
      await listener?.dispose();
    } catch (_) {}
    try {
      await r?.disconnect();
    } catch (_) {}
    try {
      await r?.dispose();
    } catch (_) {}
  }

  // ---- Socket events ---------------------------------------------------------

  void _onIncoming(dynamic data) {
    if (isBusy) return; // already on a call → mirrors "busy"
    final map = _asMap(data);
    _reset();
    callId = '${map['callId'] ?? ''}';
    kind = '${map['kind'] ?? 'direct'}' == 'group' ? 'group' : 'direct';
    outgoing = false;
    phase = CallPhase.incoming;
    final caller = _asMap(map['caller']);
    peerName = '${caller['name'] ?? 'Someone'}';
    peerInitials = initialsFrom(peerName);
    peerColor = avatarColorFor('${caller['id'] ?? peerName}');
    peerAvatarUrl = '${caller['avatarUrl'] ?? ''}';
    if (kind == 'group') {
      final group = _asMap(map['group']);
      _pendingGroupId = '${group['id'] ?? ''}';
      groupName = '${group['name'] ?? ''}';
    }
    _showUi();
    notifyListeners();
  }

  void _onAccepted(dynamic data) {
    if (phase == CallPhase.outgoing && _matches(data)) _goActive();
  }

  void _onTaken(dynamic data) {
    if (phase == CallPhase.incoming && _matches(data)) _end();
  }

  void _onEnded(dynamic data) {
    if (!isBusy || !_matches(data)) return;
    final status = '${_asMap(data)['status'] ?? ''}';
    if (status == 'declined') {
      statusMessage = 'Call declined.';
    } else if (status == 'missed') {
      statusMessage = 'No answer.';
    }
    _end();
  }

  // ---- Helpers ---------------------------------------------------------------

  bool _matches(dynamic data) {
    final id = '${_asMap(data)['callId'] ?? ''}';
    return id.isEmpty || callId.isEmpty || id == callId;
  }

  void _fail(String message) {
    statusMessage = message;
    phase = CallPhase.ended;
    notifyListeners();
    Future.delayed(const Duration(milliseconds: 1800), _end);
  }

  void _end() {
    _teardownMedia();
    _removeMiniBar();
    if (Platform.isAndroid && screenShareEnabled) {
      // Stop the media-projection foreground service on hang-up.
      FlutterBackground.disableBackgroundExecution().catchError((_) => false);
    }
    phase = CallPhase.ended;
    notifyListeners();
    _dismissUi();
    _reset();
    notifyListeners();
  }

  void _reset() {
    phase = CallPhase.idle;
    callId = '';
    kind = 'direct';
    outgoing = true;
    peerName = '';
    peerInitials = '';
    peerAvatarUrl = '';
    peerColor = ArdentColors.navy700;
    groupName = '';
    _pendingGroupId = '';
    connectingMedia = false;
    micEnabled = true;
    cameraEnabled = false;
    speakerOn = true;
    screenShareEnabled = false;
    minimized = false;
    // statusMessage / mediaError are left for the UI to show briefly.
  }

  void _showUi() {
    final nav = _navKey?.currentState;
    if (nav == null || _routeOpen) return;
    _routeOpen = true;
    nav
        .push(MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => const CallScreen(),
        ))
        .then((_) => _routeOpen = false);
  }

  void _dismissUi() {
    if (!_routeOpen) return;
    _navKey?.currentState?.pop();
    _routeOpen = false;
  }

  String _errorText(String code, String who) {
    switch (code) {
      case 'busy':
        return '$who is on another call.';
      case 'not_allowed':
      case 'not_a_member':
        return 'You can\'t call here.';
      case 'invalid_callee':
      case 'invalid_group':
      case 'no_such_user':
        return 'Couldn\'t reach $who.';
      default:
        return 'Call failed. Please try again.';
    }
  }

  Map _asMap(dynamic v) => v is Map ? v : const {};
}
