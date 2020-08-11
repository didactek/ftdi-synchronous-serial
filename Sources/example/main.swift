//
//  main.swift
//
//
//  Created by Kit Transue on 2020-07-31.
//

import Foundation
import LibUSB
import FTDI

#if false
exerciseC()
#endif

USBDevice.initializeUSBLibrary()
defer {
    USBDevice.closeUSBLibrary()
}

do { // hoping block scope triggers FtdiSPI.deinit
    let bus = try! FtdiSPI(speedHz: 1_000_000)
    let ledPrologue = Data(repeating: 0, count: 4)
    let ledEpilogue = Data(repeating: 0xff, count: 4)
    let ledBlue = Data([0xe8, 0xff, 0x00, 0x00])
    let ledRed = Data([0xe8, 0x00, 0x00, 0xff])
    let data = ledPrologue + ledBlue + ledBlue + ledRed + ledBlue + ledBlue + ledEpilogue
    bus.write(data: data, count: data.count)
}
