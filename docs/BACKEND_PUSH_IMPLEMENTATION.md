# Backend Implementation Guide — Push Notifications & Calls

For the **backend team**. This is the complete list of what to **add and do** on
the backend so the Ardent Community mobile app can receive push notifications and
ring incoming calls when the app is backgrounded, killed, or the phone is locked.

The **mobile app side is already done**. The backend needs: two token endpoints,
a DB table, Firebase service-account credentials, notification sending, and — the
important new part — **sending a call push when a call starts**.

Shared with the eforward app: the token endpoints and payload are identical, so
one implementation can serve both apps (same Firebase project `ardent-community`).

---

## 0. Task checklist

- [ ] **DB:** add the `user_fcm_tokens` table (§2).
- [ ] **API:** implement `POST /users/fcm-token` and `DELETE /users/fcm-token` (§3).
- [ ] **Secrets:** add the Firebase service-account env vars (§4).
- [ ] **Send notifications:** via the Firebase Admin SDK (§5).
- [ ] **Send call pushes on call start** — VoIP push (iOS) + high-priority data
      FCM (Android) (§6). ← the key new work.
- [ ] Keep the existing Socket.IO call accept/decline/end handlers (§7).
- [ ] Prune invalid tokens when sending (§5, §6).

---

## 1. How it fits together

```
Something happens (message / call) ──> BACKEND looks up the user's device rows
        │                                      │
        │ normal notification                  │ call
        ▼                                      ▼
   FCM notification  ──────────────►    iOS: APNs VoIP push (PushKit) ─► CallKit
   (iOS+Android)                        Android: high-priority data FCM ─► full-screen UI
```

- The app **registers each device** (its FCM token, and on iOS a VoIP token) via
  the endpoints in §3. Store them.
- To notify, **send to every stored token** for the target user.
- The app already handles displaying everything and, for calls, joining/declining.

---

## 2. Database

```sql
CREATE TABLE user_fcm_tokens (
  fcm_token     VARCHAR(255) NOT NULL,        -- unique per device install (PK)
  employee_id   VARCHAR(64)  NOT NULL,        -- the app user id
  device_id     VARCHAR(128),
  device_model  VARCHAR(128),
  platform      VARCHAR(16)  NOT NULL,        -- 'ios' | 'android'
  voip_token    VARCHAR(255),                 -- iOS PushKit token (nullable)
  updated_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (fcm_token),
  INDEX idx_employee (employee_id)
);
```

Multi-device: one user may have many rows. `voip_token` is only set on iOS.

---

## 3. Token endpoints

