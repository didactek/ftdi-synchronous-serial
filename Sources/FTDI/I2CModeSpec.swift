//
//  I2CModeSpec.swift
//  
//
//  Created by Kit Transue on 2020-08-29.
//

/// I2C modes.
///
/// Properties provide timing specifications and other mode-dependent attirbutes of the protocol.
/// See: UM10204: I2C-bus specification and user manual
/// https://www.nxp.com/docs/en/user-guide/UM10204.pdf
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
    
    func clockSpeed() -> Int {
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
