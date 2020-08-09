//
//  FtdiSPI.swift
//
//
//  Created by Kit Transue on 2020-08-01.
//  Copyright © 2020 Kit Transue
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation
import CLibUSB

public class FtdiSPI: LinkSPI {
    static let ctx: OpaquePointer? = nil // for sharing libusb contexts, init, etc.
    enum SPIError: Error {
        case bindingDeviceHandle
        case getConfiguration
        case claimInterface
    }

    var handle: OpaquePointer? = nil
    var wIndex: UInt16 = 1  // FIXME
    var usbWriteTimeout: UInt32 = 5000  // FIXME
    let writeEndpoint: UInt8
    let readEndpoint: UInt8

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
        print("device has", descriptor.bNumConfigurations, "configurations")
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
        let configurationIndex = 0
        let interfacesCount = configuration![configurationIndex].bNumInterfaces
        print("there are \(interfacesCount) interfaces on this device")  // FTDI reports only one, so that's the one we want
        // FIXME: check ranges at each array; scan for the write endpoint
        let interfaceNumber: Int32 = 0
        guard libusb_claim_interface(handle, interfaceNumber) == 0 else {
            throw SPIError.claimInterface
        }
        let interface = configuration![configurationIndex].interface[Int(interfaceNumber)]
        let endpointCount = interface.altsetting[0].bNumEndpoints
        print("Device has \(endpointCount) endpoints")
        let endpoints = (0 ..< endpointCount).map { interface.altsetting[0].endpoint[Int($0)] }
        // LIBUSB_ENDPOINT_IN/OUT is already shifted to bit 7:
        writeEndpoint = endpoints.first {$0.bEndpointAddress & (1 << 7) == LIBUSB_ENDPOINT_OUT.rawValue}!
            .bEndpointAddress
        readEndpoint = endpoints.first {$0.bEndpointAddress & (1 << 7) == LIBUSB_ENDPOINT_IN.rawValue}!
            .bEndpointAddress

        print("read endpoint:", readEndpoint)
        print("write endpoint:", writeEndpoint)

