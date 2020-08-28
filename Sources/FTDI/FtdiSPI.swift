//
//  FtdiSPI.swift
//  
//
//  Created by Kit Transue on 2020-08-01.
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

    /// AN_135_MPSSE_Basics lifetime: 4.2 Configure FTDI Port For MPSSE Use
    func configurePorts() {
        // Reset peripheral side
        //  rx buf purged
        //  bitmode: RESET
// FIXME: this is not a FT_ResetDevice, but a MPSSE controller reset, which is different
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
        setBitmode(.mpsse, outputPinMask: SerialPins.outputs.rawValue)
    }
    
    
    func initializePinState() {
        queueDataBits(values: 0, outputMask: SerialPins.outputs.rawValue, pins: .lowBytes)
    }
    
    
    /// AN_135_MPSSE_Basics lifetime: 4.3 Configure MPSSE
    func configureMPSSEForSPI(frequencyHz: Int) {
        // Clock speed
        configureClocking(frequencyHz: frequencyHz)
        // pin directions
        initializePinState()
        flushCommandQueue()
    }
    
    public func write(data: Data) {
        writeWithClock(data: data, during: .fallingEdge)
    }
}
