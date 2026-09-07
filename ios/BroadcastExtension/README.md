# iOS screen sharing — Broadcast Upload Extension setup

Screen sharing in calls works on Android out of the box. On **iOS**, Apple
requires a *Broadcast Upload Extension* (a separate app target) to capture the
screen. The source for that extension lives in this folder, and the app is
already wired for it (`RTCAppGroupIdentifier` / `RTCScreenSharingExtension` in
`ios/Runner/Info.plist`, and `ios/Runner/Runner.entitlements`).

**What ships in git:** all the code + config in this folder and the Runner
entitlements/Info.plist keys.

**What you must do once in Xcode** (it involves your Apple Developer signing and
Xcode target registration, which cannot be delivered by a `git pull`):

## 1. Open the workspace
```bash
open ios/Runner.xcworkspace
```

## 2. Add the Broadcast Upload Extension target
- **File ▸ New ▸ Target… ▸ Broadcast Upload Extension.**
- Product Name: **BroadcastExtension**
- **Uncheck** "Include UI Extension".
- Finish. If asked to activate the scheme, click **Activate**.
- Set the extension target's **Bundle Identifier** to
  `com.example.ardentCommunity.broadcast` (must equal `RTCScreenSharingExtension`
  in `ios/Runner/Info.plist`).
- Set its **iOS Deployment Target** to match Runner (e.g. iOS 13+).

## 3. Use the source files in this folder
Xcode generates a starter `SampleHandler.swift` + `Info.plist` in a new group.
Replace them with the files here:
- Delete the generated `SampleHandler.swift`.
- **Add Files to "BroadcastExtension"…** and add, with *Target Membership =
  BroadcastExtension only*:
  - `SampleHandler.swift`
  - `SampleUploader.swift`
  - `SocketConnection.swift`
  - `DarwinNotificationCenter.swift`
  - `Atomic.swift`
- Point the target's **Info.plist** build setting at this folder's `Info.plist`
  (or paste its `NSExtension` block into the generated one).

## 4. App Group capability (both targets)
On **each** of the `Runner` target and the `BroadcastExtension` target:
- **Signing & Capabilities ▸ + Capability ▸ App Groups.**
- Add / check `group.com.example.ardentCommunity`.

This must match:
- `ios/Runner/Runner.entitlements`
- `ios/BroadcastExtension/BroadcastExtension.entitlements` (set the extension
  target's **Code Signing Entitlements** build setting to this file)
- `RTCAppGroupIdentifier` in `ios/Runner/Info.plist`
- `appGroupIdentifier` in `SampleHandler.swift`

> If your real bundle id is **not** `com.example.ardentCommunity`, change it
> everywhere above (app group id, extension bundle id, and all four references).

## 5. Build & run on a real device
Screen capture (and WebRTC) do **not** work on the iOS Simulator — use a
physical device. Tap **Share** in a call → the system broadcast picker appears →
pick "Ardent Screen Share" → **Start Broadcast**.

## How it fits together
`CallController.toggleScreenShare()` calls `setScreenShareEnabled(true)`.
On iOS that presents the system broadcast picker; the picked extension
(`SampleHandler`) opens the App-Group unix socket and streams JPEG frames to the
app, which flutter_webrtc reads and publishes to the LiveKit room. Remote peers
see it promoted full-screen (handled in `lib/screens/call_screen.dart`).
