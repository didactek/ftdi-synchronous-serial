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

        configureMPSSEForSPI(frequencyHz: speedHz)
        // AN_135_MPSSE_Basics lifetime: Use serial port/GPIO:
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
