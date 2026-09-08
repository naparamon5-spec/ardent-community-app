import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../api/api.dart';
import '../calls/callkit_service.dart';
import '../utils/device_info_util.dart';

/// True when a push is a call invite the app should ring for.
bool _isCallMessage(RemoteMessage m) => m.data['type'] == 'call';

/// Show the native incoming-call UI (CallKit / full-screen notification) from a
/// call push's data payload. Works from the background isolate on Android.
Future<void> _showCallFromMessage(RemoteMessage m) async {
  await CallKitService.instance.showIncoming(
    callId: '${m.data['callId'] ?? ''}',
    callerName:
        '${m.data['callerName'] ?? m.data['caller'] ?? 'Incoming call'}',
    avatarUrl: '${m.data['avatarUrl'] ?? ''}',
    kind: '${m.data['kind'] ?? 'direct'}',
    groupId: '${m.data['groupId'] ?? ''}',
    isVideo: '${m.data['video'] ?? ''}' == 'true',
  );
}

/// Android channel used to display foreground/data push notifications. Its id
/// must match the `channel_id` the backend sets in the FCM `android` block.
const AndroidNotificationChannel kDefaultChannel = AndroidNotificationChannel(
  'ardent_default',
  'General Notifications',
  description: 'Community updates, messages, and alerts',
  importance: Importance.high,
);

/// Android-only local-notifications plugin. On iOS, Firebase is the sole
/// notification delegate and displays alerts natively — initializing this on
/// iOS would replace Firebase's delegate and silently break iOS notifications.
final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

/// Handles messages that arrive while the app is terminated or backgrounded.
///
/// Must be a top-level (or static) function annotated with
/// [pragma('vm:entry-point')] so it survives release tree-shaking and can be
/// invoked in its own isolate by the platform.
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  // The isolate is fresh, so Firebase must be initialised here too.
  await Firebase.initializeApp();
  debugPrint('[Push] background message: ${message.messageId}');
  // A call invite → ring with the native call UI even when killed/locked.
  // (On iOS this path is handled natively by PushKit/VoIP; here it covers
  // Android's high-priority data message waking this background isolate.)
  if (_isCallMessage(message)) {
    await _showCallFromMessage(message);
    return;
  }
  // Android: a data-only message won't be auto-displayed by the system, so show
  // it ourselves. (A message carrying a `notification` block is displayed by the
  // OS while backgrounded, so we skip it here to avoid a duplicate.) On iOS,
  // APNs already displayed it — nothing to do.
  if (!Platform.isIOS && message.notification == null) {
    await _showAndroidNotification(message);
  }
}

/// Displays a heads-up notification on Android from a [RemoteMessage].
Future<void> _showAndroidNotification(RemoteMessage message) async {
  final n = message.notification;
  final title = n?.title ?? message.data['title'] as String? ?? 'Ardent';
  final body = n?.body ?? message.data['body'] as String? ?? '';
  await _localNotifications.show(
    id: message.hashCode,
    title: title,
    body: body,
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        kDefaultChannel.id,
        kDefaultChannel.name,
        channelDescription: kDefaultChannel.description,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
    ),
    payload: message.data.isNotEmpty ? message.data.toString() : null,
  );
}

