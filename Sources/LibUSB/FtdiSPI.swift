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
        case getConfiguration
    }
    
    var handle: OpaquePointer? = nil
    var wIndex: UInt16 = 1  // FIXME
    var usbWriteTimeout: UInt32 = 5000  // FIXME
    let writeEndpoint: UInt8

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
        let result = libusb_open(device, &handle)
        guard result == 0 else {
            throw SPIError.bindingDeviceHandle
        }
        
        var configuration: UnsafeMutablePointer<libusb_config_descriptor>? = nil
        guard libusb_get_active_config_descriptor(device, &configuration) == 0 else {
            throw SPIError.getConfiguration
        }
        // FIXME: check ranges at each array; scan for the write endpoint
        // FIXME: endpoint still returns "endpoint not found on any open interface"
        writeEndpoint = configuration!.pointee.interface.pointee.altsetting.pointee.endpoint[0].bEndpointAddress
        
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
        setBitmode(.reset)
        // Configure USB transfer sizes
        // Set event/error characters
        // Set timeouts
        // Set latency timer
        setLatency(5000)
        // Set flow control
        // Reset MPSSE controller  //FIXME: different from "reset peripheral side", and if so: should these be different calls?
        //  bitmode: RESET
        setBitmode(.reset)
        //  rx buf purged
        // Enable MPSSE controller
        //  bitmode: MPSSE
        setBitmode(.mpsse, outputPinMask: SpiHardwarePin.clock.rawValue | SpiHardwarePin.dataOut.rawValue)
    }
    

    /// AN_135_MPSSE_Basics lifetime: 4.3 Configure MPSSE
    func configureMPSSEForSPI() {
        // Clock speed
        setClock(frequencyHz: 1_000_000)
        // pin directions--documentation says to set that now, but it's initially configured when setting the MPSSE bit mode
        // initial pin states
    }

    /// AN_135_MPSSE_Basics lifetime: Reset MPSSE and close port:
    func endMPSSE() {
        // Reset MPSSE
        setBitmode(.reset)
        // Close handles/resources
    }
    
    
    enum BRequestType: UInt8 {  // FIXME: credit pyftdi
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
    
    /// D2XX FT_SetBItmode values
    enum BitMode: UInt16 {
        // FIXME: harmonize comments with documentation
        case reset = 0x00  // switch off altnerative mode (default to UART)
        case bitbang = 0x01  // classical asynchronous bitbang mode
        case mpsse = 0x02  // MPSSE mode, available on 2232x chips
        case syncbb = 0x04  // synchronous bitbang mode
        case mcu = 0x08  // MCU Host Bus Emulation mode,
        case opto = 0x10  // Fast Opto-Isolated Serial Interface Mode
        case cbus = 0x20  // Bitbang on CBUS pins of R-type chips
        case syncff = 0x40  // Single Channel Synchronous FIFO mode
    }
    
    // FIXME: pins are almost certainly an option list
    enum SpiHardwarePin: UInt16 {
        case clock = 0x01
        case dataOut = 0x02
        case dataIn = 0x04
    }
    
    
    enum ControlRequestType: UInt8 {  // FIXME: credit pyftdi
        case standard = 0b00_00000
        case `class`  = 0b01_00000
        case vendor   = 0b10_00000
        case reserved = 0b11_00000
    }
    enum ControlDirection: UInt8 {  // FIXME: credit pyftdi
        case out = 0x00
        case `in` = 0x80
    }
    enum ControlRequestRecipient: UInt8 {  // FIXME: credit pyftdi
        case device = 0
        case interface = 1
        case endpoint = 2
        case other = 3
    }
    func controlRequest(type: ControlRequestType, direction: ControlDirection, recipient: ControlRequestRecipient) -> UInt8 {
        return type.rawValue | direction.rawValue | recipient.rawValue
    }

    func controlTransferOut(bRequest: BRequestType, value: UInt16, data: Data? = nil) {
        let requestType = controlRequest(type: .vendor, direction: .out, recipient: .device)
        
        var dataCopy = Array(data ?? Data())

        // FIXME: I'm pretty sure this bridging is wrong:
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
    
    func controlTransfer(requestType: UInt8, bRequest: BRequestType, wValue: UInt16, wIndex: UInt16, data: UnsafeMutablePointer<UInt8>!, wLength: UInt16, timeout: UInt32) -> Int32 {
        libusb_control_transfer(handle, requestType, bRequest.rawValue, wValue, wIndex, data, wLength, timeout)
    }
    
    func checkMPSSEResult() {
        // FIXME: implement
        // read
        // make assertion on results
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
    
    func setBitmode(_ mode: BitMode, outputPinMask: UInt16 = 0) {
        guard outputPinMask <= 0xff else {
            fatalError("directionMask bits out of range: 0x\(String(outputPinMask, radix: 16))")
        }
        let value = mode.rawValue << 8 | outputPinMask
        controlTransferOut(bRequest: .setBitmode, value: value, data: nil)
    }
    
    func setClock(frequencyHz: Int) {
        // FIXME: only low speed implemented currently
        // calculate divisors
        // write
        checkMPSSEResult()
    }
    // END Implementation of pyftdi documented constants/patterns
    #endif

    public func write(data: Data, count: Int) {
        guard count > 0 else {
            fatalError("write must send minimum of one byte")
        }
        // FIXME: also add the MPSSE command statement?
        let sizeSpec = UInt16(count - 1)
        let sizePrologue = withUnsafeBytes(of: sizeSpec.littleEndian) { Data($0) }
        
        bulkTransfer(msg: sizePrologue + data)
    }
    
    func bulkTransfer(msg: Data) {
        // dunno how to set these up:
        // ftdi.py talks also about "interface"
        var bytesTransferred: Int32 = 0
        let timeout: UInt32 = 5000
        
        let outgoingCount = Int32(msg.count)
        var data = msg // copy for safety
        let result = data.withUnsafeMutableBytes { unsafe in
            libusb_bulk_transfer(handle, writeEndpoint, unsafe.bindMemory(to: UInt8.self).baseAddress, outgoingCount, &bytesTransferred, timeout)
        }
        guard result == 0 else {
            fatalError("bulkTransfer returned \(result)")
        }
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

