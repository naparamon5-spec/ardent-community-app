import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../api/api.dart';
import '../utils/device_info_util.dart';

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

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  bool _initialised = false;
  String? _fcmToken;
  String? _lastUserId; // remembered so token refreshes can re-register.
  bool _refreshHooked = false;

  /// The current FCM registration token, if obtained.
  String? get fcmToken => _fcmToken;

  /// Called when a notification is tapped and opens the app. Route from here.
  void Function(RemoteMessage message)? onOpened;

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
    FirebaseMessaging.onMessage.listen((message) {
      debugPrint('[Push] foreground message: ${message.notification?.title}');
    });
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

  /// Builds the backend payload — identical shape to the eforward app so both
  /// apps share one backend contract (docs/FCM_PUSH_NOTIFICATIONS.md).
  Future<Map<String, dynamic>> _payload(String userId, String token) async {
    final device = await DeviceInfoUtil.current();
    return {
      'employee_id': userId,
      'fcm_token': token,
      'device_id': device['deviceId'],
      'device_model': device['deviceModel'],
      'platform': Platform.isIOS ? 'ios' : 'android',
    };
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
