//
//  Atomic.swift
//  BroadcastExtension
//
//  Thread-safe wrapper used by the sample uploader. Part of the standard
//  flutter_webrtc iOS screen-share broadcast extension (see README.md).
//

import Foundation

class Atomic<T> {
    private let queue = DispatchQueue(label: "com.ardent.broadcast.atomic")
    private var _value: T

    init(_ value: T) {
        self._value = value
    }

    var value: T {
        get { queue.sync { _value } }
        set { queue.sync { _value = newValue } }
    }

    func mutate(_ transform: (inout T) -> Void) {
        queue.sync { transform(&_value) }
    }
}
