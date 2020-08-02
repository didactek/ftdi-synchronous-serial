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
        
        // scan for devices:

        var devices: UnsafeMutablePointer<OpaquePointer?>? = nil
        let deviceCount = libusb_get_device_list(Self.ctx, &devices)
        guard deviceCount > 0 else {
            fatalError("no USB devices found")
        }
        print("found \(deviceCount) devices")

        let device = devices![0]
        
        var descriptor = libusb_device_descriptor()
        let _ = libusb_get_device_descriptor(device, &descriptor)
        print("vendor:", String(descriptor.idVendor, radix: 16))
        print("product:", String(descriptor.idProduct, radix: 16))


        // find the device

        // use the device:
        #if false  // FIXME: crashes; another example of getting pass-by-reference wrong?
        var handle: OpaquePointer? = nil
        withUnsafeMutablePointer(to: &handle) {handle in
            let result = libusb_open(device, handle)
            guard result == 0 else {
                fatalError("error binding device to a handle")
            }
        }
        #endif

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

