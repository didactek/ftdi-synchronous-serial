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

import SimpleUSB

private var logger = Logger(label: "com.didactek.ftdi-synchronous-serial.ftdi-i2c")

/// Use an FTDI MPSSE adapter to read or control pins in GPIO mode.
///
/// - Important: This cannot be used simultaneously with I2C or SPI modes. While the chip will be
/// in MPSSE mode, operations that set pins may change the pins used by the serial bus, corrupting serial
/// operations.
public class FtdiGPIO {
    /// Values or I/O direction for a bank (8 bits) of pins.
    public typealias PinBankState = UInt8

    /// Groups of I/O pins.
    public enum PinBank {
        // Note: this somewhat duplicates the Ftdi.GpioBlock enum, but that
        // has cruft related to the details of using the API (like: "high" and
        // "low" terminology. So we don't export that here.
        case adbus
        case acbus
    }

    let serialEngine: Ftdi
    /// bus  pins assigned for output
    let busOutputs : [PinBank: PinBankState]

    public init(ftdiAdapter: USBDevice, adOutputPins: PinBankState, acOutputPins: PinBankState) throws {
        logger.logLevel = .trace
        serialEngine = try Ftdi(ftdiAdapter: ftdiAdapter)

        busOutputs = [
            .acbus: acOutputPins,
            .adbus: adOutputPins,
        ]

        // Configure:
        serialEngine.setBitmode(.reset)
        serialEngine.setLatency(mSec: 16)

        serialEngine.setBitmode(.mpsse, outputPinMask: busOutputs[.adbus]!)
        serialEngine.queueDataBits(values: 0, outputMask: busOutputs[.acbus]!, pins: .acbus)
    }

    deinit {
        serialEngine.setBitmode(.reset)
    }

    /// Change the output values on a bank of pins.
    ///
    /// - Parameter bank: Which bank to set pins in.
    /// - Parameter values: Bits to use for output pins.
    /// - Note: All pins configured for output are set at the same time.
    public func setPins(bank: PinBank, values: PinBankState) {
        let bankMask = busOutputs[bank]!
        serialEngine.queueDataBits(values: values, outputMask: bankMask, pins: bank.gpioBlock())
        serialEngine.flushCommandQueue()
    }

    /// Read all the ADBUS pins.
    ///
    /// - Parameter pins: Selector for pins to read.
    /// - Returns:UInt8 with each bit set according ot the value read on the pin.
    /// - Note: Both input and output pin values are returned.
    /// - Note: Pins that are not connected are liable to float and return random values.
    public func readPins(pins: PinBank) -> PinBankState {
        let block = pins.gpioBlock()
        let promise = serialEngine.queryDataBits(pins: block)
        serialEngine.flushCommandQueue()
        return promise.value[0]
    }
}

extension FtdiGPIO.PinBank {
    /// Map PinBank values to corresponding aliases used by the MPSSE internals.
    func gpioBlock() -> Ftdi.GpioBlock {
        switch self {
        case .acbus:
            return .acbus
        case .adbus:
            return .adbus
        }
    }
}
