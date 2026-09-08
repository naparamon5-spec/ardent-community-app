import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

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
///   - iOS:     ios/Runner/GoogleService-Info.plist   (add via Xcode)
///   - Android: android/app/google-services.json      (add + apply the
///              google-services Gradle plugin)
///
/// [PushService.init] is safe to call even before those files exist: it simply
/// logs and no-ops so the app keeps launching. Wire [onToken] to POST the token
/// to the backend so it can target this device.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  bool _initialised = false;
  String? _fcmToken;

  /// The current FCM registration token, if obtained. Send this to the backend.
  String? get fcmToken => _fcmToken;

  /// Called whenever a fresh FCM token is available (first fetch + refreshes).
  /// Set this to push the token to your backend, e.g. Api.instance.registerPush.
  Future<void> Function(String token)? onToken;

  /// Called when a notification is tapped and opens the app. Route from here.
  void Function(RemoteMessage message)? onOpened;

  Future<void> init() async {
    if (_initialised) return;
    try {
      await Firebase.initializeApp();
    } catch (e) {
      // No GoogleService-Info.plist / google-services.json yet, or a config
      // problem. Don't crash the app — push just stays inactive until fixed.
      debugPrint('[Push] Firebase.initializeApp failed ($e) — push disabled');
      return;
    }
    _initialised = true;

    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

    final messaging = FirebaseMessaging.instance;

    // Ask the user for permission (shows the iOS system prompt; on Android 13+
    // this drives the POST_NOTIFICATIONS runtime permission).
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('[Push] permission: ${settings.authorizationStatus}');

    // Show heads-up notifications while the app is in the foreground on iOS.
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // On iOS the FCM token is only available after the APNs token is set; fetch
    // it explicitly so we can surface a clear log if APNs isn't wired yet.
    if (Platform.isIOS) {
      final apns = await messaging.getAPNSToken();
      debugPrint('[Push] APNs token: ${apns ?? '<none — check capability/key>'}');
    }

    await _fetchAndReportToken(messaging);

    // Token can rotate; keep the backend in sync.
    messaging.onTokenRefresh.listen((token) {
      _fcmToken = token;
      debugPrint('[Push] token refreshed');
      _report(token);
    });

    // App opened from a notification while backgrounded.
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('[Push] opened from notification: ${message.messageId}');
      onOpened?.call(message);
    });

    // App launched cold from a notification.
    final initial = await messaging.getInitialMessage();
    if (initial != null) onOpened?.call(initial);

    // Foreground messages (app open and visible).
    FirebaseMessaging.onMessage.listen((message) {
      debugPrint('[Push] foreground message: ${message.notification?.title}');
    });
  }

  Future<void> _fetchAndReportToken(FirebaseMessaging messaging) async {
    try {
      final token = await messaging.getToken();
      if (token != null) {
        _fcmToken = token;
        debugPrint('[Push] FCM token: $token');
        _report(token);
      }
    } catch (e) {
      debugPrint('[Push] getToken failed: $e');
    }
  }

  void _report(String token) {
    final cb = onToken;
    if (cb != null) {
      cb(token).catchError(
        (e) => debugPrint('[Push] onToken handler failed: $e'),
      );
    }
  }
}
