//
//  FtdiSPI.swift
//  
//
//  Created by Kit Transue on 2020-08-01.
//

import Foundation
import CLibUSB

public class FtdiSPI: LinkSPI {
    static let ctx: OpaquePointer? = nil // for sharing libusb contexts, init, etc.
    enum SPIError: Error {
    }

    public init(speedHz: Int) {
        // find FTDI device
        let vendor = 0x00
        let product = 0x00
        let bus = 0x00
        let address = 0x00
        let serialNumber = 0x00
        let index = 0x00
        
        // scan for devices:
        let devices = UnsafeMutablePointer<UnsafeMutablePointer<OpaquePointer?>?>.allocate(capacity: 1)
        defer {
            devices.deallocate()
        }
        let deviceCount = libusb_get_device_list(Self.ctx, devices)
        print("found \(deviceCount) devices")
        exit(0)
        
        //devdesc = UsbDeviceDescriptor(vendor, product, bus, address, serial, index, None)
        var device: OpaquePointer? = nil
        
        // find the device
        
        var handle: OpaquePointer? = nil
        withUnsafeMutablePointer(to: &handle) {handle in
            let result = libusb_open(device, handle)
        }

        // switch to MPSSE
        // configure MPSSE
        // keep somehow
    }

    public func write(data: Data, count: Int) {
        // use USB device
    }
    
    public static func initializeUSBLibrary() {
        let resultRaw = libusb_init(nil)
        let result = libusb_error(rawValue: resultRaw)
        guard result == LIBUSB_SUCCESS else {
            let msg = String(cString: libusb_strerror(result))
            fatalError("libusb_init failed: \(msg)")
        }
    }
    
    public static func closeUSBLibrary() {
        libusb_exit(ctx)
    }
}

