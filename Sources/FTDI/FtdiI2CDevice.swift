//
//  FtdiI2CDevice.swift
//
//
//  Created by Kit Transue on 2020-08-16.
//  Copyright © 2020 Kit Transue
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation

/// Manage conversations with a specific device at an I2C address, adding necessary start/stop blocks
/// to sustain and complete a conversation, including the two-start/one-stop `writeAndRead` operation.
public class FtdiI2CDevice {
    let address: UInt8
    let bus: FtdiI2C

    /// - Parameter busHost: Host from which I2C clock/conversations originate.
    /// - Parameter nodeAddress: I2C address of the target device on the bus.
    public init(busHost: FtdiI2C, nodeAddress: Int) throws {
        self.bus = busHost
        self.address = UInt8(nodeAddress)
    }

    public func supportsClockStretching() -> Bool {
        return bus.supportsClockStretching()
    }

    /// Write bytes to the device, preceded by a 'start' and followed by a 'stop'.
    public func write(data: Data) {
        bus.write(address: address, data: data)
        bus.sendStop()
    }

    /// Read bytes from the device, preceded by a 'start' and followed by a 'stop'.
    /// - Parameter count: Number of bytes to read.
    /// - Note: For devices that adopt a named register, address, or command idioms, use
    /// `writeAndRead` to send the name/address/command and read the response.
    public func read(count: Int) -> Data {
        let data = bus.read(address: address, count: count)
        bus.sendStop()
        return data
    }

    /// Write bytes to the device, read a response, and then send a 'stop' to end the conversation.
    /// - Parameter sendFrom: Bytes to send in the first conversation fragment.
    /// - Parameter receiveCount: Number of bytes to read in the second conversation fragment.
    /// - Returns: Bytes read.
    public func writeAndRead(sendFrom: Data, receiveCount: Int) -> Data {
        bus.write(address: address, data: sendFrom)
        let data = bus.read(address: address, count: receiveCount)
        bus.sendStop()
        return data
    }
}
