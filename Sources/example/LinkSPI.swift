//
//  LinkSPI.swift
//  
//
//  FIXME: Stub from Deft; integrate or factor... (and adjust copyright)
//

import Foundation
import FTDI

/// Send messages over an SPI channel.
public protocol LinkSPI {
    /// Send message over SPI.
    ///
    /// With many hardware configuration, the driven device does not communicate back to the initiating device.
    /// No error checking is possible; all writes are assumed to succeed. Framing errors may be hard to diagnose.
    func write(data: Data)
}

// FIXME: the SPI versions of these may run into the base class semantics. This is the wrong class to assure conformance on; need it on the *link*, which will encode address, etc.
extension FtdiSPI: LinkSPI {
    // maintain conformance with Deft project
}
