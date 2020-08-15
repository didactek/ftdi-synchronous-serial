//
//  FtdiI2C.swift
//
//
//  Created by Kit Transue on 2020-08-10.
//  Copyright © 2020 Kit Transue
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation

#if true // I think I2C might be a lot of work...

// references:
// https://en.wikipedia.org/wiki/I²C
// AN_135 FTDI MPSSE Basics Version 1.1
// AN_108 Command Processor for MPSSE and MCU Host Bus Emulation Modes
// https://www.ftdichip.com/Support/Documents/AppNotes/AN_113_FTDI_Hi_Speed_USB_To_I2C_Example.pdf
public class FtdiI2C: Ftdi {
    struct I2CHardwarePins: OptionSet {
        let rawValue: UInt8

        static let clock   = I2CHardwarePins(rawValue: 1 << 0)
        // the chip is wired so dataOut and dataIn pins are tied togther to form SDA: dataOut is used to pull the bus down or to let it float; data is read on the dataIn pin
        static let dataOut = I2CHardwarePins(rawValue: 1 << 1)
        static let dataIn  = I2CHardwarePins(rawValue: 1 << 2)
        // if one needs clock stretching, a pin should be allocated to watch for the bus pausing the clock signal

        static let outputs: I2CHardwarePins = [.clock, .dataOut]
        static let inputs: I2CHardwarePins = [.dataIn]
        static let tristate: I2CHardwarePins = [.clock, .dataOut]
    }

    enum Mode {
        case standard // 100 kbps
        #if false  // unsupported
        case fast // 400 kbps
        case fastPlus // 1 Mbps
        case highSpeed // 3.4 Mbps
        case ultraFast // 5 Mbps
        case turbo // 1.4 Mbps  // Wikipedia
        #endif
    }

    public override init() throws {
        try super.init()

        configurePorts()
        confirmMPSSEModeEnabled()
        configureMPSSEForI2C(mode: .standard)
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
        setBitmode(.mpsse, outputPinMask: I2CHardwarePins.outputs.rawValue)
    }


    func configureMPSSEForI2C(mode: Mode) {
        // Output pins were set when MPSSE was enabled

        // I2C wires may be asserted by any device on the bus:
        setTristate(lowMask: I2CHardwarePins.tristate.rawValue, highMask: 0)
        // need:
        // 3-phase clock
        // clock speed (100kbps/400kbps/)
        fatalError("not implemented")
    }

    // FIXME: implement write
    // FIXME: implement read
    // FIXME: implement exchange?
    // FIXME: implement start
    // FIXME: implement stop
}
#endif
