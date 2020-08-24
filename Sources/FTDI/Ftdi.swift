//
//  Ftdi.swift
//  
//
//  Created by Kit Transue on 2020-08-01.
//

import Foundation
import Logging
import LibUSB

var logger = Logger(label: "com.didactek.libusb.ftdi-core")

public class Ftdi {
    let device: USBDevice

    
    public init() throws {
        let usbSubsystem = USBBus()
        device = try usbSubsystem.findDevice()
        logger.logLevel = .trace
    }

    
    /// AN_135_MPSSE_Basics lifetime: Reset MPSSE and close port:
    func endMPSSE() {
        // Reset MPSSE
        setBitmode(.reset)
        // Close handles/resources
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
    
     
    // AN_108: Command Processor for MPSSE and MCU Host Bus Emulation Modes
    // Ch 3: Command Definitions
    enum MpsseCommand: UInt8 {
        // 3.2 Data Shifting (sending serial data synchronized with clock)
        // Pve == +ve == rising edge
        // Nve == -ve == falling edge
        
        // 3.3 Data Shifting, MSB
        case writeBytesPveMsb = 0x10
        case writeBytesNveMsb = 0x11
        case writeBitsPveMsb = 0x12
        case writeBitsNveMsb = 0x13
        case readBytesPveMsb = 0x20
        case readBytesNveMsb = 0x24
        case readBitsPveMsb = 0x22
        case readBitsNveMsb = 0x26
        case outNveInPveBytesMsb = 0x31
        case outPveInNveBytesMsb = 0x34
        case outNveInPveBitsMsb = 0x33
        case outPveInNveBitsMsb = 0x36
        
        // 3.4 Data Shifting, LSB
        case writeBytesPveLsb = 0x18
        case writeBytesNveLsb = 0x19
        case writeBitsPveLsb = 0x1a
        case writeBitsNveLsb = 0x1b
        case readBytesPveLsb = 0x28
        case readBytesNveLsb = 0x2c
        case readBitsPveLsb = 0x2a
        case readBitsNveLsb = 0x2e
        case outNveInPveBytesLsb = 0x39
        case outPveInNveBytesLsb = 0x3c
        case outNveInPveBitsLsb = 0x3b
        case outPveInNveBitsLsb = 0x3e

        // FIXME: add others as necessary/convenient

        // 3.6 Set / Read Data Bits High / Low Bytes
        case setBitsLow = 0x80  // Change LSB GPIO output
        case setBitsHigh = 0x82  // Change MSB GPIO output
        case getBitsLow = 0x81  // Get LSB GPIO output
        case getBitsHigh = 0x83  // Get MSB GPIO output
        
        // 3.7 Loopback
        case loopbackStart = 0x84  // Enable loopback
        case loopbackEnd = 0x85  // Disable loopback
        
        // 3.8 Clock
        case setTCKDivisor = 0x86  // Set TCK/SK divisor
        // 6 FT232H, FT2232H & FT4232H only
        case disableClockDivide5 = 0x8a  // Enable 60 MHz clock transitions (30MHz cycle)
        case enableClockDivide5 = 0x8b  // Enable 12 MHz clock transitions (6MHz cycle)
        case enableClock3Phase = 0x8c  // Enable 3-phase data clocking (I2C)
        case disableClock3Phase = 0x8d  // Disable 3-phase data clocking
        case clockBitsNoData = 0x8e  // Clock for n+1 cycles with no data transfer (JTAG)
        case clockBytesNoData = 0x8f  // Clock for 8*(n+1) cycles with no data transfer
        case clockWaitOnHigh = 0x94  // Clock until GPIOL1 goes low **
        case clockWaitOnLow = 0x95  // Clock until GPIOL1 goes high **
        case enableAdaptiveClocking = 0x96  // Gate clock on RTCK read from GPIOL3 (ARM/JTAG)
        case disableAdaptiveClocking = 0x97  // Disable adaptive clocking
        case clockWaitOnHighTimeout = 0x9c  // Clock until GPIOL1 is high or 8*(n+1) cycles
        case clockWaitOnLowTimeout = 0x9d  // Clock until GPIOL1 is low or 8*(n+1) cycles
        
        // 5 Instruction release/flow control
        
        // 5.1 Send Immediate
        case sendImmediate = 0x87  // Flush; request immediate response
        
        // 7.1 Drive on '0'; Tristate on '1'
        case onlyDriveZero = 0x9e  // Set output pins to float on '1' (I2C)
        
        case bogus = 0xab  // per AN_135; should provoke "0xFA Bad Command" error
        
        // ** documentation is unclear or inconsistent in its description
    }
    
    
    
    private func callMPSSE(command: MpsseCommand, arguments: Data) {
        let cmd = Data([command.rawValue]) + arguments
        device.bulkTransferOut(msg: cmd)
        checkMPSSEResult()
    }
    
    func checkMPSSEResult() {
        // FIXME: some commands return information (like 'getBits*')
        let resultMessage = device.bulkTransferIn()
        logger.trace("checkMPSSEResult read returned: \(resultMessage.map { String($0, radix: 16)})")
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
        // FIXME: these flushes are necessary at this point; not sure where accumulated results come from.
        // Three reads seem to be required; more are OK.
        // Thread.sleep(until: Date(timeIntervalSinceNow: 0.100)) or its equivalent to stabilize results does
        // not seem to make any kind of difference.
        checkMPSSEResult()
        checkMPSSEResult()
        checkMPSSEResult()
        
        let badOpcode = MpsseCommand.bogus.rawValue
        device.bulkTransferOut(msg: Data([badOpcode]))
        let resultMessage = device.bulkTransferIn()
        logger.trace("confirmMPSSEModeEnabled read returned: \(resultMessage.map { String($0, radix: 16)})")
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

    /// Set the clock output frequency.
    ///
    /// This sets up an internal clock that triggers each pin change managed by the
    /// clock circuitry. To drive a simple square wave, two triggers are needed per cycle:
    /// one for each XOR of the clock.
    ///
    /// For the three-phase clock, three state changes are required,
    /// so the effective frequency on the clocked pin is 1/3 the frequency
    /// of the internal operations.
    ///
    /// frequencyHz is the desired full cycle rate on the clock pin.
    func setClock(frequencyHz: Int, forThreePhase: Bool = false) {
        let timedActionsPerCycle = forThreePhase ? 3 : 2

        // FIXME: only low speed implemented currently
        // FIXME: explicitly enabling/disabling divide-by-5 is recommended.
        let internalClock = 12_000_000

        /// AN 135 3.2.1
        let divisor = internalClock / (timedActionsPerCycle * frequencyHz) - 1

        let divisorSetting = UInt16(clamping: divisor)
        let argument = withUnsafeBytes(of: divisorSetting.littleEndian) {Data($0)}
        
        callMPSSE(command: .setTCKDivisor, arguments: argument)
    }
    
    func disableAdaptiveClock() {
        callMPSSE(command: .disableAdaptiveClocking, arguments: Data())
    }
    
    /// Sustain data through clock phase.
    ///
    /// Behavior of the "3-phase" clock: set up data for 1/3 cycle; change
    /// clock for 1/3 cycle; return clock to starting for 1/3 cycle.
    /// Full cycle takes three triggers of the internal clock used for state transitions, so
    /// the setClock frequency needs to be adjusted appropriately.
    func enableThreePhaseClock() {
        callMPSSE(command: .enableClock3Phase, arguments: Data())
    }
    
    public enum DataWindow {
        case risingEdge // +ve; rising/high
        case fallingEdge // -ve; falling/low
        case highClock // 3-phase clock, data valid when clock high
    }
    
    public enum BitOrder {
        case msb // most-significant bit first
        case lsb // least-significant bit first
    }
    
    
    /// Write data.
    ///
    /// Put data onto the I2C SDA pin, with one bit per clock cycle.
    /// If the clock is in the specified state, then assert SDA for one clock cycle. If the clock is not in the specified starting state, then set it to starting state and assert SDA; hold SDA for clock cycle.
    ///
    /// For the "3-phase" clock: set up data for 1/3 cycle; change
    /// clock for 1/3 cycle; return clock to starting for 1/3 cycle.
    public func write(data: Data, during window: DataWindow, bitOrder: BitOrder = .msb) {
        guard data.count > 0 else {
            fatalError("write must send minimum of one byte")
        }

        let command: MpsseCommand
        // FIXME: it might be possible to make this table from raw values and the semantics in Table 3.2?
        switch bitOrder {
        case .msb:
            switch window {
            case .risingEdge:
                command = .writeBytesPveMsb
            case .fallingEdge:
                command = .writeBytesNveMsb
            case .highClock:
                command = .writeBytesNveMsb  // not obvious from documentation; see AN 113 2.3.1 Definitions and Functions for examples
            }
        case .lsb:
            switch window {
            case .risingEdge:
                command = .writeBytesPveLsb
            case .fallingEdge:
                command = .writeBytesNveLsb
            case .highClock:
                command = .writeBytesNveLsb  // not obvious from documentation
            }
        }

        let sizeSpec = UInt16(data.count - 1)
        let sizePrologue = withUnsafeBytes(of: sizeSpec.littleEndian) { Data($0) }
        
        callMPSSE(command: command, arguments: sizePrologue + data)
    }
    
    public func write(bits: Int, ofDatum: UInt8, during window: DataWindow, bitOrder: BitOrder = .msb) {
        guard bits > 0 else {
            fatalError("write must send minimum of one bit")
        }

        let command: MpsseCommand
        // FIXME: it might be possible to make this table from raw values and the semantics in Table 3.2?
        switch bitOrder {
        case .msb:
            switch window {
            case .risingEdge:
                command = .writeBitsPveMsb
            case .fallingEdge:
                command = .writeBitsNveMsb
            case .highClock:
                command = .writeBitsNveMsb  // not obvious from documentation; see AN 113 2.3.1 Definitions and Functions for examples
            }
        case .lsb:
            switch window {
            case .risingEdge:
                command = .writeBitsPveLsb
            case .fallingEdge:
                command = .writeBitsNveLsb
            case .highClock:
                command = .writeBitsNveLsb  // not obvious from documentation
            }
        }

        let sizeSpec = UInt8(bits - 1)
        
        callMPSSE(command: command, arguments: Data([sizeSpec, ofDatum]))
    }
    
    
    // Warning: semantics of reading LSB format seem slightly strange: bits are populated from MSB and shifted on each entry. May require shift 8-bits to place into low bits.
    public func read(bits: Int, during window: DataWindow, bitOrder: BitOrder = .msb) -> UInt8 {
        guard bits > 0 else {
            fatalError("write must send minimum of one bit")
        }

        let command: MpsseCommand
        // FIXME: it might be possible to make this table from raw values and the semantics in Table 3.2?
        switch bitOrder {
        case .msb:
            switch window {
            case .risingEdge:
                command = .readBitsPveMsb
            case .fallingEdge:
                command = .readBitsNveMsb
            case .highClock:
                command = .readBitsPveMsb  // not obvious from documentation; see AN 113 2.3.1 Definitions and Functions for examples
            }
        case .lsb:
            switch window {
            case .risingEdge:
                command = .readBitsPveLsb
            case .fallingEdge:
                command = .readBitsNveLsb
            case .highClock:
                command = .readBitsPveLsb  // not obvious from documentation; see AN 113 2.3.1 Definitions and Functions for examples
            }
        }

        let sizeSpec = UInt8(bits - 1)
        
        callMPSSE(command: command, arguments: Data([sizeSpec]))
        // FIXME: read result
        fatalError("read of MPSSEE result not implemented")
    }
    
    enum GpioBlock {
        // lots of commands operate on either the high byte pins or the low byte
        // pins.
        
        // 3.6
        case highBytes // ACBUS 7-0
        case lowBytes  // ADBUS 7-0
        
        // By encoding the parallel semantics of opCodes, we can reduce the number of
        // specialized implementations of functions. Because the compiler will enforce
        // case coverage, it reminds us to keep these opCode maps complete.
        func cmdSetBits() -> MpsseCommand {
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
        let cmd = pins.cmdSetBits()
        let pinSpec = Data([values, outputMask])
        callMPSSE(command: cmd, arguments: pinSpec)
    }

    /// Allow output pins to float on '1' (to be pulled up by bus or sunk down by other devices)
    ///
    /// lowMask: bit field for pins; 1 = float on 'high'; 0 = actively pull high on 'high'
    /// highMask: bit field for pins;1 = float on 'high'; 0 = actively pull high on 'high'
    ///
    /// AN 108 7.1 Set I/O to only drive on a ‘0’ and tristate on a ‘1’
    func setTristate(lowMask: UInt8, highMask: UInt8) {
        let pinSpec = Data([lowMask, highMask])
        callMPSSE(command: .onlyDriveZero, arguments: pinSpec)
    }

    
}