/// Firebase Cloud Messaging wrapper for the app.
///
/// One Firebase *project* serves both platforms; native config supplies the
/// credentials at runtime:
///   - iOS:     ios/Runner/GoogleService-Info.plist
///   - Android: android/app/google-services.json  (+ google-services plugin)
///
/// Backend registration matches the eforward app 1:1 — see
/// docs/FCM_PUSH_NOTIFICATIONS.md. Call [init] once at startup (permission +
/// listeners), then [registerToken] whenever a user session is active (login,
/// resume) and [removeToken] on logout.
///
/// [init] is safe to call even before the native config files exist: it logs
/// and no-ops so the app keeps launching.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  // Resolved lazily via a getter, NOT an eager field initializer: touching
  // `FirebaseMessaging.instance` before `Firebase.initializeApp()` throws
  // `No Firebase App '[DEFAULT]'`. Since `PushService.instance` is accessed in
  // main() before init() runs, an eager field would crash at construction.
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  bool _initialised = false;
  String? _fcmToken;
  String? _lastUserId; // remembered so token refreshes can re-register.
  bool _refreshHooked = false;

  /// The current FCM registration token, if obtained.
  String? get fcmToken => _fcmToken;

  /// Called when a notification is tapped and opens the app. Route from here.
  void Function(RemoteMessage message)? onOpened;

  /// Called whenever a push arrives while the app is in the foreground. Wire
  /// this to refresh the unread count so the in-app + icon badge stay in sync.
  void Function(RemoteMessage message)? onForegroundMessage;

  /// One-time setup: Firebase init, permission prompt, and message listeners.
  /// Does NOT register with the backend — call [registerToken] once a user is
  /// authenticated.
  Future<void> init() async {
    if (_initialised) return;
    try {
      await Firebase.initializeApp();
    } catch (e) {
      // No config files yet, or a config problem. Don't crash — push stays
      // inactive until fixed.
      debugPrint('[Push] Firebase.initializeApp failed ($e) — push disabled');
      return;
    }
    _initialised = true;

    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

    // Android only: set up the local-notifications plugin + channel so we can
    // display foreground and data-only pushes. Never on iOS (see the note on
    // [_localNotifications]).
    if (!Platform.isIOS) {
      await _initAndroidNotifications();
    }

    // Ask the user for permission (iOS system prompt; Android 13+ runtime
    // POST_NOTIFICATIONS permission).
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('[Push] permission: ${settings.authorizationStatus}');

    // Show heads-up notifications while the app is in the foreground on iOS.
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // App opened from a notification while backgrounded.
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('[Push] opened from notification: ${message.messageId}');
      onOpened?.call(message);
    });

    // App launched cold from a notification.
    final initial = await _messaging.getInitialMessage();
    if (initial != null) onOpened?.call(initial);

    // Foreground messages (app open and visible).
    FirebaseMessaging.onMessage.listen((message) async {
      debugPrint('[Push] foreground message: ${message.notification?.title}');
      // A call invite while the app is open is handled by the in-app call UI
      // (the realtime socket delivers `call:incoming`); don't also ring CallKit.
      if (_isCallMessage(message)) return;
      // iOS presents the alert itself (setForegroundNotificationPresentationOptions);
      // on Android we must display it manually.
      if (!Platform.isIOS) {
        await _showAndroidNotification(message);
      }
      // Keep the unread count / badge in sync with the new arrival.
      onForegroundMessage?.call(message);
    });
  }

  /// Initialises the Android local-notifications plugin and default channel.
  Future<void> _initAndroidNotifications() async {
    await _localNotifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (response) {
        debugPrint('[Push] local notification tapped: ${response.payload}');
      },
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(kDefaultChannel);
  }

  /// Registers/upserts this device's FCM token against the backend for [userId].
  /// Idempotent — safe to call on every login and app resume. Returns `true`
  /// only when the backend accepted the token.
  Future<bool> registerToken(String userId) async {
    if (userId.isEmpty) return false;
    if (!_initialised) await init();
    if (!_initialised) return false; // Firebase unavailable.

    try {
      // On iOS the FCM token is only available after the APNs token is set.
      if (Platform.isIOS) {
        final apns = await _messaging.getAPNSToken();
        if (apns == null) {
          debugPrint('[Push] APNs token not ready yet — will retry on refresh');
        }
      }

      final token = await _messaging.getToken();
      if (token == null) {
        debugPrint('[Push] could not get FCM token');
        return false;
      }
      _fcmToken = token;
      _lastUserId = userId;

      final payload = await _payload(userId, token);
      await Api.instance.users.registerFcmToken(payload);
      debugPrint('[Push] token registered for $userId');

      _hookRefresh();
      // iOS: re-register when the VoIP (PushKit) token arrives or changes, so
      // the backend can send VoIP call pushes.
      if (Platform.isIOS) {
        CallKitService.instance.onVoipToken = (_) {
          final uid = _lastUserId;
          if (uid != null && uid.isNotEmpty) registerToken(uid);
        };
      }
      return true;
    } catch (e) {
      debugPrint('[Push] registerToken failed: $e');
      return false;
    }
  }

  /// Removes only this device's token from the backend (on logout), then
  /// invalidates the token locally so the device stops receiving pushes even if
  /// the backend delete failed. A fresh token is generated after the next login.
  Future<void> removeToken(String userId) async {
    try {
      final token = _fcmToken ?? await _messaging.getToken();
      if (userId.isNotEmpty && token != null) {
        try {
          await Api.instance.users.removeFcmToken(await _payload(userId, token));
          debugPrint('[Push] token removed from backend');
        } catch (e) {
          debugPrint('[Push] backend token delete failed ($e); '
              'still invalidating on device');
        }
      }
    } finally {
      try {
        await _messaging.deleteToken();
      } catch (_) {}
      _fcmToken = null;
      _lastUserId = null;
    }
  }

  /// Builds the backend payload — matches the eforward app, plus an optional
  /// iOS `voip_token` the backend uses to send VoIP (PushKit) call pushes so
  /// calls ring when the app is killed/locked. See docs/FCM_PUSH_NOTIFICATIONS.md.
  Future<Map<String, dynamic>> _payload(String userId, String token) async {
    final device = await DeviceInfoUtil.current();
    final payload = <String, dynamic>{
      'employee_id': userId,
      'fcm_token': token,
      'device_id': device['deviceId'],
      'device_model': device['deviceModel'],
      'platform': Platform.isIOS ? 'ios' : 'android',
    };
    if (Platform.isIOS) {
      final voip = await CallKitService.instance.getVoipToken();
      if (voip != null) payload['voip_token'] = voip;
    }
    return payload;
  }

  /// Re-register automatically when Google rotates the token.
  void _hookRefresh() {
    if (_refreshHooked) return;
    _refreshHooked = true;
    _messaging.onTokenRefresh.listen((newToken) async {
      _fcmToken = newToken;
      debugPrint('[Push] token refreshed');
      final uid = _lastUserId;
      if (uid != null && uid.isNotEmpty) {
        await registerToken(uid);
      }
    });
  }
}
