//
//  FtdiGPIO.swift
//
//
//  Created by Kit Transue on 2020-10-29.
//  Copyright © 2020 Kit Transue
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation
import Logging

import LibUSB

private var logger = Logger(label: "com.didactek.ftdi-synchronous-serial.ftdi-i2c")

/// Use an FTDI MPSSE adapter to read or control pins in GPIO mode.
///
/// - Important: This cannot be used simultaneously with I2C or SPI modes. While the chip will be
/// in MPSSE mode, operations that set pins may change the pins used by the serial bus, corrupting serial
/// operations.
public class FtdiGPIO {
    /// Mask for pins. Low order is ADBUS 0-7; high order is ACBUS 0-7.
    public typealias PinMask = UInt16

    let serialEngine: Ftdi
    /// Low byte output mask
    let adbusOutputs: UInt8
    /// Cache of low byte output values. Allows changes to individual bits without affecting other bits.
    var adbusValues: UInt8
    /// High byte output mask
    let acbusOutputs: UInt8
    /// Cache of high byte output values. Allows changes to individual bits without affecting other bits.
    var acbusValues: UInt8

    public init(ftdiAdapter: USBDevice, outputPins: PinMask) throws {
        logger.logLevel = .trace

        serialEngine = try Ftdi(ftdiAdapter: ftdiAdapter)
        let (highBits, lowBits) = outputPins.quotientAndRemainder(dividingBy: 256)
        adbusOutputs = UInt8(lowBits)
        acbusOutputs = UInt8(highBits)

        adbusValues = 0
        acbusValues = 0

        // Configure:
        serialEngine.setBitmode(.reset)
        serialEngine.setLatency(mSec: 16)

        serialEngine.setBitmode(.mpsse, outputPinMask: UInt8(lowBits))
        serialEngine.queueDataBits(values: acbusValues, outputMask: acbusValues, pins: .acbus)
    }

    deinit {
        serialEngine.setBitmode(.reset)
    }

    /// Change one of the output pins on the ADBUS.
    ///
    /// - Parameter index: Bit position of the pin to change.
    /// - Parameter assertHigh: If true, set pin high (to 1); if false, to low/0.
    public func writeADbus(index: Int, assertHigh: Bool) {
        guard (0..<8).contains(index) else {
            fatalError("index out of range")
        }
        let mask = UInt8(1 << index)
        guard (mask & adbusOutputs) != 0 else {
            fatalError("Pin \(index) was not configured as an output pin")
        }

        if assertHigh {
            adbusValues |= mask
        } else {
            adbusValues &= ~mask
        }

        serialEngine.queueDataBits(values: adbusValues, outputMask: adbusOutputs, pins: .adbus)
        serialEngine.flushCommandQueue()
    }

    /// Read all the ADBUS pins.
    ///
    /// - Returns:UInt8 with each bit set according ot the value read on the pin.
    /// - Note: Both input and output pin values are returned.
    /// - Note: Pins that are not connected are liable to float and return random values.
    public func readADbus() -> UInt8 {
        let promise = serialEngine.queryDataBits(pins: .adbus)
        serialEngine.flushCommandQueue()
        return promise.value[0]
    }
}
