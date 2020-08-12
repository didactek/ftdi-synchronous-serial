//
//  USBDevice.swift
//  libusb-swift
//
//  Created by Kit Transue on 2020-08-02.
//

import Foundation
import Logging
import CLibUSB

// FIXME: what should I be using for logging?
// FIXME: is defining a logging label even *appropriate* for a library function?
var logger = Logger(label: "com.didactek.libusb.main")
// how to default configuration to debug?

struct EndpointAddress {
    typealias RawValue = UInt8
    let rawValue: RawValue
    
    init(rawValue: UInt8) {
        self.rawValue = rawValue
    }
    
    // USB 2.0: 9.6.6 Endpoint:
    // Bit 7 is direction IN/OUT
    let directionMask = Self.RawValue(LIBUSB_ENDPOINT_IN.rawValue | LIBUSB_ENDPOINT_OUT.rawValue)

    var isWritable: Bool {
        get {
            return rawValue & directionMask == LIBUSB_ENDPOINT_OUT.rawValue
        }
    }
}



public class USBDevice {
    
    enum USBError: Error {
        case bindingDeviceHandle
        case getConfiguration
        case claimInterface
    }
    
    let device: OpaquePointer
    var handle: OpaquePointer? = nil
    let interfaceNumber: Int32 = 0

    var usbWriteTimeout: UInt32 = 5000  // FIXME
    let writeEndpoint: EndpointAddress
    let readEndpoint: EndpointAddress


    init(device: OpaquePointer) throws {
        self.device = device
        libusb_ref_device(device)  // register ownership

        let result = libusb_open(device, &handle)  // deinit: libusb_close
        guard result == 0 else {
            throw USBError.bindingDeviceHandle
        }
        
        var configurationPtr: UnsafeMutablePointer<libusb_config_descriptor>? = nil
        defer {
            libusb_free_config_descriptor(configurationPtr)
        }
        guard libusb_get_active_config_descriptor(device, &configurationPtr) == 0 else {
            throw USBError.getConfiguration
        }
        guard let configuration = configurationPtr else {
            throw USBError.getConfiguration
        }
        let configurationIndex = 0
        let interfacesCount = configuration[configurationIndex].bNumInterfaces
        logger.debug("there are \(interfacesCount) interfaces on this device")  // FTDI reports only one, so that's the one we want
        // FIXME: check ranges at each array; scan for the write endpoint
        guard libusb_claim_interface(handle, interfaceNumber) == 0 else {  // deinit: libusb_release_interface
            throw USBError.claimInterface
        }
        let interface = configuration[configurationIndex].interface[Int(interfaceNumber)]

        let endpointCount = interface.altsetting[0].bNumEndpoints
        logger.debug("Device/Interface has \(endpointCount) endpoints")
        let endpoints = (0 ..< endpointCount).map { interface.altsetting[0].endpoint[Int($0)] }
        let addresses = endpoints.map { EndpointAddress(rawValue: $0.bEndpointAddress) }
        writeEndpoint = addresses.first { $0.isWritable }!
        readEndpoint = addresses.first { !$0.isWritable }!
    }
    deinit {
        libusb_release_interface(handle, interfaceNumber)
        libusb_close(handle)
        libusb_unref_device(device)
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
    

    public func controlTransferOut(bRequest: UInt8, value: UInt16, wIndex: UInt16, data: Data? = nil) {
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
        // USB 2.0 9.3.4: wIndex
        // some interpretations (high bits 0):
        //   as endpoint (direction:1/0:3/endpoint:4)
        //   as interface (interface number)
        // semantics for ControlRequestType.standard requests are defined in
        // Table 9.4 Standard Device Requests
        // ControlRequestType.vendor semantics may vary.
        // FIXME: could we make .standard calls more typesafe?
        libusb_control_transfer(handle, requestType, bRequest, wValue, wIndex, data, wLength, timeout)
    }
    
 
    public func bulkTransferOut(msg: Data) {
        var bytesTransferred = Int32(0)
        
        let outgoingCount = Int32(msg.count)
        var data = msg // copy for safety
        let result = data.withUnsafeMutableBytes { unsafe in
            libusb_bulk_transfer(handle, writeEndpoint.rawValue, unsafe.bindMemory(to: UInt8.self).baseAddress, outgoingCount, &bytesTransferred, usbWriteTimeout)
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
            libusb_bulk_transfer(handle, readEndpoint.rawValue, unsafe.bindMemory(to: UInt8.self).baseAddress, Int32(bufSize), &readCount, usbWriteTimeout)
        }
        guard result == 0 else {
            let errorMessage = String(cString: libusb_error_name(result)) // must not free message
            fatalError("bulkTransfer read returned \(result): \(errorMessage)")
        }
        return readBuffer.prefix(Int(readCount))
    }
}
