//
//  useCFunctions.swift
//  
//
//  Created by Kit Transue on 2020-08-02.
//

import Foundation
import CInterop

func exerciseC() {
    // need a pointer to C-string
    var ptr: UnsafePointer<CChar>? = nil
    // populate via call to CInterop
    getPtrToString(&ptr)
    // validate contents
    print(String(cString: ptr!))
    
    
    var data = Data(repeating: 0xaa, count: 8)
    #if false // 'withUnsafeMutableBytes' is deprecated: use `withUnsafeMutableBytes<R>(_: (UnsafeMutableRawBufferPointer) throws -> R) rethrows -> R` instead
    data.withUnsafeMutableBytes {
        consumeBytes($0)
    }
    #elseif false // Cannot convert value of type 'UnsafeMutableRawBufferPointer' to expected argument type 'UnsafeMutablePointer<UInt8>?'
    withUnsafeMutableBytes(of: &data) {
        consumeBytes($0)
    }
    #elseif false // Cannot convert value of type '(_) -> Void' to expected argument type '(UnsafeMutableRawBufferPointer) throws -> _'
    withUnsafeMutableBytes(of: &data) {
        consumeBytes($0.baseAddress)
    }
    #elseif false // 'withUnsafeMutableBytes' is deprecated: use `withUnsafeMutableBytes<R>(_: (UnsafeMutableRawBufferPointer) throws -> R) rethrows -> R` instead
    let _ = data.withUnsafeMutableBytes { (unsafe: UnsafeMutablePointer<UInt8>) -> Int in  // trying to help overload
        consumeBytes(unsafe)
        return 0
    }
    #elseif false // some success with overload; no warning; but can't go from baseAddress
    let _ = data.withUnsafeMutableBytes { (unsafe: UnsafeMutableRawBufferPointer) -> Int in  // trying to help overload
        consumeBytes(unsafe.baseAddress) // Cannot convert value of type 'UnsafeMutableRawPointer?' to expected argument type 'UnsafeMutablePointer<UInt8>?'
        return 0
    }
    #elseif false // This works!
    let _ = data.withUnsafeMutableBytes { (unsafe: UnsafeMutableRawBufferPointer) -> Int in  // trying to help overload
        consumeBytes(unsafe.bindMemory(to: UInt8.self).baseAddress)
        return 0
    }
    #elseif true // This works!
    data.withUnsafeMutableBytes { unsafe in  // overload help not necessary?
        consumeBytes(unsafe.bindMemory(to: UInt8.self).baseAddress)
    }
    #endif
}
