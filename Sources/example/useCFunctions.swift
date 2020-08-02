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
}
