import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';

/// Bridges native call UI (iOS **CallKit** / Android full-screen incoming-call
/// notification) to the app's call logic, so incoming calls ring even when the
/// app is backgrounded, killed, or the phone is locked.
///
/// The native UI is triggered by a push (iOS: VoIP/PushKit; Android:
/// high-priority FCM data message — see docs/FCM_PUSH_NOTIFICATIONS.md). When
/// the user accepts/declines from that UI, the callbacks here fire so
/// [CallController] can join or decline the real call.
class CallKitService {
  CallKitService._();
  static final CallKitService instance = CallKitService._();

  StreamSubscription<CallEvent?>? _sub;

  /// Maps the CallKit UUID → the app's real call payload, so an accept/decline
  /// coming back from the native UI can be resolved to the actual call.
  final Map<String, _PendingCall> _byUuid = {};

  /// Fired when the user accepts from the native call UI.
  void Function(String callId, String kind, String groupId)? onAccept;

  /// Fired when the user declines/ends from the native call UI.
  void Function(String callId)? onDecline;

  /// Fired when the iOS VoIP (PushKit) token becomes available or changes, so
  /// it can be (re-)registered with the backend for sending VoIP pushes.
  void Function(String voipToken)? onVoipToken;

  /// Start listening for CallKit/notification actions. Safe to call repeatedly.
  void listen() {
    _sub ??= FlutterCallkitIncoming.onEvent.listen(_handle);
  }

  void _handle(CallEvent? event) {
    if (event == null) return;
    switch (event) {
      case CallEventActionDidUpdateDevicePushTokenVoip():
        getVoipToken().then((t) {
          if (t != null) onVoipToken?.call(t);
        });
        break;
      case CallEventActionCallAccept(:final callKitParams):
        final p = _resolve(callKitParams);
        if (p != null) onAccept?.call(p.callId, p.kind, p.groupId);
        break;
      case CallEventActionCallDecline(:final callKitParams):
        final p = _resolve(callKitParams);
        if (p != null) onDecline?.call(p.callId);
        _byUuid.remove(callKitParams.id);
        break;
      case CallEventActionCallEnded(:final callKitParams):
        // Ended from the native UI — treat as a decline so the caller and
        // backend learn the callee didn't pick up.
        final p = _resolve(callKitParams);
        if (p != null) onDecline?.call(p.callId);
        _byUuid.remove(callKitParams.id);
        break;
      case CallEventActionCallTimeout(:final id):
        // Ring timed out (missed). Only the CallKit UUID is provided.
        final p = _byUuid[id];
        if (p != null) onDecline?.call(p.callId);
        _byUuid.remove(id);
        break;
      default:
        break;
    }
  }

  _PendingCall? _resolve(CallKitParams params) {
    final byId = _byUuid[params.id];
    if (byId != null) return byId;
    // Cold-launch from a push: state map is empty, so recover from `extra`.
    final extra = params.extra;
    if (extra == null) return null;
    return _PendingCall(
      callId: '${extra['callId'] ?? ''}',
      kind: '${extra['kind'] ?? 'direct'}',
      groupId: '${extra['groupId'] ?? ''}',
    );
  }

  /// Display the native incoming-call UI for [callId].
  Future<void> showIncoming({
    required String callId,
    required String callerName,
    String avatarUrl = '',
    String kind = 'direct',
    String groupId = '',
    bool isVideo = false,
  }) async {
    final uuid = _uuidV4();
    _byUuid[uuid] = _PendingCall(callId: callId, kind: kind, groupId: groupId);

    final params = CallKitParams(
      id: uuid,
      nameCaller: callerName.isEmpty ? 'Incoming call' : callerName,
      appName: 'Ardent',
      avatar: avatarUrl.isEmpty ? null : avatarUrl,
      handle: kind == 'group' ? 'Group call' : 'Ardent call',
      type: isVideo ? 1 : 0,
      duration: 45000,
      extra: {'callId': callId, 'kind': kind, 'groupId': groupId},
      ios: const IOSParams(
        handleType: 'generic',
        supportsVideo: true,
        maximumCallGroups: 1,
        maximumCallsPerCallGroup: 1,
        audioSessionMode: 'default',
        configureAudioSession: true,
      ),
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        isShowCallID: false,
        isImportant: true,
        isBot: false,
        // Full-screen incoming UI even over the lock screen.
        isShowFullLockedScreen: true,
        ringtonePath: 'system_ringtone_default',
        backgroundColor: '#0B2A4A',
        actionColor: '#4CAF50',
        textAccept: 'Accept',
        textDecline: 'Decline',
        incomingCallNotificationChannelName: 'Incoming Calls',
        missedCallNotificationChannelName: 'Missed Calls',
      ),
    );
    await FlutterCallkitIncoming.showCallkitIncoming(params);
  }

  /// Dismiss the native call UI for a specific app call id (all matching UUIDs).
  Future<void> endCall(String callId) async {
    final uuids =
        _byUuid.entries.where((e) => e.value.callId == callId).map((e) => e.key);
    for (final id in uuids.toList()) {
      try {
        await FlutterCallkitIncoming.endCall(id);
      } catch (_) {}
      _byUuid.remove(id);
    }
  }

  /// Dismiss every native call UI (e.g. on logout).
  Future<void> endAll() async {
    try {
      await FlutterCallkitIncoming.endAllCalls();
    } catch (_) {}
    _byUuid.clear();
  }

  /// The iOS VoIP (PushKit) token, needed by the backend to send VoIP pushes.
  /// Returns null on Android / when unavailable.
  Future<String?> getVoipToken() async {
    if (!Platform.isIOS) return null;
    try {
      final token = await FlutterCallkitIncoming.getDevicePushTokenVoIP();
      return (token == null || token.isEmpty) ? null : token;
    } catch (e) {
      debugPrint('[CallKit] getVoipToken failed: $e');
      return null;
    }
  }

  /// RFC 4122 v4 UUID (CallKit requires a UUID id) without adding a dependency.
  String _uuidV4() {
    final r = Random.secure();
    final b = List<int>.generate(16, (_) => r.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    String hex(int i) => b[i].toRadixString(16).padLeft(2, '0');
    final s = b.asMap().keys.map(hex).join();
    return '${s.substring(0, 8)}-${s.substring(8, 12)}-${s.substring(12, 16)}'
        '-${s.substring(16, 20)}-${s.substring(20)}';
  }
}

class _PendingCall {
  _PendingCall({required this.callId, required this.kind, required this.groupId});
  final String callId;
  final String kind;
  final String groupId;
}
