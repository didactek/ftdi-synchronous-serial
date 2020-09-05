//
//  FtdiSPI.swift
//
//
//  Created by Kit Transue on 2020-08-01.
//  Copyright © 2020 Kit Transue
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation
import LibUSB

/// Use an FTDI FT232H to communicate with devices using SPI (Serial Peripheral Interface).
///
/// SPI is an ad-hoc protocol. Many details available at the [Wikipedia SPI entry](https://en.wikipedia.org/wiki/Serial_Peripheral_Interface).
/// - Important: Current implementation does not support read or loopback. It is push-only.
public class FtdiSPI {
    let serialEngine: Ftdi
    let mode: SPIModeSpec


    public init(ftdiAdapter: USBDevice, speedHz: Int) throws {
        // FIXME: expand supported modes.
        mode = .mode0
        serialEngine = try Ftdi(ftdiAdapter: ftdiAdapter)

        serialEngine.configureClocking(frequencyHz: speedHz)

        setSPIIdle()
        serialEngine.flushCommandQueue()
    }


    /// Queue commands to set the SPI bus to its idle state.
    ///
    /// Definition of idle for the SPI mode is defined in `SPIModeSpec`.
    func setSPIIdle() {
        serialEngine.queueDataBits(values: mode.busAtIdle, outputMask: Ftdi.SerialPins.outputs.rawValue, pins: .lowBytes)
    }

    /// Push data to the SPI bus.
    ///
    /// Note: no acknowledgement is checked; data is assumed to have been successfully transmitted.
    public func write(data: Data) {
        serialEngine.writeWithClock(data: data, during: mode.writeWindow)
    }
}
