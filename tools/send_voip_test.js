#!/usr/bin/env node
// Send a test VoIP (PushKit) push directly to a device, to verify the app rings
// incoming calls independently of the backend.
//
// Usage:
//   node tools/send_voip_test.js <voip_token> [--sandbox]
//
// - <voip_token> comes from the user_fcm_tokens table (platform='ios') after
//   logging in on build 4+, or from the app's debug token display.
// - Default target is PRODUCTION APNs (correct for a TestFlight/App Store build).
//   Add --sandbox only for a `flutter run` debug build.
//
// Uses the APNs auth key already saved at:
//   ~/.appstoreconnect/private_keys/AuthKey_22W6PB9G79.p8
// with Key ID 22W6PB9G79 and Team ID K9973Z86YT.

const crypto = require('crypto');
const http2 = require('http2');
const fs = require('fs');
const os = require('os');
const path = require('path');

const KEY_ID = '22W6PB9G79';
const TEAM_ID = 'K9973Z86YT';
const BUNDLE_ID = 'com.ardentnetworks.community';
const KEY_PATH = path.join(os.homedir(), '.appstoreconnect', 'private_keys', `AuthKey_${KEY_ID}.p8`);

const token = process.argv[2];
const sandbox = process.argv.includes('--sandbox');
if (!token || token.startsWith('--')) {
  console.error('Usage: node tools/send_voip_test.js <voip_token> [--sandbox]');
  process.exit(1);
}

const b64url = (buf) =>
  Buffer.from(buf).toString('base64').replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');

function makeJwt() {
  const key = fs.readFileSync(KEY_PATH, 'utf8');
  const header = b64url(JSON.stringify({ alg: 'ES256', kid: KEY_ID }));
  const claims = b64url(JSON.stringify({ iss: TEAM_ID, iat: Math.floor(Date.now() / 1000) }));
  const signingInput = `${header}.${claims}`;
  // ES256 in JOSE needs the raw R||S signature (ieee-p1363), not DER.
  const signature = crypto.sign('sha256', Buffer.from(signingInput), {
    key,
    dsaEncoding: 'ieee-p1363',
  });
  return `${signingInput}.${b64url(signature)}`;
}

const host = sandbox ? 'https://api.sandbox.push.apple.com' : 'https://api.push.apple.com';
const payload = JSON.stringify({
  callId: 'test-' + Date.now(),
  callerName: 'VoIP Test Call',
  kind: 'direct',
  groupId: '',
  video: 'false',
});

console.log(`→ ${sandbox ? 'SANDBOX' : 'PRODUCTION'} APNs`);
console.log(`→ topic: ${BUNDLE_ID}.voip`);
console.log(`→ token: ${token.slice(0, 12)}…`);

const client = http2.connect(host);
client.on('error', (e) => { console.error('connection error:', e.message); process.exit(1); });

const req = client.request({
  ':method': 'POST',
  ':path': `/3/device/${token}`,
  'authorization': `bearer ${makeJwt()}`,
  'apns-topic': `${BUNDLE_ID}.voip`,
  'apns-push-type': 'voip',
  'apns-priority': '10',
  'content-type': 'application/json',
});

let status = 0;
let body = '';
req.on('response', (headers) => { status = headers[':status']; });
req.setEncoding('utf8');
req.on('data', (chunk) => { body += chunk; });
req.on('end', () => {
  if (status === 200) {
    console.log('\n✅ APNs accepted the VoIP push (HTTP 200). The phone should ring now.');
    console.log('   If it did NOT ring → the app/device side still has an issue.');
    console.log('   If it DID ring → the app is fine; your backend just needs to send this same push.');
  } else {
    console.log(`\n❌ APNs rejected it (HTTP ${status}): ${body}`);
    console.log('   400 BadDeviceToken/BadTopic, 403 auth, 410 Unregistered → see the reason above.');
    if (!sandbox && /BadDeviceToken/.test(body)) {
      console.log('   Tip: a debug (flutter run) build registers a SANDBOX token — retry with --sandbox.');
    }
  }
  client.close();
});
req.write(payload);
req.end();
