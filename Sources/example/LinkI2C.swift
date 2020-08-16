//
//  LinkI2C.swift
//  
//
//  Created by Kit Transue on 2020-08-16.
//
//  FIXME: Stub from Deft; integrate or factor... (and adjust copyright)
//

import Foundation
import FTDI

/// Interface to support talking to a connected I^2C device.
///
/// I^2C devices typically reset their parsing state at the beginning of a conversation; state is discarded
/// when the STOP signal indicates the end of the exchange.
///
/// Each operation here finishes by terminating the conversation with a STOP.
///
/// `BitStorageCore`-derived objects may assist in coding and decoding `Data` arguments.
public protocol LinkI2C {
    /// Send count bytes to the devlce in a single message.
    func write(data: Data)
    
    /// Read count bytes from the device in a single STOP-terminated message.
    ///
    /// Note: reads via this interface are strictly a pull from the device with no mechanism for the master to encode a request.
    /// Simple conversations are usually highly typical, with only one format for read actions.
    func read(data: inout Data, count: Int)
    
    
    /// Send and receive bytes in a single I2C conversation.
    ///
    /// Commonly used in patterns like reading from a named register.
    func writeAndRead(sendFrom: Data, receiveInto: inout Data, receiveCount: Int)
}

extension FtdiI2CDevice: LinkI2C {
    // maintain conformance with Deft project
}
