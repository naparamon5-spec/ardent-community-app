import 'package:flutter/foundation.dart';

import '../data/mappers.dart';
import '../data/seed.dart';
import '../theme/ardent_colors.dart';
import 'api.dart';

/// The signed-in user for the current session.
///
/// Wraps `GET /auth/me` and exposes the current [Person] to the UI. A single
/// [AppSession.instance] is shared app-wide and is a [ChangeNotifier] so screens
/// rebuild when the profile loads or changes.
class AppSession extends ChangeNotifier {
  AppSession._();

  static final AppSession instance = AppSession._();

  static const Person _fallback = Person(
    id: 'me',
    name: 'You',
    initials: 'ME',
    role: 'Community Member',
    color: ArdentColors.navy700,
    online: true,
    lastActive: 'Active now',
  );

  Person? _me;
  int _unreadNotifications = 0;

  /// The current user, or a neutral placeholder until `/auth/me` resolves.
  Person get me => _me ?? _fallback;

  /// Whether the real profile has been loaded from the server.
  bool get isReady => _me != null;

  /// Unread notifications count for the signed-in user.
  int get unreadNotifications => _unreadNotifications;

  /// Updates the unread notifications count and notifies listeners.
  void setUnreadNotifications(int count) {
    final clamped = count.clamp(0, 999999);
    if (_unreadNotifications != clamped) {
      _unreadNotifications = clamped;
      notifyListeners();
    }
  }

  /// Decrements unread notifications count by [amount].
  void decrementUnreadNotifications([int amount = 1]) {
    if (_unreadNotifications > 0) {
      _unreadNotifications = (_unreadNotifications - amount).clamp(0, 999999);
      notifyListeners();
    }
  }

  /// Fetches the latest unread notifications count from `/notifications/unread-count`.
  Future<void> refreshUnreadNotifications() async {
    try {
      final res = await Api.instance.notifications.unreadCount();
      int count = 0;
      if (res is num) {
        count = res.toInt();
      } else if (res is Map) {
        final val = res['unreadCount'] ??
            res['unread_count'] ??
            res['count'] ??
            res['unread'];
        if (val is num) count = val.toInt();
        if (val is String) count = int.tryParse(val) ?? 0;
      }
      setUnreadNotifications(count);
    } catch (_) {
      // Non-critical; ignore network/auth errors.
    }
  }

  /// Sets the current user from a login/register/`/auth/me` payload. Accepts
  /// either the user object directly or a `{ user: {...} }` wrapper
  /// (`present.user` shape).
  void setFromJson(dynamic json) {
    final map = asMap(json);
    _me = personFromJson(map['user'] ?? map);
    notifyListeners();
  }

  /// Fetches the current profile from the backend. Call after sign-in or at
  /// startup when a token is already held.
  Future<void> loadMe() async {
    final data = await Api.instance.auth.me();
    setFromJson(data);
    refreshUnreadNotifications();
  }

  /// Clears the session, token, and realtime connection.
  Future<void> signOut() async {
    _me = null;
    _unreadNotifications = 0;
    Api.instance.realtime.disconnect();
    await Api.instance.auth.logout();
    notifyListeners();
  }
}
