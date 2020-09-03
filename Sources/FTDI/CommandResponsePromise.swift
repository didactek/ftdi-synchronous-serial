//
//  CommandResponsePromise.swift
//
//
//  Created by Kit Transue on 2020-08-29.
//  Copyright © 2020 Kit Transue
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation

/// Keep track of the results expected from a queued command.
public class CommandResponsePromise {
    /// Expected size of this response. The fulfillment machinery may use this for guidance in splitting a stream of responses.
    let expectedCount: Int
    private var writeOnceValue: Data? = nil
    private let fulfillCallback: ((Data) -> Void)?

    /// - Parameters:
    ///   - ofCount: Number of bytes to extract for this reply. Zero is permitted.
    ///   - onFulfill: An optional callback to be called when the value is fulfilled.
    init(ofCount: Int, onFulfill: ((Data) -> Void)? = nil) {
        expectedCount = ofCount
        fulfillCallback = onFulfill
    }

    /// Accessor for the value after fulfill has been called.
    ///
    /// - Note: Accessing value before the promise has been fulfilled is a fatal error.
    var value: Data {
        guard let value = writeOnceValue else {
            fatalError("Promised value used before commands flushed to device")
        }
        return value
    }

    /// Fulfill the promise and run any associated callback.
    ///
    /// - Parameter value: the value to be set and used in any callbacks.
    /// - Postcondition: the value member may now be retrieved by any promise holder.
    func fulfill(value: Data) {
        guard self.writeOnceValue == nil else {
            fatalError("Promise already fulfilled")
        }
        self.writeOnceValue = value

        if let callback = fulfillCallback {
            callback(value)
        }
    }
}
