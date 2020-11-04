//
//  DemoSpiLed.swift
//
//
//  Created by Kit Transue on 2020-11-04.
//  Copyright © 2020 Kit Transue
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation

import LibUSB
import FTDI

/// SPI demonstration: light up and fade a 72 LED strip.
func demoSpiLed(ftdiAdapter: USBDevice) {
   let bus = try! FtdiSPI(ftdiAdapter: ftdiAdapter, speedHz: 1_500_000)
   // 100kHz better than 1kHz; latter OK-ish with 5V converter
   // Suggest driving at at least 1MHz.
   // 1-3 MHz quite reliable even at 3.3V.
   // 7 MHz OK with fast clock.
   // Gets weird if clock divisor is zero.
   print("setup done")
   sleep(5)
   let ledPrologue = Data(repeating: 0, count: 4)
   let ledEpilogue = Data(repeating: 0xff, count: 4)
   let ledBlue = Data([0xe8, 0xff, 0x00, 0x00])
   let ledRed = Data([0xe8, 0x00, 0x00, 0xff])
   for i in 0..<100 {
       let variable = Data([0xe8, UInt8(i + 30), UInt8(130 - i), 0])
       let x = Data((0..<70).flatMap {_ in variable})
       let data = ledPrologue + ledBlue + ledBlue + ledRed + variable + ledBlue + ledBlue + variable + x + ledEpilogue
       bus.write(data: data)
       Thread.sleep(forTimeInterval: 0.05)
   }
   sleep(10)
}
