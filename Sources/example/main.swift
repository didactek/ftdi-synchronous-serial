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

do { // use a block to trigger de-inits at the end of the block scope.
    let usbSubsystem = USBBus()
    let ftdiDevice = try usbSubsystem
        .findDevice(idVendor: Ftdi.defaultIdVendor,
                    idProduct: Ftdi.defaultIdProduct)
    #if false // SPI demonstration: light up and fade a 72 LED strip.
    let bus = try! FtdiSPI(ftdiAdapter: ftdiDevice, speedHz: 1_500_000)
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
    let ledBlack = Data([0xe8, 0, 0, 0])
    for i in 0..<100 {
        let variable = Data([0xe8, UInt8(i + 30), UInt8(130 - i), 0])
        let x = Data((0..<70).flatMap {_ in variable})
        let data = ledPrologue + ledBlue + ledBlue + ledRed + variable + ledBlue + ledBlue + variable + x + ledEpilogue
        bus.write(data: data)
        Thread.sleep(forTimeInterval: 0.05)
    }
    sleep(10)
    #elseif false // I2C demonstration: read 5 bytes from TEA5767 FM tuner.
    let bus = try! FtdiI2C(ftdiAdapter: ftdiDevice, overrideClockHz: 30_000)
    let radio = try! FtdiI2CDevice(busHost: bus, nodeAddress: 0x60)
    let status = radio.read(count: 5)
    print(status.map {String($0, radix: 16)})
    #else  // GPIO demonstration: read input pin connected to output pin.
    #endif
     // Connect pins ADBUS 0 and ADBUS 6:
    let gpio = try! FtdiGPIO(ftdiAdapter: ftdiDevice, adOutputPins: 1 << 0, acOutputPins: 7)
    let readMask: UInt8 = 1 << 6
    gpio.setPin(bank: .adbus, index: 0, assertHigh: false)
    print(gpio.readPins(pins: .acbus) & readMask)
    gpio.setPin(bank: .adbus, index: 0, assertHigh: true)
    print(gpio.readPins(pins: .acbus) & readMask)
    gpio.setPin(bank: .adbus, index: 0, assertHigh: false)
    print(gpio.readPins(pins: .acbus    ) & readMask)

    for _ in 0..<100 {
        for x in [2, 2, 2, 1, 1, 1, 0, 0, 0].shuffled() {
            for y in 0...2 {
                gpio.setPin(bank: .acbus, index: y, assertHigh: true)
            }
            gpio.setPin(bank: .acbus, index: x, assertHigh: false)
            Thread.sleep(forTimeInterval: 0.7)
        }
    }
}
