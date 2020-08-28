//
//  FtdiSPI.swift
//
//
//  Created by Kit Transue on 2020-08-01.
//  Copyright © 2020 Kit Transue
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation

/// Use an FTDI FT232H to communicate with devices using SPI (Serial Peripheral Interface).
///
///References:
/// https://en.wikipedia.org/wiki/Serial_Peripheral_Interface
public class FtdiSPI: Ftdi {

    /// Enumerates the supported modes and provides
    enum ClockSemantics {
        case mode0
        #if false  // remainder not currently implemented
        case mode1
        case mode2
        case mode3
        #endif

        /// the edge when writing data must be valid
        var writeWindow: DataWindow {
            switch self {
            case .mode0:
                return .fallingEdge
            }
        }

        /// clock and dataOut values for an idle bus.
        /// (as a bit field)
        var busAtIdle: UInt8 {
            switch self {
            case .mode0:
                return 0
            }
        }
    }

    let mode: ClockSemantics

    public init(speedHz: Int) throws {
        mode = .mode0
        try super.init()

        configureClocking(frequencyHz: speedHz)

        setSPIIdle()
        flushCommandQueue()
    }


    /// Queue commands to set the SPI bus to its idle state.
    ///
    /// Idle is data and clock pins low.
    func setSPIIdle() {
        queueDataBits(values: mode.busAtIdle, outputMask: SerialPins.outputs.rawValue, pins: .lowBytes)
    }

    /// Push data to the SPI bus.
    ///
    /// Note: no acknowledgement is checked; data is assumed to have been successfully transmitted.
    public func write(data: Data) {
        writeWithClock(data: data, during: mode.writeWindow)
    }
}
