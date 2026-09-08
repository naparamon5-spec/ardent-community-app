# Push Notifications & Calls — Complete Guide (Frontend + Backend, iOS & Android)

Everything needed for push notifications **and incoming-call ringing** in the
**Ardent Community** app on **both iOS and Android**: device-token registration,
the backend API contract, service-account credentials for sending, notification
sending, and the **call push** contract that makes calls ring when the app is
backgrounded, killed, or the phone is locked. Token registration mirrors the
**eforward app**, so one backend serves both apps (same Firebase project).

- **One Firebase project** (`ardent-community`), two apps: iOS
  (`com.ardentnetworks.community`) and Android
  (`com.ardentnetworks.ardent_community`).
- **FCM** delivers normal notifications to both platforms (iOS via APNs).
- **Calls** ring via the native call UI (iOS **CallKit** + **PushKit/VoIP**;
  Android full-screen incoming notification woken by a high-priority FCM **data**
  message). See §9.

### Credential map

| Credential | Purpose | Where it lives |
|-----------|---------|----------------|
| `GoogleService-Info.plist` / `google-services.json` | client config (app **receives**) | in the app ✅ |
| APNs `.p8` key (`22W6PB9G79`) | lets FCM reach Apple **and** signs VoIP pushes | uploaded to Firebase ✅; backend uses it for VoIP (§9) |
| Service account (`FCM_PROJECT_ID`/`FCM_CLIENT_EMAIL`/`FCM_PRIVATE_KEY`) | backend **sends** FCM | backend `.env` (§6) |

---

## 1. Token registration API

Both endpoints require the user's bearer token.

**Register / upsert:** `POST {API_BASE_URL}/users/fcm-token`

```
Authorization: Bearer <access_token>
Content-Type: application/json
```
```json
{
  "employee_id": "<user id>",
  "fcm_token":   "<FCM registration token>",
  "device_id":   "<stable per-device id>",
  "device_model":"<human-readable model>",
  "platform":    "ios" | "android",
  "voip_token":  "<iOS PushKit VoIP token — iOS only, optional>"
}
```
`2xx` = saved. The `voip_token` is present only on iOS and only once the VoIP
token is available; the backend needs it to send call pushes to iPhones (§9).

**Remove (logout):** `DELETE {API_BASE_URL}/users/fcm-token` — same body; delete
the row matching `employee_id` **and** `fcm_token`.

> The JSON key is `employee_id` to stay byte-compatible with eforward; it carries
> Ardent's user id (`AppSession.instance.me.id`).

---

## 2. SQL schema

```sql
CREATE TABLE user_fcm_tokens (
  fcm_token     VARCHAR(255) NOT NULL,
  employee_id   VARCHAR(64)  NOT NULL,
  device_id     VARCHAR(128),
  device_model  VARCHAR(128),
  platform      VARCHAR(16)  NOT NULL,       -- 'ios' | 'android'
  voip_token    VARCHAR(255),                -- iOS PushKit token (nullable)
  updated_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (fcm_token),
  INDEX idx_employee (employee_id)
);
```
- Register = upsert on `fcm_token`. Delete = by `employee_id` + `fcm_token`.
- Prune tokens FCM reports invalid when sending (§7).

---

## 3. Client registration flow (mirrors eforward)

Register on login, OTP, app-resume, and cold-start auto-login; remove on logout.
Idempotent (upsert), and re-registers automatically on FCM/VoIP token refresh.
On logout the client also deletes the token locally so a logged-out device stops
receiving pushes. **Already wired** in this app (AuthGate + `signOut`).

---

## 4. Device fields (`device_info_plus`)

| Platform | `device_id` | `device_model` |
|----------|-------------|----------------|
| Android | `androidInfo.id` | `"<brand> <model>"` |
| iOS | `iosInfo.identifierForVendor` | `iosInfo.utsname.machine` |

---

## 5. Frontend integration points (already implemented)

| Concern | Source |
|---------|--------|
| Base URL | `ApiConfig.baseUrl` (`lib/api/api_config.dart`) |
| Access token | `AuthStore.instance.token` (`lib/api/auth_store.dart`) |
| User id | `AppSession.instance.me.id` (`lib/api/session.dart`) |
| Token register/remove | `PushService` (`lib/services/push_service.dart`) |
| Notification display + badge | `PushService`, `AppBadge` (`lib/services/app_badge.dart`) |
| Incoming-call UI | `CallKitService` (`lib/calls/callkit_service.dart`), `CallController` |

---

## 6. Backend service-account credentials (backend sends FCM)

```env
FCM_PROJECT_ID=ardent-community
FCM_CLIENT_EMAIL=<client_email from the service-account JSON>
FCM_PRIVATE_KEY=<private_key from the service-account JSON>
```

Get the JSON: Firebase Console → project **ardent-community** → ⚙️ **Project
settings** → **Service accounts** → **Generate new private key**. Map
`project_id`/`client_email`/`private_key` to the vars above. Keep it in secrets,
never in git or the app.

⚠️ **Newline gotcha:** the private key has real newlines; store them escaped as
`\n` and restore in code:
```js
const privateKey = process.env.FCM_PRIVATE_KEY.replace(/\\n/g, '\n');
```

---

## 7. Sending a normal notification (backend)

