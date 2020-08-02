//
//  useCFunctions.swift
//
//
//  Created by Kit Transue on 2020-08-02.
//  Copyright © 2020 Kit Transue
//  SPDX-License-Identifier: Apache-2.0
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
