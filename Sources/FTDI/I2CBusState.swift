//
//  I2CBusState.swift
//
//
//  Created by Kit Transue on 2020-08-29.
//  Copyright © 2020 Kit Transue
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation

/// I2C bus states as viewed by a device choosing how to write to the bus.
///
/// See: [UM10204: I2C-bus specification and user manual](https://www.nxp.com/docs/en/user-guide/UM10204.pdf)
struct I2CBusState {
    /// Options for setting a signal on an I2C bus line.
    ///
    /// See [UM10204](https://www.nxp.com/docs/en/user-guide/UM10204.pdf) 3.1.1: SDA and SCL signals
    enum TristateOutput {
        /// let the signal float (normally biased high, but may be sunk to zero by another device
        case float
        /// pull signal down to zero
        case zero
    }

    /// SDA: data line
    let sda: TristateOutput
    /// SCL: clock
    let scl: TristateOutput

    /// [UM10204](https://www.nxp.com/docs/en/user-guide/UM10204.pdf)  3.1.1: SDA and SCL high -> bus is free/unclaimed
    static let idle = Self(sda: .float, scl: .float)
    /// Hold the clock low; neutral state between operations
    static let clockLow = Self(sda: .float, scl: .zero)
}