```js
const admin = require('firebase-admin');
admin.initializeApp({
  credential: admin.credential.cert({
    projectId: process.env.FCM_PROJECT_ID,
    clientEmail: process.env.FCM_CLIENT_EMAIL,
    privateKey: process.env.FCM_PRIVATE_KEY.replace(/\\n/g, '\n'),
  }),
});

async function sendPush(fcmToken, title, body, data = {}) {
  try {
    await admin.messaging().send({
      token: fcmToken,
      notification: { title, body },
      data,                                    // string values only
      apns: { payload: { aps: { sound: 'default', badge: 1 } } },
      android: { priority: 'high', notification: { channelId: 'ardent_default' } },
    });
  } catch (err) {
    if (['messaging/registration-token-not-registered',
         'messaging/invalid-argument'].includes(err.code)) {
      await db.query('DELETE FROM user_fcm_tokens WHERE fcm_token = ?', [fcmToken]);
    } else { throw err; }
  }
}
```
- Android channel id is **`ardent_default`** (the app creates it).
- `apns.payload.aps.badge` sets the iOS icon badge; the app also syncs the badge
  to its unread count on its own.

---

## 8. Platform display notes

- **iOS:** Firebase is the sole notification delegate and displays alerts
  natively. The app does **not** init `flutter_local_notifications` on iOS
  (doing so breaks Firebase's delegate). Foreground alerts are enabled in
  `PushService`.
- **Android:** the app shows foreground/data notifications via
  `flutter_local_notifications` on channel `ardent_default`.

---

## 9. Incoming calls when killed / locked (the important part)

Normal FCM notifications can't ring a call on a killed/locked device. Two
mechanisms are used, and the **backend must send a call push on call start** (in
addition to the existing Socket.IO signaling, which only reaches an app that's
already open).

### Common call payload fields
| Field | Meaning |
|-------|---------|
| `callId` | the call's id (used to fetch the LiveKit token + signal accept/decline) |
| `callerName` | shown on the call screen |
| `kind` | `direct` or `group` |
| `groupId` | for group calls |
| `video` | `"true"` for a video call (optional) |

### Android — high-priority FCM **data** message
Send a **data-only** message (no `notification` block) at **high** priority to
each Android `fcm_token`. The app's background handler wakes and shows the
full-screen incoming-call UI.

```js
await admin.messaging().send({
  token: androidFcmToken,
  android: { priority: 'high' },
  data: {
    type: 'call',
    callId, callerName, kind, groupId,
    video: isVideo ? 'true' : 'false',
  },
});
```

### iOS — **VoIP push** via PushKit (uses the same `.p8` key)
iOS requires a **VoIP push** to ring a killed app. Send it over APNs to the
device's **`voip_token`** (registered in §1), token-authed with the same APNs
key `22W6PB9G79` / Team `K9973Z86YT`:

```
POST https://api.push.apple.com/3/device/<voip_token>      (or api.sandbox... for dev)
authorization: bearer <JWT signed with the .p8 key (kid=22W6PB9G79, iss=K9973Z86YT)>
apns-topic: com.ardentnetworks.community.voip
apns-push-type: voip
apns-priority: 10

{ "callId": "...", "callerName": "...", "kind": "direct", "groupId": "", "video": "false" }
```
- `apns-topic` **must** be the bundle id + `.voip`.
- The native app reports it to CallKit immediately (Apple requirement).

### What the app already does
- Shows the native call UI from the push (CallKit on iOS via the AppDelegate
  PushKit handler; full-screen notification on Android via the FCM background
  handler).
- **Accept** → joins the LiveKit room by `callId` (`POST /calls/:id/token`) and
  signals `callAccept`/`callGroupJoin` — works even from a cold launch.
- **Decline / timeout** → signals `callDecline` to the backend.
- Registers/refreshes the iOS `voip_token` and sends it in the token payload.

### Backend checklist for calls
1. On call start, in addition to socket signaling, **send a call push** to each
   of the callee's devices: VoIP push for iOS rows, high-priority data FCM for
   Android rows.
2. Keep handling `callAccept` / `callGroupJoin` / `callDecline` / `callEnd` from
   the socket as today — the app calls them after the user acts on the call UI.
3. If the call is answered elsewhere or cancelled, emit `call:taken` / `call:ended`
   so the app dismisses the native call UI on other devices.

---

## 10. Status recap

| Item | Status |
|------|--------|
| iOS/Android Firebase config + entitlements + APNs key | ✅ |
| Token register/remove (both platforms) | ✅ |
| App-icon badge synced to unread count | ✅ |
| Android foreground notification display | ✅ |
| Incoming-call UI (CallKit + PushKit / Android full-screen) | ✅ app side |
| Backend `POST`/`DELETE /users/fcm-token` (+ `voip_token`) | ⬜ backend |
| Backend service account + notification sending (§6–7) | ⬜ backend |
| Backend **call push** on call start (§9) | ⬜ backend |

---

### TL;DR for the backend
1. Implement `POST`/`DELETE /users/fcm-token` (§1), storing `voip_token` too.
2. Put the service-account creds in `.env` (§6) and send notifications via the
   Admin SDK (§7).
3. **On call start, send a call push** (§9): VoIP push to iOS `voip_token`s,
   high-priority `type:'call'` data FCM to Android `fcm_token`s. Same socket
   accept/decline handlers as today.
