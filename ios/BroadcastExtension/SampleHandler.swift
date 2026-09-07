//
//  SampleHandler.swift
//  BroadcastExtension
//
//  ReplayKit broadcast upload handler. Connects to the app over an App-Group
//  unix socket and forwards captured screen frames. Part of the standard
//  flutter_webrtc iOS screen-share broadcast extension (see README.md).
//
//  IMPORTANT: keep `appGroupIdentifier` in sync with:
//    - the App Group capability on BOTH the Runner and this extension target,
//    - Runner/Runner.entitlements + this target's entitlements,
//    - RTCAppGroupIdentifier in Runner/Info.plist.
//

import ReplayKit

class SampleHandler: RPBroadcastSampleHandler {
    // Must match RTCAppGroupIdentifier in the app's Info.plist.
    private let appGroupIdentifier = "group.com.example.ardentCommunity"

    private var clientConnection: SocketConnection?
    private var uploader: SampleUploader?

    private var socketFilePath: String {
        guard let sharedContainer = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
        else {
            return ""
        }
        // Matches flutter_webrtc's kRTCScreensharingSocketFD ("rtc_SSFD").
        return sharedContainer.appendingPathComponent("rtc_SSFD").path
    }

    override init() {
        super.init()
        if let connection = SocketConnection(filePath: socketFilePath) {
            clientConnection = connection
            setupConnection()
            uploader = SampleUploader(connection: connection)
        }
    }

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        DarwinNotificationCenter.shared.postNotification(.broadcastStarted)
        openConnection()
    }

    override func broadcastPaused() {}

    override func broadcastResumed() {}

    override func broadcastFinished() {
        DarwinNotificationCenter.shared.postNotification(.broadcastStopped)
        clientConnection?.close()
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer,
                                      with sampleBufferType: RPSampleBufferType) {
        switch sampleBufferType {
        case .video:
            uploader?.send(sample: sampleBuffer)
        default:
            break
        }
    }

    // MARK: - Private

    private func setupConnection() {
        clientConnection?.didClose = { [weak self] error in
            if let error = error {
                self?.finishBroadcastWithError(error)
            } else {
                let stopError = NSError(
                    domain: RPRecordingErrorDomain,
                    code: 10001,
                    userInfo: [NSLocalizedDescriptionKey: "Screen sharing stopped"]
                )
                self?.finishBroadcastWithError(stopError)
            }
        }
    }

    private func openConnection() {
        let queue = DispatchQueue(label: "broadcast.connectTimer")
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: .milliseconds(100), leeway: .milliseconds(500))
        timer.setEventHandler { [weak self] in
            guard self?.clientConnection?.open() == true else { return }
            timer.cancel()
        }
        timer.resume()
    }
}
