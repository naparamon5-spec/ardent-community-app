//
//  SampleUploader.swift
//  BroadcastExtension
//
//  Encodes each captured frame as JPEG, wraps it in a CFHTTPMessage carrying
//  Buffer-Width/Height/Orientation headers, and streams it over the socket in
//  chunks. The wire format matches flutter_webrtc's app-side
//  FlutterSocketConnectionFrameReader. Part of the standard flutter_webrtc iOS
//  screen-share broadcast extension.
//

import Foundation
import ReplayKit

private let kMaxReadLength = 10 * 1024

class SampleUploader {
    private static let imageContext = CIContext(options: nil)

    private var connection: SocketConnection

    private var dataToSend: Data?
    private var byteIndex = 0

    private let serialQueue = DispatchQueue(label: "com.ardent.broadcast.sampleUploader")
    private var isReady = false

    init(connection: SocketConnection) {
        self.connection = connection
        setupConnection()
    }

    @discardableResult
    func send(sample buffer: CMSampleBuffer) -> Bool {
        guard isReady else { return false }

        isReady = false
        dataToSend = prepare(sample: buffer)
        byteIndex = 0

        serialQueue.async { [weak self] in
            self?.sendDataChunk()
        }

        return true
    }

    // MARK: - Private

    private func setupConnection() {
        connection.didOpen = { [weak self] in
            self?.isReady = true
        }
        connection.streamHasSpaceAvailable = { [weak self] in
            self?.serialQueue.async {
                if let self = self, self.sendDataChunk() {
                    self.isReady = true
                }
            }
        }
    }

    @discardableResult
    private func sendDataChunk() -> Bool {
        guard let dataToSend = dataToSend else { return false }

        var bytesLeft = dataToSend.count - byteIndex
        var length = bytesLeft > kMaxReadLength ? kMaxReadLength : bytesLeft

        length = dataToSend[byteIndex ..< (byteIndex + length)].withUnsafeBytes {
            guard let ptr = $0.bindMemory(to: UInt8.self).baseAddress else { return 0 }
            return connection.writeToStream(buffer: ptr, maxLength: length)
        }

        if length > 0 {
            byteIndex += length
            bytesLeft -= length

            if bytesLeft == 0 {
                self.dataToSend = nil
                byteIndex = 0
            }
        } else {
            print("writeBufferToStream failure")
        }

        return true
    }

    private func prepare(sample buffer: CMSampleBuffer) -> Data? {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(buffer) else {
            print("image buffer not available")
            return nil
        }

        CVPixelBufferLockBaseAddress(imageBuffer, .readOnly)

        let scaleFactor = 2
        let width = CVPixelBufferGetWidth(imageBuffer) / scaleFactor
        let height = CVPixelBufferGetHeight(imageBuffer) / scaleFactor
        let orientation = CMGetAttachment(
            buffer, key: RPVideoSampleOrientationKey as CFString, attachmentModeOut: nil
        )?.uintValue ?? 0

        let scaledImage = CIImage(cvPixelBuffer: imageBuffer)
            .transformed(by: CGAffineTransform(scaleX: 1.0 / CGFloat(scaleFactor),
                                               y: 1.0 / CGFloat(scaleFactor)))

        CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly)

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let jpegData = SampleUploader.imageContext.jpegRepresentation(
                of: scaledImage,
                colorSpace: colorSpace,
                options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: 1.0]
              )
        else {
            return nil
        }

        let httpResponse = CFHTTPMessageCreateResponse(
            kCFAllocatorDefault, 200, nil, kCFHTTPVersion1_1
        ).takeRetainedValue()
        CFHTTPMessageSetHeaderFieldValue(httpResponse, "Content-Length" as CFString, String(jpegData.count) as CFString)
        CFHTTPMessageSetHeaderFieldValue(httpResponse, "Buffer-Width" as CFString, String(width) as CFString)
        CFHTTPMessageSetHeaderFieldValue(httpResponse, "Buffer-Height" as CFString, String(height) as CFString)
        CFHTTPMessageSetHeaderFieldValue(httpResponse, "Buffer-Orientation" as CFString, String(orientation) as CFString)
        CFHTTPMessageSetBody(httpResponse, jpegData as CFData)

        return CFHTTPMessageCopySerializedMessage(httpResponse)?.takeRetainedValue() as Data?
    }
}
