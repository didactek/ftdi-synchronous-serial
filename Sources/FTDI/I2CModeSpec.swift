//
//  I2CModeSpec.swift
//
//
//  Created by Kit Transue on 2020-08-29.
//  Copyright © 2020 Kit Transue
//  SPDX-License-Identifier: Apache-2.0
//

/// I2C modes.
///
/// Properties provide timing specifications and other mode-dependent attirbutes of the protocol.
/// See: [UM10204: I2C-bus specification and user manual](https://www.nxp.com/docs/en/user-guide/UM10204.pdf)
/// Table 10. Characteristics of the SDA and SCL bus lines for Standard, Fast, and Fast-mode Plus I2C-bus devices
/// Table 12. Characteristics of the SDAH, SCLH, SDA and SCL bus lines for Hs-mode I2C-bus devices[
enum I2CModeSpec {
    #if false  // unsupported
    /// 100 kbps
    case standard
    #endif
    /// 400 kbps
    case fast
    #if false  // unsupported
    /// 1 Mbps
    case fastPlus
    /// 3.4 Mbps
    case highSpeed
    /// 5 Mbps
    case ultraFast
    /// 1.4 Mbps
    case turbo  // not in spec, but per Wikipedia
    #endif

    var maxClockSpeed: Int {
        switch self {
            #if false
        case .standard:
            return 100_000
            #endif
        case .fast:
            return 400_000
        }
    }

    // FIXME: add hold timings.
}
