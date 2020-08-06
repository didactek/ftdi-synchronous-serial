//
//  main.swift
//
//
//  Created by Kit Transue on 2020-07-31.
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
    let bus = try! FtdiSPI(speedHz: 10_000_000)
    let data = Data(repeating: 0x55, count: 10)  // 85 decimal
    bus.write(data: data, count: data.count)
}
