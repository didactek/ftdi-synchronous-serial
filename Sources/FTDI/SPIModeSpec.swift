//
//  SPIModeSpec.swift
//
//
//  Created by Kit Transue on 2020-09-04.
//  Copyright © 2020 Kit Transue
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation

/// SPI Modes and their specifications.
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

    /// clock and dataOut values for an idle bus.
    /// (as a bit field)
    // FIXME: how to make this implementation-independent so this can be moved to a specification-only file?
    var busAtIdle: UInt8 {
        switch self {
        case .mode0:
            return 0
        }
    }
}