Both require the caller's bearer token (the app sends `Authorization: Bearer …`).
Resolve the authenticated user and trust `employee_id` from the body (it is the
app user's id).

### `POST /users/fcm-token` — register / upsert

Request body:
```json
{
  "employee_id": "<user id>",
  "fcm_token":   "<FCM token>",
  "device_id":   "<device id>",
  "device_model":"<model>",
  "platform":    "ios" | "android",
  "voip_token":  "<iOS VoIP token, optional>"
}
```

Upsert on `fcm_token`:
```sql
INSERT INTO user_fcm_tokens (fcm_token, employee_id, device_id, device_model, platform, voip_token)
VALUES (?, ?, ?, ?, ?, ?)
ON DUPLICATE KEY UPDATE
  employee_id = VALUES(employee_id),
  device_id = VALUES(device_id),
  device_model = VALUES(device_model),
  platform = VALUES(platform),
  voip_token = COALESCE(VALUES(voip_token), voip_token),
  updated_at = CURRENT_TIMESTAMP;
```
Return `200`.

### `DELETE /users/fcm-token` — remove one device (logout)

Same body. Delete only the matching row:
```sql
DELETE FROM user_fcm_tokens WHERE employee_id = ? AND fcm_token = ?;
```
Return `200`.

---

## 4. Firebase service-account credentials (secrets)

Firebase Console → project **ardent-community** → ⚙️ **Project settings** →
**Service accounts** → **Generate new private key** → download the JSON. Put in
the backend `.env` / secrets (never in git):

```env
FCM_PROJECT_ID=ardent-community
FCM_CLIENT_EMAIL=<client_email from the JSON>
FCM_PRIVATE_KEY=<private_key from the JSON>
```

⚠️ **Newline gotcha:** the private key has real newlines. Store escaped as `\n`
and restore in code (`process.env.FCM_PRIVATE_KEY.replace(/\\n/g, '\n')`).
Skipping this causes `invalid_grant` / `DECODER` errors.

---

## 5. Sending a normal notification (Node / firebase-admin)

```js
const admin = require('firebase-admin');
admin.initializeApp({
  credential: admin.credential.cert({
    projectId: process.env.FCM_PROJECT_ID,
    clientEmail: process.env.FCM_CLIENT_EMAIL,
    privateKey: process.env.FCM_PRIVATE_KEY.replace(/\\n/g, '\n'),
  }),
});

async function notifyUser(employeeId, title, body, data = {}) {
  const rows = await db.query(
    'SELECT fcm_token FROM user_fcm_tokens WHERE employee_id = ?', [employeeId]);
  await Promise.all(rows.map(async ({ fcm_token }) => {
    try {
      await admin.messaging().send({
        token: fcm_token,
        notification: { title, body },
        data,                                       // string values only
        apns: { payload: { aps: { sound: 'default', badge: 1 } } },
        android: { priority: 'high', notification: { channelId: 'ardent_default' } },
      });
    } catch (err) {
      if (['messaging/registration-token-not-registered',
           'messaging/invalid-argument'].includes(err.code)) {
        await db.query('DELETE FROM user_fcm_tokens WHERE fcm_token = ?', [fcm_token]);
      } else { throw err; }
    }
  }));
}
```
- Android notification channel id is **`ardent_default`** (the app creates it).
- `aps.badge` sets the iOS icon badge.

---

## 6. Sending a CALL push on call start ← key new work

When a call starts, **in addition to** the existing socket `call:incoming`
signaling (which only reaches an already-open app), send a **call push** to each
of the callee's devices so the phone rings even when killed/locked.

Look up the callee's rows and branch by platform:

```js
async function ringUser(employeeId, call) {
  // call = { callId, callerName, kind: 'direct'|'group', groupId, video: bool }
  const rows = await db.query(
    'SELECT platform, fcm_token, voip_token FROM user_fcm_tokens WHERE employee_id = ?',
    [employeeId]);
  await Promise.all(rows.map(r =>
    r.platform === 'ios' ? sendVoipPush(r.voip_token, call)
                         : sendAndroidCallData(r.fcm_token, call)));
}
```

### 6a. Android — high-priority **data** message (FCM)

Data-only (no `notification` block), priority `high`:

```js
async function sendAndroidCallData(fcmToken, call) {
  await admin.messaging().send({
    token: fcmToken,
    android: { priority: 'high' },
    data: {
      type: 'call',
      callId: call.callId,
      callerName: call.callerName,
      kind: call.kind,
      groupId: call.groupId || '',
      video: call.video ? 'true' : 'false',
    },
  });
}
```

### 6b. iOS — **VoIP push** via APNs + PushKit

iOS needs a **VoIP push** to ring a killed app. Send it to the device's
`voip_token`, token-authed with the **same APNs `.p8` key** already uploaded to
Firebase (Key ID `22W6PB9G79`, Team `K9973Z86YT`). This is a direct APNs HTTP/2
call (the Firebase Admin SDK does **not** send VoIP pushes).

```js
const http2 = require('http2');
const jwt = require('jsonwebtoken');   // or sign ES256 manually

// Cache the bearer JWT for up to ~50 min.
function apnsJwt() {
  return jwt.sign({ iss: 'K9973Z86YT', iat: Math.floor(Date.now() / 1000) }, APNS_P8_KEY, {
    algorithm: 'ES256',
    header: { alg: 'ES256', kid: '22W6PB9G79' },
  });
}

async function sendVoipPush(voipToken, call) {
  if (!voipToken) return;
  const host = 'https://api.push.apple.com';   // 'https://api.sandbox.push.apple.com' for dev
  const client = http2.connect(host);
  const body = JSON.stringify({
    callId: call.callId,
    callerName: call.callerName,
    kind: call.kind,
    groupId: call.groupId || '',
    video: call.video ? 'true' : 'false',
  });
  const req = client.request({
    ':method': 'POST',
    ':path': `/3/device/${voipToken}`,
    'authorization': `bearer ${apnsJwt()}`,
    'apns-topic': 'com.ardentnetworks.community.voip',   // bundle id + .voip
    'apns-push-type': 'voip',
    'apns-priority': '10',
    'content-type': 'application/json',
  });
  req.setEncoding('utf8');
  req.write(body); req.end();
  req.on('response', h => { if (h[':status'] !== 200) {/* log; prune on 410 */} });
  req.on('end', () => client.close());
}
```

Notes:
- `apns-topic` **must** be `com.ardentnetworks.community.voip` (the app's bundle
  id + `.voip`).
- `apns-push-type: voip` and `apns-priority: 10` are required.
- Use the **production** host `api.push.apple.com` for TestFlight/App Store
  builds; `api.sandbox.push.apple.com` for `flutter run` debug builds.
- `APNS_P8_KEY` is the contents of the `.p8` file (the same key uploaded to
  Firebase). Keep it in secrets.
- On APNs status `410` (or `BadDeviceToken`), clear that row's `voip_token`.

---

## 7. Keep the existing socket handlers

No change needed here — the app calls these after the user acts on the native
call UI:
- `callAccept` / `callGroupJoin` — callee accepted; proceed as today.
- `callDecline` / `callEnd` — callee declined/hung up.
- Emit `call:taken` (answered elsewhere) and `call:ended` so other devices
  dismiss the ringing UI.

The media itself is unchanged: the app still fetches the LiveKit room token from
`POST /calls/:id/token` by `callId` and connects.

---

## 8. Quick test path

1. Register a device (log in on the app) → confirm a row in `user_fcm_tokens`
   (and a `voip_token` on iOS).
2. **Notification:** call `notifyUser(...)` → the device shows it (foreground
   shows on Android via the app; iOS shows via the system).
3. **Call:** call `ringUser(...)` with a real `callId` → the device rings with
   the native call UI even when the app is killed/locked. Accept → the app joins
   the call.
4. If nothing arrives: check the token is stored, the APNs topic is exactly
   `com.ardentnetworks.community.voip`, and (iOS) the VoIP push used the right
   host (production vs sandbox).

---

### One-paragraph summary
Add the `user_fcm_tokens` table and the `POST`/`DELETE /users/fcm-token`
endpoints; store the Firebase service-account creds in `.env`; send normal
notifications with the Firebase Admin SDK; and — the new part — **on call start
send a call push to the callee's devices**: a high-priority `type:'call'` data
FCM to Android tokens, and a **VoIP push** (APNs, topic
`com.ardentnetworks.community.voip`, using the existing `.p8` key) to iOS
`voip_token`s. Keep the current socket accept/decline handlers as they are.
