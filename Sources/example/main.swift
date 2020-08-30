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
import FTDI

do { // hoping block scope triggers FtdiSPI.deinit
    let usbSubsystem = USBBus()
    let ftdiDevice = try usbSubsystem
        .findDevice(idVendor: Ftdi.defaultIdVendor,
                    idProduct: Ftdi.defaultIdProduct,
                    serialNumber: nil)
    #if true
    let bus = try! FtdiSPI(device: ftdiDevice, speedHz: 1_000_000)
    let ledPrologue = Data(repeating: 0, count: 4)
    let ledEpilogue = Data(repeating: 0xff, count: 4)
    let ledBlue = Data([0xe8, 0xff, 0x00, 0x00])
    let ledRed = Data([0xe8, 0x00, 0x00, 0xff])
    let data = ledPrologue + ledBlue + ledBlue + ledRed + ledBlue + ledBlue + ledEpilogue
    bus.write(data: data)
    #else
    let bus = try! FtdiI2C(device: ftdiDevice)
    let radio = try! FtdiI2CDevice(bus: bus, nodeAddress: 0x60)
    let status = radio.read(count: 5)
    print(status.map {String($0, radix: 16)})
    #endif
}
