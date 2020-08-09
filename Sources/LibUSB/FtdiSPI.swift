//
//  FtdiSPI.swift
//  
//
//  Created by Kit Transue on 2020-08-01.
//

import Foundation


public class FtdiSPI: LinkSPI {
    let device: USBDevice

    public init(speedHz: Int) throws {
        // AN_135_MPSSE_Basics lifetime: 4.1 Confirm device existence and open file handle
        device = try USBDevice()
        
        configurePorts()
        confirmMPSSEModeEnabled()
        configureMPSSEForSPI(frequencyHz: speedHz)
        // AN_135_MPSSE_Basics lifetime: Use serial port/GPIO:
    }
    
    deinit {
        endMPSSE()
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
    func configureMPSSEForSPI(frequencyHz: Int) {
        // Clock speed
        setClock(frequencyHz: frequencyHz)
        // pin directions
        initializePinState()
    }
    
    func initializePinState() {
        setDataBits(values: 0, outputMask: SpiHardwarePins.outputs.rawValue, pins: .lowBytes)
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
        case reset = 0x00  // switch off alternative mode (default to UART)
        case bitbang = 0x01  // classical asynchronous bitbang mode
        case mpsse = 0x02  // MPSSE mode, available on 2232x chips
        case syncbb = 0x04  // synchronous bitbang mode
        case mcu = 0x08  // MCU Host Bus Emulation mode,
        case opto = 0x10  // Fast Opto-Isolated Serial Interface Mode
        case cbus = 0x20  // Bitbang on CBUS pins of R-type chips
        case syncff = 0x40  // Single Channel Synchronous FIFO mode
    }
    
    struct SpiHardwarePins: OptionSet {
        let rawValue: UInt8
        
        static let clock   = SpiHardwarePins(rawValue: 1 << 0)
        static let dataOut = SpiHardwarePins(rawValue: 1 << 1)
        static let dataIn  = SpiHardwarePins(rawValue: 1 << 2)
        
        static let outputs: SpiHardwarePins = [.clock, .dataOut]
        static let inputs: SpiHardwarePins = [.dataIn]
    }
    
    // AN_108: Command Processor for MPSSE and MCU Host Bus Emulation Modes
    // Ch 3: Command Definitions
    enum MpsseCommand: UInt8 {
        // 3.2 Data Shifting (sending serial data synchronized with clock)
        case writeBytesNveMsb = 0x11
        //...

        // 3.6 Set / Read Data Bits High / Low Bytes
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
    

    
    func callMPSSE(command: MpsseCommand, arguments: Data) {
        let cmd = Data([command.rawValue]) + arguments
        device.bulkTransfer(msg: cmd)
        checkMPSSEResult()
    }
    
    func checkMPSSEResult() {
        let resultMessage = device.read()
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
        device.bulkTransfer(msg: Data([badOpcode]))
        let resultMessage = device.read()
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
    
    enum GpioBlock {
        // lots of commands operate on either the high byte pins or the low byte
        // pins.
        
        // 3.6
        case highBytes // ACBUS 7-0
        case lowBytes  // ADBUS 7-0
        
        // By encoding the parallelism of opCodes, we can reduce the number of
        // explicit implementations of functions. Because the compiler will enforce
        // case coverage, it reminds us to keep these opCode maps complete.
        func opCodeSet() -> MpsseCommand {
            switch self {
            case .highBytes:
                return .setBitsHigh
            case .lowBytes:
                return .setBitsLow
            }
        }
    }

    /// Define pins as input or output
    ///
    /// values sets level on output pins
    /// 1 in outputMask marks pin as an output
    func setDataBits(values: UInt8, outputMask: UInt8, pins: GpioBlock) {
        let cmd = pins.opCodeSet()
        let pinSpec = Data([values, outputMask])
        callMPSSE(command: cmd, arguments: pinSpec)
    }
    
    #if true  // block crediting pyftdi
    // Implementation of these is heavily dependent on pyftdi.
    // FIXME: GIVE CREDIT:
    //    # Copyright (C) 2010-2020 Emmanuel Blot <emmanuel.blot@free.fr>
    //    # Copyright (c) 2016 Emmanuel Bouaziz <ebouaziz@free.fr>
    //    # All rights reserved.

    func controlTransferOut(bRequest: BRequestType, value: UInt16, data: Data?) {
        device.controlTransferOut(bRequest: bRequest.rawValue, value: value, data: data)
    }

    func setLatency(_ unspecifiedUnit: UInt16) {
        controlTransferOut(bRequest: .setLatencyTimer, value: unspecifiedUnit, data: Data())
    }

    func setBitmode(_ mode: BitMode, outputPinMask: UInt8 = 0) {
        let value = mode.rawValue << 8 | UInt16(outputPinMask)
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
}

