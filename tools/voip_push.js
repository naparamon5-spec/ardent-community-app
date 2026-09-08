// Drop-in VoIP (PushKit) sender for the BACKEND — the exact logic proven to ring
// the iOS app (verified: HTTP 200 → device rang). The Firebase Admin SDK CANNOT
// send VoIP pushes; this is a direct APNs HTTP/2 call.
//
// Call sendVoipPush(...) from your "call start" handler for every iOS device
// row's voip_token, alongside the Socket.IO call:incoming signaling you already
// emit. For Android, keep using a high-priority data FCM (see
// docs/BACKEND_PUSH_IMPLEMENTATION.md §6a).
//
// Requires Node 15+ (http2 + crypto are built in). No npm packages needed.

const crypto = require('crypto');
const http2 = require('http2');

// ---- Config (put the p8 KEY in your secrets, not in code) -------------------
const APNS = {
  keyId: '22W6PB9G79',                        // APNs Auth Key ID
  teamId: 'K9973Z86YT',                       // Apple Team ID
  bundleId: 'com.ardentnetworks.community',   // topic = bundleId + '.voip'
  // The .p8 file CONTENTS (PEM). e.g. process.env.APNS_P8_KEY (with real
  // newlines, or "\n"-escaped then .replace(/\\n/g,'\n')).
  p8Key: process.env.APNS_P8_KEY,
  // TestFlight / App Store builds => production. Only a `flutter run` debug
  // build uses sandbox.
  production: true,
};

const b64url = (buf) =>
  Buffer.from(buf).toString('base64').replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');

// APNs bearer JWT (ES256). Reuse for up to ~50 min; must be < 1h old.
let _jwt = { token: null, at: 0 };
function apnsJwt() {
  const now = Math.floor(Date.now() / 1000);
  if (_jwt.token && now - _jwt.at < 3000) return _jwt.token;
  const header = b64url(JSON.stringify({ alg: 'ES256', kid: APNS.keyId }));
  const claims = b64url(JSON.stringify({ iss: APNS.teamId, iat: now }));
  const signingInput = `${header}.${claims}`;
  const sig = crypto.sign('sha256', Buffer.from(signingInput), {
    key: APNS.p8Key,
    dsaEncoding: 'ieee-p1363',   // JOSE needs raw R||S, not DER
  });
  _jwt = { token: `${signingInput}.${b64url(sig)}`, at: now };
  return _jwt.token;
}

/**
 * Send a VoIP push that makes the iOS app ring an incoming call.
 * @param {string} voipToken  the device's voip_token (from user_fcm_tokens)
 * @param {{callId:string, callerName:string, kind?:string, groupId?:string, video?:boolean}} call
 * @returns {Promise<{status:number, body:string}>}
 */
function sendVoipPush(voipToken, call) {
  return new Promise((resolve, reject) => {
    if (!voipToken) return resolve({ status: 0, body: 'no voip_token' });
    const host = APNS.production
      ? 'https://api.push.apple.com'
      : 'https://api.sandbox.push.apple.com';
    const client = http2.connect(host);
    client.on('error', reject);

    const payload = JSON.stringify({
      callId: call.callId,
      callerName: call.callerName,
      kind: call.kind || 'direct',
      groupId: call.groupId || '',
      video: call.video ? 'true' : 'false',
    });

    const req = client.request({
      ':method': 'POST',
      ':path': `/3/device/${voipToken}`,
      'authorization': `bearer ${apnsJwt()}`,
      'apns-topic': `${APNS.bundleId}.voip`,   // MUST be bundleId + '.voip'
      'apns-push-type': 'voip',                // required for VoIP
      'apns-priority': '10',
      'content-type': 'application/json',
    });

    let status = 0;
    let body = '';
    req.on('response', (h) => { status = h[':status']; });
    req.setEncoding('utf8');
    req.on('data', (c) => { body += c; });
    req.on('end', () => { client.close(); resolve({ status, body }); });
    req.on('error', reject);
    req.write(payload);
    req.end();
  });
}

// Fan out to all of a user's iOS devices. Prune tokens APNs rejects (410).
async function ringUserIOS(db, employeeId, call) {
  const rows = await db.query(
    "SELECT voip_token FROM user_fcm_tokens WHERE employee_id = ? AND platform = 'ios' AND voip_token IS NOT NULL",
    [employeeId],
  );
  await Promise.all(rows.map(async ({ voip_token }) => {
    const { status, body } = await sendVoipPush(voip_token, call);
    if (status !== 200) {
      console.error(`[voip] APNs ${status}: ${body}`);
      if (status === 410 || /BadDeviceToken|Unregistered/.test(body)) {
        await db.query('UPDATE user_fcm_tokens SET voip_token = NULL WHERE voip_token = ?', [voip_token]);
      }
    }
  }));
}

module.exports = { sendVoipPush, ringUserIOS };
