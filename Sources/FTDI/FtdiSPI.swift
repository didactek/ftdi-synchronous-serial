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
///References:
/// https://en.wikipedia.org/wiki/Serial_Peripheral_Interface
public class FtdiSPI {
    let serialEngine: Ftdi
    /// SPI Modes and their specifications
    enum ClockSemantics {
        case mode0
        #if false  // remainder not currently implemented
        case mode1
        case mode2
        case mode3
        #endif

        /// The edge when writing data must be valid
        var writeWindow: DataWindow {
            switch self {
            case .mode0:
                return .fallingEdge
            }
        }

        /// clock and dataOut values for an idle bus.
        /// (as a bit field)
        // FIXME: how to make this implementation-independent so this can be moved to a specification-only file?
        var busAtIdle: UInt8 {
            switch self {
            case .mode0:
                return 0
            }
        }
    }

    let mode: ClockSemantics

    public init(ftdiAdapter: USBDevice, speedHz: Int) throws {
        mode = .mode0
        serialEngine = try Ftdi(ftdiAdapter: ftdiAdapter)

        serialEngine.configureClocking(frequencyHz: speedHz)

        setSPIIdle()
        serialEngine.flushCommandQueue()
    }


    /// Queue commands to set the SPI bus to its idle state.
    ///
    /// Definition of idle for the SPI mode is defined in ClockSemantics.
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
