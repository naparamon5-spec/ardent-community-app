# FCM Push Notifications — Backend & Client Contract

This document defines how the **Ardent Community** app registers device push
tokens with the backend and how the backend delivers push notifications. It is
intentionally **identical to the eforward app** so a single backend
implementation/pattern can serve both apps.

- **One Firebase project** (`ardent-community`) with **two apps registered**:
  iOS (`com.ardentnetworks.community`) and Android
  (`com.ardentnetworks.ardent_community`).
- **FCM (Firebase Cloud Messaging)** is the single send path for **both**
  platforms. On iOS, FCM relays to **APNs**; on Android it delivers directly.
- The backend stores one row **per device** (multi-device per user) and sends
  to every stored token for a target user.

---

## 1. Backend API contract

Two endpoints, matching eforward exactly. Both require the authenticated user's
bearer token.

### Register / upsert a device token

```
POST {API_BASE_URL}/users/fcm-token
```

**Headers**

```
Authorization: Bearer <access_token>
Content-Type: application/json
Accept: application/json
```

**Body**

```json
{
  "employee_id": "<user id>",
  "fcm_token":   "<FCM registration token>",
  "device_id":   "<stable per-device id>",
  "device_model":"<human-readable model>",
  "platform":    "ios" | "android"
}
```

**Success:** any `2xx`. The client treats `200–299` as saved; anything else as
failed (and logs the status + body).

> **Field naming:** the field is called `employee_id` to stay byte-for-byte
> compatible with the eforward backend. In Ardent Community it carries the app
> user's id (`AppSession.instance.me.id`). Keep the JSON key `employee_id` so
> both apps hit the same schema; map it to your users table as appropriate.

### Remove the current device token (on logout)

```
DELETE {API_BASE_URL}/users/fcm-token
```

Same headers and **same body** as register. The backend deletes only the row
matching **`employee_id` AND `fcm_token`** (so other devices of the same user
keep working).

---

## 2. Suggested SQL schema

Multi-device: the primary key is the token (a token is globally unique to one
device install), and a user may own many.

```sql
CREATE TABLE user_fcm_tokens (
  fcm_token     VARCHAR(255) NOT NULL,        -- PK: unique per device install
  employee_id   VARCHAR(64)  NOT NULL,        -- the app user id
  device_id     VARCHAR(128),                 -- identifierForVendor / Android id
  device_model  VARCHAR(128),
  platform      VARCHAR(16)  NOT NULL,        -- 'ios' | 'android'
  updated_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (fcm_token),
  INDEX idx_employee (employee_id)
);
```

- **Register** = `INSERT ... ON DUPLICATE KEY UPDATE` (upsert on `fcm_token`),
  refreshing `employee_id`, `device_model`, `platform`, `updated_at`. This
  correctly re-assigns a token if the same device is used by a new account.
- **Delete** = `DELETE WHERE employee_id = ? AND fcm_token = ?`.
- Prune tokens FCM reports as unregistered/invalid when you send (see §6).

---

## 3. Client registration flow (mirrors eforward)

The client calls **register** whenever it has a valid session, and **remove** on
logout.

| Moment | Call |
|--------|------|
| After login succeeds | `registerToken(userId)` |
| After OTP / re-auth | `registerToken(userId)` |
| App resume (foreground) with a live session | `registerToken(userId)` |
| Dashboard/home load | `registerToken(userId)` |
| FCM token refresh (`onTokenRefresh`) | `registerToken(userId)` |
| Logout | `removeToken(userId)` |

Registration is **idempotent** (upsert), so calling it on every resume is safe
and self-healing.

**On logout**, the client both (a) tells the backend to delete the row, and
(b) calls `FirebaseMessaging.instance.deleteToken()` so the device stops
receiving pushes even if the network delete failed. A fresh token is generated
after the next login re-registers.

---

## 4. Device info fields

Collected via `device_info_plus` (same as eforward):

| Platform | `device_id` | `device_model` |
|----------|-------------|----------------|
| Android | `androidInfo.id` | `"<brand> <model>"` |
| iOS | `iosInfo.identifierForVendor` (`"unknown"` if null) | `iosInfo.utsname.machine` |

---

## 5. Ardent Community integration points

Where the values come from **in this app** (they differ from eforward's classes,
but the payload sent to the backend is identical):

