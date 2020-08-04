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
        case bindingDeviceHandle
    }
    
    var handle: OpaquePointer? = nil
    var wIndex: UInt16 = 1  // FIXME
    var usbWriteTimeout: UInt32 = 5000  // FIXME

    public init(speedHz: Int) throws {

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
        #endif


        // AN_135_MPSSE_Basics lifetime: Confirm device existence and open file handle
        // Style question: what is the best ordering of declare/open/guard/defer?
        let result = libusb_open(device, &handle)
        guard result == 0 else {
            throw SPIError.bindingDeviceHandle
        }
        
        configurePorts()
        configureMPSSEForSPI()
        // AN_135_MPSSE_Basics lifetime: Use serial port/GPIO:
    }
    
    deinit {
        guard let handle = handle else {
            fatalError("init should not have succeeded without creating handle")
        }

        endMPSSE()
        libusb_close(handle)
    }
    
    /// AN_135_MPSSE_Basics lifetime: 4.2 Configure FTDI Port For MPSSE Use
    func configurePorts() {
        // Reset peripheral side
        //  rx buf purged
        //  bitmode: RESET
        // Configure USB transfer sizes
        //  TX chunksize: 1024
        //  RX chunksize: 512
        // Set event/error characters
        // Set timeouts
        // Set latency timer
        setLatency(5000)
        // Set flow control
        // Reset MPSSE controller
        //  bitmode: RESET
        //  rx buf purged
        // Enable MPSSE controller
        //  bitmode: MPSSE
    }
    

    /// AN_135_MPSSE_Basics lifetime: 4.3 Configure MPSSE
    func configureMPSSEForSPI() {
        // Clock speed
        // pin directions
        // initial pin states
    }

    /// AN_135_MPSSE_Basics lifetime: Reset MPSSE and close port:
    func endMPSSE() {
        // Reset MPSSE
        // Close handles/resources
    }
    
    
    // FIXME: credit pyftdi
    enum BRequestType: UInt8 {
        case reset = 0x0  // Reset the port
        case setModemControl = 0x1  // Set the modem control register
        case setFlowControl = 0x2  // Set flow control register
        case setBaudrate = 0x3  // Set baud rate
        case setData = 0x4  // Set the data characteristics of the port
        case pollModemLineStatus = 0x5  // Get line status
        case setEventChar = 0x6  // Change event character
        case setErrorChar = 0x7  // Change error character
        case setLatencyTimer = 0x9  // Change latency timer
        case getLatencyTimer = 0xa  // Get latency timer
        case setBitmode = 0xb  // Change bit mode
        case readPins = 0xc  // Read GPIO pin value (or "get bitmode")
    }
    
    
    enum ControlRequestType: UInt8 {
        case standard = 0b00_00000
        case `class`  = 0b01_00000
        case vendor   = 0b10_00000
        case reserved = 0b11_00000
    }
    enum ControlDirection: UInt8 {
        case out = 0x00
        case `in` = 0x80
    }
    enum ControlRequestRecipient: UInt8 {
        case device = 0
        case interface = 1
        case endpoint = 2
        case other = 3
    }
    func controlRequest(type: ControlRequestType, direction: ControlDirection, recipient: ControlRequestRecipient) -> UInt8 {
        return type.rawValue | direction.rawValue | recipient.rawValue
    }

    func controlTransferOut(bRequest: BRequestType, value: UInt16, data: Data) {
        let requestType = controlRequest(type: .vendor, direction: .out, recipient: .device)
        
        var dataCopy = Array(data)

        // FIXME: I'm pretty sure this bridging is wrong:
        controlTransfer(requestType: requestType, bRequest: bRequest,
                        wValue: value, wIndex: wIndex,
                        data: &dataCopy,
                        wLength: UInt16(data.count), timeout: usbWriteTimeout)
    }
    
    func controlTransfer(requestType: UInt8, bRequest: BRequestType, wValue: UInt16, wIndex: UInt16, data: UnsafeMutablePointer<UInt8>!, wLength: UInt16, timeout: UInt32) {
        libusb_control_transfer(handle, requestType, bRequest.rawValue, wValue, wIndex, data, wLength, timeout)
    }
    
    #if true  // block crediting pyftdi
    // Implementation of these is heavily dependent on pyftdi.
    // FIXME: GIVE CREDIT:
    //    # Copyright (C) 2010-2020 Emmanuel Blot <emmanuel.blot@free.fr>
    //    # Copyright (c) 2016 Emmanuel Bouaziz <ebouaziz@free.fr>
    //    # All rights reserved.


    func setLatency(_ unspecifiedUnit: UInt16) {
        controlTransferOut(bRequest: .setLatencyTimer, value: unspecifiedUnit, data: Data())
    }
    // END Implementation of pyftdi dependent functions
    #endif

    public func write(data: Data, count: Int) {
        // Message prologue includes number of bytes in the message
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

