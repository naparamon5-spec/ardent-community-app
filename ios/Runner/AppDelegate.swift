import Flutter
import UIKit
import PushKit
import CallKit
import flutter_callkit_incoming

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, PKPushRegistryDelegate {
  // MUST be retained as a property. A PKPushRegistry held only in a local
  // variable is deallocated as soon as the launch method returns, and then
  // PushKit never delivers a VoIP token or any incoming call pushes.
  private var voipRegistry: PKPushRegistry?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Register for VoIP (PushKit) pushes so incoming calls can ring via CallKit
    // even when the app is killed or the phone is locked. The backend sends a
    // VoIP push on call start (see docs/FCM_PUSH_NOTIFICATIONS.md).
    let registry = PKPushRegistry(queue: DispatchQueue.main)
    registry.delegate = self
    registry.desiredPushTypes = [.voIP]
    self.voipRegistry = registry

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  // MARK: - PKPushRegistryDelegate

  /// The VoIP token updated — hand it to the plugin, which forwards it to Dart
  /// (PushService then registers it with the backend as `voip_token`).
  func pushRegistry(
    _ registry: PKPushRegistry,
    didUpdate pushCredentials: PKPushCredentials,
    for type: PKPushType
  ) {
    guard type == .voIP else { return }
    let deviceToken = pushCredentials.token.map { String(format: "%02x", $0) }.joined()
    SwiftFlutterCallkitIncomingPlugin.sharedInstance?.setDevicePushTokenVoIP(deviceToken)
  }

  func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
    guard type == .voIP else { return }
    SwiftFlutterCallkitIncomingPlugin.sharedInstance?.setDevicePushTokenVoIP("")
  }

  /// An incoming VoIP push arrived. Apple requires that we report an incoming
  /// call to CallKit before returning, or iOS terminates the app and stops
  /// delivering VoIP pushes. `showCallkitIncoming(_:fromPushKit:)` does that.
  func pushRegistry(
    _ registry: PKPushRegistry,
    didReceiveIncomingPushWith payload: PKPushPayload,
    for type: PKPushType,
    completion: @escaping () -> Void
  ) {
    guard type == .voIP else { completion(); return }

    let dict = payload.dictionaryPayload
    // CallKit needs a UUID for its call id; keep the app's real call id in extra.
    let uuid = UUID().uuidString
    let callId = (dict["callId"] as? String) ?? uuid
    let nameCaller = (dict["callerName"] as? String)
      ?? (dict["caller"] as? String) ?? "Incoming call"
    let kind = (dict["kind"] as? String) ?? "direct"
    let groupId = (dict["groupId"] as? String) ?? ""
    let isVideo = (dict["video"] as? String) == "true"

    let data = flutter_callkit_incoming.Data(
      id: uuid,
      nameCaller: nameCaller,
      handle: kind == "group" ? "Group call" : "Ardent call",
      type: isVideo ? 1 : 0
    )
    data.extra = ["callId": callId, "kind": kind, "groupId": groupId]
    data.supportsVideo = true
    data.appName = "Ardent"

    SwiftFlutterCallkitIncomingPlugin.sharedInstance?.showCallkitIncoming(data, fromPushKit: true)
    completion()
  }
}
