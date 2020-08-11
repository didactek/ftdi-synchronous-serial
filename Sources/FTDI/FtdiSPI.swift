//
//  FtdiSPI.swift
//
//
//  Created by Kit Transue on 2020-08-01.
//  Copyright © 2020 Kit Transue
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation


public class FtdiSPI: Ftdi {
    public init(speedHz: Int) throws {
        // AN_135_MPSSE_Basics lifetime: 4.1 Confirm device existence and open file handle
        try super.init()
        configurePorts()
        confirmMPSSEModeEnabled()
        configureMPSSEForSPI(frequencyHz: speedHz)
        // AN_135_MPSSE_Basics lifetime: Use serial port/GPIO:
    }

    deinit {
        endMPSSE()
    }

    struct SpiHardwarePins: OptionSet {
        let rawValue: UInt8

        static let clock   = SpiHardwarePins(rawValue: 1 << 0)
        static let dataOut = SpiHardwarePins(rawValue: 1 << 1)
        static let dataIn  = SpiHardwarePins(rawValue: 1 << 2)

        static let outputs: SpiHardwarePins = [.clock, .dataOut]
        static let inputs: SpiHardwarePins = [.dataIn]
    }

    /// AN_135_MPSSE_Basics lifetime: 4.2 Configure FTDI Port For MPSSE Use
    func configurePorts() {
        // Reset peripheral side
        //  rx buf purged
        //  bitmode: RESET
        setBitmode(.reset)
        // Configure USB transfer sizes
        // Set event/error characters
        // Set timeouts
        // Set latency timer
        setLatency(mSec: 16)
        // Set flow control
        // Reset MPSSE controller  //FIXME: different from "reset peripheral side", and if so: should these be different calls?
        //  bitmode: RESET
        setBitmode(.reset)
        //  rx buf purged
        // Enable MPSSE controller
        //  bitmode: MPSSE
        setBitmode(.mpsse, outputPinMask: SpiHardwarePins.outputs.rawValue)
    }


    func initializePinState() {
        setDataBits(values: 0, outputMask: SpiHardwarePins.outputs.rawValue, pins: .lowBytes)
    }


    /// AN_135_MPSSE_Basics lifetime: 4.3 Configure MPSSE
    func configureMPSSEForSPI(frequencyHz: Int) {
        // Clock speed
        setClock(frequencyHz: frequencyHz)
        // pin directions
        initializePinState()
    }
}
