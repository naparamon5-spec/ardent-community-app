import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

/// Shared device-identification helper. Returns a stable per-device id and a
/// human-readable model, used when registering the FCM push token with the
/// backend (see docs/FCM_PUSH_NOTIFICATIONS.md). Mirrors the eforward app so
/// both apps send the same device fields to the same backend contract.
class DeviceInfoUtil {
  DeviceInfoUtil._();

  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  static Future<Map<String, String>> current() async {
    if (Platform.isAndroid) {
      final info = await _deviceInfo.androidInfo;
      return {
        'deviceId': info.id,
        'deviceModel': '${info.brand} ${info.model}',
      };
    } else if (Platform.isIOS) {
      final info = await _deviceInfo.iosInfo;
      return {
        'deviceId': info.identifierForVendor ?? 'unknown',
        'deviceModel': info.utsname.machine,
      };
    }
    return {'deviceId': 'unknown', 'deviceModel': 'unknown'};
  }
}
