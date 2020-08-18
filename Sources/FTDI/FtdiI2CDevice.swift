//
//  FtdiI2CDevice.swift
//
//
//  Created by Kit Transue on 2020-08-16.
//  Copyright © 2020 Kit Transue
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation

public class FtdiI2CDevice {
    let address: UInt8
    let bus: FtdiI2C

    // FIXME: throw if the address isn't found on the bus?
    public init(bus: FtdiI2C, nodeAddress: Int) throws {
        self.bus = bus
        self.address = UInt8(nodeAddress)
    }

    public func write(data: Data) {
        bus.write(address: address, data: data)
        bus.sendStop()
    }

    public func read(count: Int) -> Data {
        let data = bus.read(address: address, count: count)
        bus.sendStop()
        return data
    }

    public func writeAndRead(sendFrom: Data, receiveCount: Int) -> Data {
        bus.write(address: address, data: sendFrom)
        let data = bus.read(address: address, count: receiveCount)
        bus.sendStop()
        return data
    }
}
