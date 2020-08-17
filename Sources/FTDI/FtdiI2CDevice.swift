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

    public func read(data: inout Data, count: Int) {
        bus.read(address: address, data: &data, count: count)
        bus.sendStop()
    }

    public func writeAndRead(sendFrom: Data, receiveInto: inout Data, receiveCount: Int) {
        bus.write(address: address, data: sendFrom)
        bus.read(address: address, data: &receiveInto, count: receiveCount)
        bus.sendStop()
    }
}
