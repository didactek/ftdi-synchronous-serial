//
//  FtdiConfiguration.swift
//
//
//  Created by Kit Transue on 2020-10-27.
//  Copyright © 2020 Kit Transue
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation

extension Ftdi {
    /// USB bRequests issued when making calls to the FTDI D2XX API.
    ///
    /// - Note: These do not appear to be documented by FTDI, but are instead observed
    /// empirically on Linux using the process described in 'ftdi-probe'.
    enum BRequest: UInt8 {
        /// Corresponds to FT_SetBitMode.
        case setBitMode = 0x0b
        /// Corresponds to FT_SetLatencyTimer.
        case setLatencyTimer = 0x09
    }

    /// Configure the built-in delay when reading data.
    ///
    /// - Parameter mSec: Desired read latency in milliseconds.
    ///
    /// - Note: Setting latency is recommended in the MPSSE mode, but the semantics of latency
    /// in MPSSE mode are slightly unclear. The FT232H defaults to injecting a 16ms delay into reads.
    /// See [AN 232 B](https://www.ftdichip.com/Support/Documents/AppNotes/AN232B-04_DataLatencyFlow.pdf).
    func setLatency(mSec: UInt16) {
        controlTransferOut(bRequest: .setLatencyTimer, value: mSec)
    }

    /// Select or reset the operating mode of the FTDI adapter.
    ///
    /// - Parameter mode: desired operating mode
    /// - Parameter outputPinMask: Low pins (ADBUS) configuration: 1 => pin used for output.
    func setBitmode(_ mode: BitMode, outputPinMask: UInt8 = 0) {
        let value = mode.rawValue << 8 | UInt16(outputPinMask)
        controlTransferOut(bRequest: .setBitMode, value: value)
    }


    /// Provide a slightly-more-typed interface for control transfer outs.
    ///
    /// - Note: Always uses '0' for wIndex, which seems to be the pattern deployed by FTDI's drivers.
    func controlTransferOut(bRequest: BRequest, value: UInt16) {
        device.controlTransferOut(bRequest: bRequest.rawValue, value: value, wIndex: 0, data: nil)
    }
}
