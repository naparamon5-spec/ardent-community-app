//
//  SocketConnection.swift
//  BroadcastExtension
//
//  Client end of the AF_UNIX socket the extension uses to hand captured frames
//  to the app. The app (flutter_webrtc's FlutterSocketConnection) is the
//  server that binds/listens on the App-Group container path; this connects to
//  it. Part of the standard flutter_webrtc iOS screen-share broadcast extension.
//

import Foundation

class SocketConnection: NSObject {
    var didOpen: (() -> Void)?
    var didClose: ((Error?) -> Void)?
    var streamHasSpaceAvailable: (() -> Void)?

    private let filePath: String
    private var socketHandle: Int32 = -1
    private var address: sockaddr_un

    private var inputStream: InputStream?
    private var outputStream: OutputStream?

    private var networkQueue: DispatchQueue?
    private var shouldKeepRunning = false

    init?(filePath path: String) {
        filePath = path
        socketHandle = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)

        guard socketHandle != -1 else {
            print("failure: socket handle")
            return nil
        }

        address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        guard path.utf8.count < MemoryLayout.size(ofValue: address.sun_path) else {
            print("failure: path too long")
            return nil
        }
        _ = withUnsafeMutablePointer(to: &address.sun_path.0) { ptr in
            path.withCString { strcpy(ptr, $0) }
        }

        super.init()
    }

    func open() -> Bool {
        print("open socket connection")

        guard FileManager.default.fileExists(atPath: filePath) else {
            // The app hasn't created the socket yet.
            return false
        }

        var status: Int32 = -1
        withUnsafeMutablePointer(to: &address) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { addrPtr in
                status = connect(socketHandle, addrPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }

        guard status == 0 else {
            print("failure: socket connect (\(status))")
            return false
        }

        var readStream: Unmanaged<CFReadStream>?
        var writeStream: Unmanaged<CFWriteStream>?
        CFStreamCreatePairWithSocket(kCFAllocatorDefault, socketHandle, &readStream, &writeStream)

        inputStream = readStream?.takeRetainedValue()
        inputStream?.delegate = self
        inputStream?.setProperty(kCFBooleanTrue, forKey: Stream.PropertyKey(kCFStreamPropertyShouldCloseNativeSocket as String))

        outputStream = writeStream?.takeRetainedValue()
        outputStream?.delegate = self
        outputStream?.setProperty(kCFBooleanTrue, forKey: Stream.PropertyKey(kCFStreamPropertyShouldCloseNativeSocket as String))

        setupNetworkThread()

        return true
    }

    func close() {
        shouldKeepRunning = false

        inputStream?.delegate = nil
        outputStream?.delegate = nil

        inputStream?.close()
        outputStream?.close()

        inputStream = nil
        outputStream = nil
    }

    func writeToStream(buffer: UnsafePointer<UInt8>, maxLength length: Int) -> Int {
        outputStream?.write(buffer, maxLength: length) ?? 0
    }

    // MARK: - Private

    private func setupNetworkThread() {
        shouldKeepRunning = true
        let thread = Thread(target: self, selector: #selector(startRunLoop), object: nil)
        thread.qualityOfService = .userInitiated
        thread.start()
    }

    @objc private func startRunLoop() {
        guard let inputStream = inputStream, let outputStream = outputStream else { return }

        let runLoop = RunLoop.current
        inputStream.schedule(in: runLoop, forMode: .common)
        outputStream.schedule(in: runLoop, forMode: .common)

        inputStream.open()
        outputStream.open()

        while shouldKeepRunning {
            runLoop.run(mode: .default, before: .distantFuture)
        }
    }
}

extension SocketConnection: StreamDelegate {
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch eventCode {
        case .openCompleted:
            if aStream == outputStream {
                didOpen?()
            }
        case .hasSpaceAvailable:
            if aStream == outputStream {
                streamHasSpaceAvailable?()
            }
        case .errorOccurred:
            print("client stream error occurred: \(String(describing: aStream.streamError))")
            close()
            didClose?(aStream.streamError)
        case .endEncountered:
            close()
            didClose?(nil)
        default:
            break
        }
    }
}
