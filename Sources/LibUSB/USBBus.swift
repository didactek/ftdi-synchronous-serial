//
//  USBBus.swift
//
//
//  Created by Kit Transue on 2020-08-11.
//  Copyright © 2020 Kit Transue
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation
import CLibUSB


public class USBBus {
    let ctx: OpaquePointer? = nil // for sharing libusb contexts, init, etc.


    public func findDevice(idVendor: Int?, idProduct: Int?, serialNumber: String?) throws -> USBDevice {
        // scan for devices:
        var devices: UnsafeMutablePointer<OpaquePointer?>? = nil
        let deviceCount = libusb_get_device_list(ctx, &devices)
        defer {
            libusb_free_device_list(devices, 1)
        }
        guard deviceCount > 0 else {
            fatalError("no USB devices found")
        }
        logger.debug("found \(deviceCount) devices")

        // find the device
        // FIXME: be more precise than this! Look at all the entries; libusb
        // says libusb_open_device_with_vid_pid is a crutch and that enumeration
        // is the right way to go....
        let device = devices![0]

        #if true
        deviceDetail(device: device!)
        #endif

        return try USBDevice(subsystem: self, device: device!)
    }

    func deviceDetail(device: OpaquePointer) {
        var descriptor = libusb_device_descriptor()
        let _ = libusb_get_device_descriptor(device, &descriptor)
        logger.debug("vendor: \(String(descriptor.idVendor, radix: 16))")
        logger.debug("product: \(String(descriptor.idProduct, radix: 16))")

        #if false  // FIXME: do string lookup
        // get the serial number:
        // need a lang descriptor
        let bufSize = 1024
        var serialNumber = Data(repeating: 0, count: bufSize)
        let serialNumberIndex = descriptor.iSerialNumber
        libusb_get_descriptor(handle, LIBUSB_DT_STRING, serialNumberIndex, &serialNumber, Int32(bufSize))
        // some kind of get_description call here
        logger.debug("device has \(descriptor.bNumConfigurations) configurations")
        #endif
    }

     public init() {
        // FIXME: how to do this better, and where?
        logger.logLevel = .trace

        let resultRaw = libusb_init(nil)
        let result = libusb_error(rawValue: resultRaw)
        guard result == LIBUSB_SUCCESS else {
            let msg = String(cString: libusb_strerror(result))
            fatalError("libusb_init failed: \(msg)")
        }
    }

    deinit {
        libusb_exit(ctx)
    }
}
