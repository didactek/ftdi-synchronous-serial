//
//  DemoI2CRadio.swift
//
//
//  Created by Kit Transue on 2020-11-04.
//  Copyright © 2020 Kit Transue
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation
import SimpleUSB
import FTDI

/// I2C demonstration: read 5 bytes from TEA5767 FM tuner.
func demoI2CRadio(ftdiDevice: USBDevice) {
    let bus = try! FtdiI2C(ftdiAdapter: ftdiDevice, overrideClockHz: 30_000)
    let radio = try! FtdiI2CDevice(busHost: bus, nodeAddress: 0x60)
    let status = radio.read(count: 5)
    print(status.map {String($0, radix: 16)})
}
