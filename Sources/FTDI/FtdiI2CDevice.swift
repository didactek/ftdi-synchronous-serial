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

    /// Semaphore held by public methods from I2C start to I2C stop.
    let busReservedSemaphore = DispatchSemaphore(value: 1)

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
    public func write(data: Data) throws {
        busReservedSemaphore.wait()
        defer {
            bus.sendStop()
            busReservedSemaphore.signal()
        }
        try bus.write(address: address, data: data)
    }

    /// Read bytes from the device, preceded by a 'start' and followed by a 'stop'.
    /// - Parameter count: Number of bytes to read.
    /// - Note: For devices that adopt a named register, address, or command idioms, use
    /// `writeAndRead` to send the name/address/command and read the response.
    public func read(count: Int) throws -> Data {
        busReservedSemaphore.wait()
        defer {
            bus.sendStop()
            busReservedSemaphore.signal()
        }
        return try bus.read(address: address, count: count)
    }

    /// Write bytes to the device, read a response, and then send a 'stop' to end the conversation.
    /// - Parameter sendFrom: Bytes to send in the first conversation fragment.
    /// - Parameter receiveCount: Number of bytes to read in the second conversation fragment.
    /// - Returns: Bytes read.
    public func writeAndRead(sendFrom: Data, receiveCount: Int) throws -> Data {
        busReservedSemaphore.wait()
        defer {
            bus.sendStop()
            busReservedSemaphore.signal()
        }

        try bus.write(address: address, data: sendFrom)
        return try bus.read(address: address, count: receiveCount)
    }
}
