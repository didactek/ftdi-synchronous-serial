//
//  main.swift
//
//
//  Created by Kit Transue on 2020-07-31.
//  Copyright © 2020 Kit Transue
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation
import LibUSB

#if false
exerciseC()
#endif

FtdiSPI.initializeUSBLibrary()
defer {
    FtdiSPI.closeUSBLibrary()
}

do { // hoping block scope triggers FtdiSPI.deinit
    let bus = try! FtdiSPI(speedHz: 1_000_000)
    let ledPrologue = Data(repeating: 0, count: 4)
    let ledEpilogue = Data(repeating: 0xff, count: 4)
    let ledBlue = Data([0xe8, 0xff, 0x00, 0x00])
    let data = ledPrologue + ledBlue + ledEpilogue
    bus.write(data: data, count: data.count)
}
