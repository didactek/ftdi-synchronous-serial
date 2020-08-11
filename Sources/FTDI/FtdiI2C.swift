//
//  FtdiI2C.swift
//
//
//  Created by Kit Transue on 2020-08-10.
//  Copyright © 2020 Kit Transue
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation

#if false // I think I2C might be a lot of work...
public class FtdiI2C: Ftdi {
    public init() throws {
        try super.init()
        // need:
        // 3-phase clock
        // clock speed (100kbps/400kbps/)
        // floating output pins (bus pulled high; bidirectional) both for data (reply phase) and clock (clock stretching)
        // if clock stretching is enabled, then need another pin to monitor the clock for pauses
        configurePorts()
        confirmMPSSEModeEnabled()
        configureMPSSEForI2C()
    }

    deinit {
        endMPSSE()
    }

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


    func configureMPSSEForI2C(frequencyHz: Int) {
        // Clock speed
        setClock(frequencyHz: frequencyHz)
        // pin directions
        initializePinState()
    }
}
#endif
