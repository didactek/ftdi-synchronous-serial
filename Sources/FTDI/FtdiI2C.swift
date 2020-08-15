//
//  FtdiI2C.swift
//  
//
//  Created by Kit Transue on 2020-08-10.
//

import Foundation

#if true // I think I2C might be a lot of work...

// references:
// https://en.wikipedia.org/wiki/I²C
// AN_135 FTDI MPSSE Basics Version 1.1

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
        // need:
        // 3-phase clock
        // clock speed (100kbps/400kbps/)
        // floating output pins (bus pulled high; bidirectional) both for data (reply phase) and clock (clock stretching)
        // if clock stretching is enabled, then need another pin to monitor the clock for pauses
        fatalError("not implemented")
    }
}
#endif
