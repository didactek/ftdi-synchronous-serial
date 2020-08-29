//
//  File.swift
//  
//
//  Created by Kit Transue on 2020-08-29.
//

import Foundation


public class CommandResponsePromise {
    let expectedCount: Int
    var writeOnceValue: Data? = nil
    let fulfillCallback: ((Data) -> Void)?
    
    init(ofCount: Int, onFulfill: ((Data) -> Void)? = nil) {
        expectedCount = ofCount
        fulfillCallback = onFulfill
    }
    
    var value: Data {
        guard let value = writeOnceValue else {
            fatalError("Promised value used before commands flushed to device")
        }
        return value
    }
    
    func fulfill(value: Data) {
        guard self.writeOnceValue == nil else {
            fatalError("Promise already fulfilled")
        }
        self.writeOnceValue = Data(value) // FIXME: Xcode 11.6 / Swift 5.2.4: explicit constructor is needed to avoid crash in Data subrange if just use value!! This seems like a bug????

        if let callback = fulfillCallback {
            callback(value)
        }
    }
}