        configurePorts()
        confirmMPSSEModeEnabled()
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
        setBitmode(.mpsse, outputPinMask: SpiHardwarePins.outputs.rawValue)
    }


    /// AN_135_MPSSE_Basics lifetime: 4.3 Configure MPSSE
    func configureMPSSEForSPI() {
        // Clock speed
        setClock(frequencyHz: 1_000_000)
        // pin directions
        initializePinState()
    }

    func initializePinState() {
        // FIXME: it's not clear what setBitsLow does: is initial states or a mask or what?
        let pinSpec = Data([UInt8(SpiHardwarePins.inputs.rawValue), UInt8(SpiHardwarePins.outputs.rawValue)])
        callMPSSE(command: .setBitsLow, arguments: pinSpec)
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

    struct SpiHardwarePins: OptionSet {
        let rawValue: UInt16  // FIXME: would it be easier to deal in just the low bits?

        static let clock   = SpiHardwarePins(rawValue: 1 << 0)
        static let dataOut = SpiHardwarePins(rawValue: 1 << 1)
        static let dataIn  = SpiHardwarePins(rawValue: 1 << 2)

        static let outputs: SpiHardwarePins = [.clock, .dataOut]
        static let inputs: SpiHardwarePins = [.dataIn]
    }

    enum MpsseCommand: UInt8 {
        case writeBytesNveMsb = 0x11
        //...
        case setBitsLow = 0x80  // Change LSB GPIO output
        case setBitsHigh = 0x82  // Change MSB GPIO output
        case getBitsLow = 0x81  // Get LSB GPIO output
        case getBitsHigh = 0x83  // Get MSB GPIO output
        case loopbackStart = 0x84  // Enable loopback
        case loopbackEnd = 0x85  // Disable loopback
        case setTickDivisor = 0x86  // Set clock
        case enableClock3phase = 0x8c  // Enable 3-phase data clocking (I2C)
        case disableClock3phase = 0x8d  // Disable 3-phase data clocking
        case clockBitsNoData = 0x8e  // Allows JTAG clock to be output w/o data
        case clockBytesNoData = 0x8f  // Allows JTAG clock to be output w/o data
        case clockWaitOnHigh = 0x94  // Clock until GPIOL1 is high
        case clockWaitOnLow = 0x95  // Clock until GPIOL1 is low
        case enableClockAdaptive = 0x96  // Enable JTAG adaptive clock for ARM
        case disableClockAdaptive = 0x97  // Disable JTAG adaptive clock
        case clockCountWaitOnHigh = 0x9c  // Clock byte cycles until GPIOL1 is high
        case clockCountWaitOnLow = 0x9d  // Clock byte cycles until GPIOL1 is low
        case driveZero = 0x9e  // Drive-zero mode
        case bogus = 0xab  // per AN_135; should provoke "0xFA Bad Command" error
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

    func callMPSSE(command: MpsseCommand, arguments: Data) {
        let cmd = Data([command.rawValue]) + arguments
        bulkTransfer(msg: cmd)
        checkMPSSEResult()
    }

    func checkMPSSEResult() {
        let resultMessage = read()
        print("checkMPSSEResult read returned:", resultMessage.map { String($0, radix: 16)})
        guard resultMessage.count >= 2 else {
            fatalError("no MPSSE response found")
        }
        guard resultMessage[0] == 0x32 else {
            fatalError("MPSSE first byte of reply marker")
        }
        guard resultMessage[1] ==  0x60 else {
            fatalError("MPSSE results should be two-byte block")
        }
        guard resultMessage.count == 2 else {
            fatalError("MPSSE results included error report")
        }

    }

    func confirmMPSSEModeEnabled() {
        // FIXME: these flushes are necessary at this point; not sure where accumulated results come from
        checkMPSSEResult()
        checkMPSSEResult()
        checkMPSSEResult()

        let badOpcode = MpsseCommand.bogus.rawValue
        bulkTransfer(msg: Data([badOpcode]))
        let resultMessage = read()
        print("confirmMPSSEModeEnabled read returned:", resultMessage.map { String($0, radix: 16)})
        guard resultMessage.count >= 4 else {
            fatalError("results should have been available")
        }
        // first two bytes are hex 32,60
        guard resultMessage[2] == 0xfa else {
            fatalError("MPSSE mode should have returned \"bad opcode\" result (0xfa)")
        }
        guard resultMessage[3] == badOpcode else {
            fatalError("MPSSE should have explained the bad opcode")
        }
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
        let busClock = 6_000_000
        let divisor = (busClock + frequencyHz)/(2 * frequencyHz) - 1
        let divisorSetting = UInt16(clamping: divisor)

        let argument = withUnsafeBytes(of: divisorSetting) {Data($0)}

        callMPSSE(command: .setTickDivisor, arguments: argument)
    }
    // END Implementation of pyftdi documented constants/patterns
    #endif

    public func write(data: Data, count: Int) {
        guard count > 0 else {
            fatalError("write must send minimum of one byte")
        }
        let sizeSpec = UInt16(count - 1)
        let sizePrologue = withUnsafeBytes(of: sizeSpec.littleEndian) { Data($0) }

        callMPSSE(command: .writeBytesNveMsb, arguments: sizePrologue + data)
    }

    func bulkTransfer(msg: Data) {
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

    public func read() -> Data {
        let bufSize = 1024 // FIXME: tell the device about this!
        var readBuffer = Data(repeating: 0, count: bufSize)
        var readCount = Int32(0)
        let result = readBuffer.withUnsafeMutableBytes { unsafe in
            libusb_bulk_transfer(handle, readEndpoint, unsafe.bindMemory(to: UInt8.self).baseAddress, Int32(bufSize), &readCount, usbWriteTimeout)
        }
        guard result == 0 /*|| result == -8*/ else {  // FIXME: add -8; no data"?
            fatalError("bulkTransfer read returned \(result)")
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

