import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:flutter/foundation.dart';

/// Keeps the home-screen app-icon badge in sync with the in-app unread
/// notification count. Safe to call from anywhere: it swallows platform errors
/// and no-ops on platforms/launchers that don't support badges.
///
/// iOS shows the exact number (requires the notification permission, already
/// requested by [PushService]). Many Android launchers only show a dot, or need
/// the count to ride on a posted notification — that's expected and harmless.
class AppBadge {
  AppBadge._();

  /// Sets the icon badge to [count]; clears it when [count] <= 0.
  static Future<void> set(int count) async {
    try {
      if (count > 0) {
        await AppBadgePlus.updateBadge(count);
      } else {
        await AppBadgePlus.updateBadge(0);
      }
    } catch (e) {
      debugPrint('[Badge] update failed: $e');
    }
  }

  /// Clears the icon badge (e.g. on logout).
  static Future<void> clear() => set(0);
}
