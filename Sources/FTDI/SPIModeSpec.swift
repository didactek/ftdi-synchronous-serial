//
//  SPIModeSpec.swift
//  
//
//  Created by Kit Transue on 2020-09-04.
//

import Foundation

/// Represents the state of the bus that is managed by the clock coordinator. The return data line is only
/// read by the coordinator.
struct SPIBusState {
    enum VoltageLevel {
        /// Low / -v / 0
        case low
        /// High / +v / 1
        case high
    }
    
    /// Serial clock output (SCLK)
    let sclk: VoltageLevel
    /// Data sent by the clock coordinator.
    /// - Remark: may be labeled "MOSI" on boards or documentation, but please avoid this acronym.
    /// Adafruit adopts the backronym "Microprocessor out, serial in," but it's awkward.
    let outgoingData: VoltageLevel
}

/// SPI Modes and their specifications.
///
/// SPI is an ad-hoc protocol. Many details available at the [Wikipedia SPI entry](https://en.wikipedia.org/wiki/Serial_Peripheral_Interface).
enum SPIModeSpec {
    case mode0
    #if false  // remainder not currently implemented
    case mode1
    case mode2
    case mode3
    #endif

    /// The edge when writing data must be valid.
    var writeWindow: DataWindow {
        switch self {
        case .mode0:
            return .fallingEdge
        }
    }
    
    /// Clock and outgoing data values for an idle bus.
    var busAtIdle: SPIBusState {
        switch self {
        case .mode0:
            return SPIBusState(sclk: .low, outgoingData: .low)
        }
    }
}
