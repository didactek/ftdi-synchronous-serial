//
//  USBDevice.swift
//  ftdi-synchronous-serial
//
//  Created by Kit Transue on 2020-08-02.
//  Copyright © 2020 Kit Transue
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation
import CLibUSB

public class USBDevice {
    static let ctx: OpaquePointer? = nil // for sharing libusb contexts, init, etc.
    enum USBError: Error {
        case bindingDeviceHandle
        case getConfiguration
        case claimInterface
    }

    var handle: OpaquePointer? = nil
    var wIndex: UInt16 = 1  // FIXME
    var usbWriteTimeout: UInt32 = 5000  // FIXME
    let writeEndpoint: UInt8
    let readEndpoint: UInt8

    public init() throws {
        // scan for devices:
        var devices: UnsafeMutablePointer<OpaquePointer?>? = nil
        let deviceCount = libusb_get_device_list(Self.ctx, &devices)
        guard deviceCount > 0 else {
            fatalError("no USB devices found")
        }
        print("found \(deviceCount) devices")

        // find the device
        // FIXME: be more precise than this!
        let device = devices![0]

        #if true // optional: this is just "we found something!" reassurance
        var descriptor = libusb_device_descriptor()
        let _ = libusb_get_device_descriptor(device, &descriptor)
        print("vendor:", String(descriptor.idVendor, radix: 16))
        print("product:", String(descriptor.idProduct, radix: 16))
        print("device has", descriptor.bNumConfigurations, "configurations")
        #endif


        let result = libusb_open(device, &handle)
        guard result == 0 else {
            throw USBError.bindingDeviceHandle
        }

        var configuration: UnsafeMutablePointer<libusb_config_descriptor>? = nil
        guard libusb_get_active_config_descriptor(device, &configuration) == 0 else {
            throw USBError.getConfiguration
        }
        let configurationIndex = 0
        let interfacesCount = configuration![configurationIndex].bNumInterfaces
        print("there are \(interfacesCount) interfaces on this device")  // FTDI reports only one, so that's the one we want
        // FIXME: check ranges at each array; scan for the write endpoint
        let interfaceNumber: Int32 = 0
        guard libusb_claim_interface(handle, interfaceNumber) == 0 else {
            throw USBError.claimInterface
        }
        let interface = configuration![configurationIndex].interface[Int(interfaceNumber)]
        let endpointCount = interface.altsetting[0].bNumEndpoints
        print("Device has \(endpointCount) endpoints")
        let endpoints = (0 ..< endpointCount).map { interface.altsetting[0].endpoint[Int($0)] }
        // LIBUSB_ENDPOINT_IN/OUT is already shifted to bit 7:
        writeEndpoint = endpoints.first {Self.isWriteable(endpointAddress: $0.bEndpointAddress)}!
            .bEndpointAddress
        readEndpoint = endpoints.first {!Self.isWriteable(endpointAddress: $0.bEndpointAddress)}!
            .bEndpointAddress
    }
    deinit {
        libusb_close(handle)
    }

    // USB spec 2.0, sec 9.3: USB Device Requests
    // USB spec 2.0, sec 9.3.1: bmRequestType
    typealias BMRequestType = UInt8
    enum ControlDirection: BMRequestType {
        case hostToDevice = 0b0000_0000
        case deviceToHost = 0b1000_0000
    }
    enum ControlRequestType: BMRequestType {
        case standard = 0b00_00000
        case `class`  = 0b01_00000
        case vendor   = 0b10_00000
        case reserved = 0b11_00000
    }
    enum ControlRequestRecipient: BMRequestType {
        case device = 0
        case interface = 1
        case endpoint = 2
        case other = 3
    }
    func controlRequest(type: ControlRequestType, direction: ControlDirection, recipient: ControlRequestRecipient) -> BMRequestType {
        return type.rawValue | direction.rawValue | recipient.rawValue
    }


    func controlTransferOut(bRequest: UInt8, value: UInt16, data: Data? = nil) {
        let requestType = controlRequest(type: .vendor, direction: .hostToDevice, recipient: .device)

        var dataCopy = Array(data ?? Data())

        let result = controlTransfer(requestType: requestType,
                                     bRequest: bRequest,
                                     wValue: value, wIndex: wIndex,
                                     data: &dataCopy,
                                     wLength: UInt16(dataCopy.count), timeout: usbWriteTimeout)
        guard result == 0 else {
            // FIXME: should probably throw rather than abort, and maybe not all calls need to be this strict
            fatalError("controlTransferOut failed")
        }
    }

    func controlTransfer(requestType: BMRequestType, bRequest: UInt8, wValue: UInt16, wIndex: UInt16, data: UnsafeMutablePointer<UInt8>!, wLength: UInt16, timeout: UInt32) -> Int32 {
        libusb_control_transfer(handle, requestType, bRequest, wValue, wIndex, data, wLength, timeout)
    }

    static func isWriteable(endpointAddress: UInt8) -> Bool {
        endpointAddress & (1 << 7) == LIBUSB_ENDPOINT_OUT.rawValue
    }

    func bulkTransferOut(msg: Data) {
        var bytesTransferred = Int32(0)

        let outgoingCount = Int32(msg.count)
        var data = msg // copy for safety
        let result = data.withUnsafeMutableBytes { unsafe in
            libusb_bulk_transfer(handle, writeEndpoint, unsafe.bindMemory(to: UInt8.self).baseAddress, outgoingCount, &bytesTransferred, usbWriteTimeout)
        }
        guard result == 0 else {
            fatalError("bulkTransfer returned \(result)")
        }
    }

    public func bulkTransferIn() -> Data {
        let bufSize = 1024 // FIXME: tell the device about this!
        var readBuffer = Data(repeating: 0, count: bufSize)
        var readCount = Int32(0)
        let result = readBuffer.withUnsafeMutableBytes { unsafe in
            libusb_bulk_transfer(handle, readEndpoint, unsafe.bindMemory(to: UInt8.self).baseAddress, Int32(bufSize), &readCount, usbWriteTimeout)
        }
        guard result == 0 else {
            let errorMessage = String(cString: libusb_error_name(result))
            fatalError("bulkTransfer read returned \(result): \(errorMessage)")
        }
        return readBuffer.prefix(Int(readCount))
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
