//
//  DarwinNotificationCenter.swift
//  BroadcastExtension
//
//  Cross-process (app <-> extension) notifications for broadcast start/stop.
//  Part of the standard flutter_webrtc iOS screen-share broadcast extension.
//

import Foundation

enum DarwinNotification: String {
    case broadcastStarted = "iOS_BroadcastStarted"
    case broadcastStopped = "iOS_BroadcastStopped"
}

class DarwinNotificationCenter {
    static let shared = DarwinNotificationCenter()

    private let notificationCenter: CFNotificationCenter

    init() {
        notificationCenter = CFNotificationCenterGetDarwinNotifyCenter()
    }

    func postNotification(_ name: DarwinNotification) {
        CFNotificationCenterPostNotification(
            notificationCenter,
            CFNotificationName(rawValue: name.rawValue as CFString),
            nil,
            nil,
            true
        )
    }
}
