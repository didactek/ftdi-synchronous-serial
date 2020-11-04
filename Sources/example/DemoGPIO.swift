//
//  DemoGPIO.swift
//
//
//  Created by Kit Transue on 2020-11-04.
//  Copyright © 2020 Kit Transue
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation

import LibUSB
import FTDI


/// GPIO demonstration: read input pin connected to output pin.
///
/// - Note: Connect pins ADBUS 0 and ADBUS 6.
func demoGPIO(ftdiAdapter: USBDevice) {
    let gpio = try! FtdiGPIO(ftdiAdapter: ftdiAdapter, adOutputPins: 1 << 0, acOutputPins: 7)
    let readMask: UInt8 = 1 << 6
    gpio.setPins(bank: .adbus, values: 0)
    print(gpio.readPins(pins: .acbus) & readMask)
    gpio.setPins(bank: .adbus, values: 1)
    print(gpio.readPins(pins: .acbus) & readMask)
    gpio.setPins(bank: .adbus, values: 0)
    print(gpio.readPins(pins: .acbus    ) & readMask)

    for _ in 0..<10 {
        for x in [1,2,3].shuffled() {
            gpio.setPins(bank: .acbus, values: UInt8(255 & ~(1 << (x - 1))))
            Thread.sleep(forTimeInterval: 0.7)
        }
    }
}
