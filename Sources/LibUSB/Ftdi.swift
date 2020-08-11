//
//  Ftdi.swift
//
//
//  Created by Kit Transue on 2020-08-01.
//  Copyright © 2020 Kit Transue
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation

public class Ftdi {
    let device: USBDevice


    public init() throws {
        device = try USBDevice(device: USBDevice.findDevice())
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
        case writeBytesNveMsb = 0x11
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

        // 7.1 Drive on '0'; Tristate on '1'
        case driveZero = 0x9e  // Set output pins to float on '1' (I2C)

        case bogus = 0xab  // per AN_135; should provoke "0xFA Bad Command" error

        // ** documentation is unclear or inconsistent in its description
    }



    func callMPSSE(command: MpsseCommand, arguments: Data) {
        let cmd = Data([command.rawValue]) + arguments
        device.bulkTransferOut(msg: cmd)
        checkMPSSEResult()
    }

    func checkMPSSEResult() {
        // FIXME: some commands return information (like 'getBits*')
        let resultMessage = device.bulkTransferIn()
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
        device.bulkTransferOut(msg: Data([badOpcode]))
        let resultMessage = device.bulkTransferIn()
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

    func setClock(frequencyHz: Int) {
        // FIXME: only low speed implemented currently
        let busClock = 6_000_000
        let divisor = (busClock + frequencyHz)/(2 * frequencyHz) - 1
        let divisorSetting = UInt16(clamping: divisor)

        let argument = withUnsafeBytes(of: divisorSetting) {Data($0)}

        callMPSSE(command: .setTCKDivisor, arguments: argument)
    }

    public func write(data: Data, count: Int) {
        guard count > 0 else {
            fatalError("write must send minimum of one byte")
        }
        let sizeSpec = UInt16(count - 1)
        let sizePrologue = withUnsafeBytes(of: sizeSpec.littleEndian) { Data($0) }

        callMPSSE(command: .writeBytesNveMsb, arguments: sizePrologue + data)
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
}
