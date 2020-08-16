//
//  FtdiI2CDevice.swift
//  
//
//  Created by Kit Transue on 2020-08-16.
//

import Foundation

public class FtdiI2CDevice {
    let address: UInt8
    let bus: FtdiI2C
    
    public init(bus: FtdiI2C, address: UInt8) {
        self.bus = bus
        self.address = address
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
