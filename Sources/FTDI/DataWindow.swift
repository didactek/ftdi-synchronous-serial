//
//  DataWindow.swift
//  
//
//  Created by Kit Transue on 2020-08-29.
//

import Foundation

/// Relationship between clock state and valid data timing.
enum DataWindow {
    /// Transition to +ve; rising edge.
    case risingEdge
    /// Transition to -ve; falling edge.
    case fallingEdge
    /// While clock is high.
    case highClock
}