| Value | Source in this repo |
|-------|---------------------|
| Base URL | `ApiConfig.baseUrl` — already includes the `/api` prefix (`lib/api/api_config.dart`) |
| Access token | `AuthStore.instance.token` (`lib/api/auth_store.dart`) |
| User id (`employee_id`) | `AppSession.instance.me.id` (`lib/api/session.dart`) |
| FCM token / refresh | `PushService` (`lib/services/push_service.dart`) |

`PushService` already fetches the token and exposes an `onToken` hook. Wire it to
POST the payload above, e.g. in `main.dart`:

```dart
PushService.instance.onToken = (token) async {
  final userId = AppSession.instance.me.id;
  if (userId.isEmpty) return;                    // not logged in yet
  final device = await DeviceInfoUtil.current(); // add device_info_plus
  await Api.instance /* or a raw http.post */ .post(
    '/users/fcm-token',
    body: {
      'employee_id':  userId,
      'fcm_token':    token,
      'device_id':    device['deviceId'],
      'device_model': device['deviceModel'],
      'platform':     Platform.isIOS ? 'ios' : 'android',
    },
  );
};
```

> To match eforward 1:1, add the `device_info_plus` package and a
> `DeviceInfoUtil.current()` helper returning `{deviceId, deviceModel}` (see §4).
> Also call the register/remove hooks at the login/logout/resume points in §3.

---

## 6. Sending a push from the backend (FCM HTTP v1)

Send to each stored `fcm_token` for the target user. Use the Firebase Admin SDK
or the HTTP v1 API with a service-account token.

```json
POST https://fcm.googleapis.com/v1/projects/ardent-community/messages:send
Authorization: Bearer <OAuth2 access token from service account>
Content-Type: application/json

{
  "message": {
    "token": "<the device fcm_token>",
    "notification": { "title": "New message", "body": "You have an update" },
    "data": { "type": "chat", "groupId": "123" },
    "apns": {
      "payload": { "aps": { "sound": "default", "badge": 1 } }
    },
    "android": {
      "priority": "high",
      "notification": { "channel_id": "ardent_default" }
    }
  }
}
```

- **iOS** requires the APNs auth key uploaded to Firebase (already done: key
  `22W6PB9G79`, Team `K9973Z86YT`). The app's `aps-environment` is `production`
  in release builds, so TestFlight/App Store builds receive production pushes.
- **Android** should specify a `channel_id` that the app has created.
- If FCM returns `UNREGISTERED` / `INVALID_ARGUMENT` for a token, **delete that
  row** — the install is gone.

---

## 7. Platform display notes (important, from eforward)

- **iOS:** Firebase is the sole `UNUserNotificationCenterDelegate` and displays
  notifications natively. **Do NOT initialize `flutter_local_notifications` on
  iOS** — its `initialize()` replaces Firebase's delegate and silently breaks all
  iOS notifications. Foreground presentation is enabled via
  `setForegroundNotificationPresentationOptions` (already set in `PushService`).
- **Android:** create a high-importance `AndroidNotificationChannel` and use
  `flutter_local_notifications` to display messages while the app is in the
  foreground/background isolate. The top-level
  `@pragma('vm:entry-point')` background handler must initialize that plugin in
  its own isolate before calling `show()`.

---

## 8. Required config recap

| Item | Status |
|------|--------|
| iOS `GoogleService-Info.plist` in `ios/Runner/` (bundled) | ✅ |
| Android `google-services.json` in `android/app/` | ✅ |
| iOS Push Notifications capability + `aps-environment` entitlement | ✅ |
| Android google-services Gradle plugin | ✅ |
| APNs `.p8` key uploaded to Firebase (`22W6PB9G79` / `K9973Z86YT`) | ✅ |
| Backend `POST`/`DELETE /users/fcm-token` implemented | ⬜ backend team |
| Client `onToken` wired to the backend + register/remove call sites | ⬜ see §5 |

---

### TL;DR for the backend team
Implement **`POST /users/fcm-token`** and **`DELETE /users/fcm-token`** exactly
as eforward: bearer-authed, JSON body `{employee_id, fcm_token, device_id,
device_model, platform}`, multi-device rows keyed by `fcm_token`. Send via FCM
to every token for a user. This is the **same contract for both iOS and
Android** — the only per-platform difference is the `platform` field value and
the display notes in §7.
