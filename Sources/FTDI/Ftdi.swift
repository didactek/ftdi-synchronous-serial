//
//  Ftdi.swift
//
//
//  Created by Kit Transue on 2020-08-01.
//  Copyright © 2020 Kit Transue
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation
import Logging
import LibUSB

var logger = Logger(label: "com.didactek.ftdi-synchronous-serial.ftdi-core")



/// Represent an FTDI FT232H operating in MPSSE mode, connected to host via USB.
///
/// The FT232H has 16 general purpose I/O pins (GPIO) that can be configured for input or output.
/// It also has an onboard clock and associated built-in logic (the "Multi-Purpose Synchronous Serial Engine",
/// or MPSSE) that uses three pins (clock, dataIn, and dataOut) for clocked serial communications.
///
/// In serial clocking mode, the remaining pins can be used for GPIO.
/// Protocols that require "chip select" or other signals can be implemented by assigning any of the remaining
/// pins for these functions and managing the pin state explicitly.
public class Ftdi {
    public static let defaultIdVendor = 0x0403
    public static let defaultIdProduct = 0x6014

    let device: USBDevice

    var commandQueue = Data()
    var expectedResultCounts: [CommandResponsePromise] = []

    struct SerialPins: OptionSet {
        let rawValue: UInt8

        static let clock   = SerialPins(rawValue: 1 << 0)
        static let dataOut = SerialPins(rawValue: 1 << 1)
        static let dataIn  = SerialPins(rawValue: 1 << 2)

        static let outputs: SerialPins = [.clock, .dataOut]
        static let inputs: SerialPins = [.dataIn]
    }

    init(ftdiAdapter: USBDevice) throws {
        self.device = ftdiAdapter
        logger.logLevel = .trace

        // AN_135_MPSSE_Basics lifetime: 4.1 Confirm device existence and open file handle
        configurePorts()
        confirmMPSSEModeEnabled()
    }

    deinit {
        endMPSSE()
    }

    /// AN_135_MPSSE_Basics lifetime: 4.2 Configure FTDI Port For MPSSE Use
    func configurePorts() {
        // Reset peripheral side
        //  rx buf purged
        //  bitmode: RESET
        // FIXME: this is not a FT_ResetDevice, but a MPSSE controller reset, which is different
        setBitmode(.reset)
        // Configure USB transfer sizes
        // Set event/error characters
        // Set timeouts
        // Set latency timer
        setLatency(mSec: 16)
        // Set flow control
        // Reset MPSSE controller  //FIXME: different from "reset peripheral side", and if so: should these be different calls?
        //  bitmode: RESET
        setBitmode(.reset)
        //  rx buf purged
        // Enable MPSSE controller
        //  bitmode: MPSSE
        setBitmode(.mpsse, outputPinMask: SerialPins.outputs.rawValue)
    }


    /// AN_135_MPSSE_Basics lifetime: Reset MPSSE and close port:
    func endMPSSE() {
        // Reset MPSSE
        setBitmode(.reset)
        // Close handles/resources
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
        /// Change LSB GPIO output
        case setBitsLow = 0x80
        /// Change MSB GPIO output
        case setBitsHigh = 0x82
        /// Get LSB GPIO output
        case getBitsLow = 0x81
        /// Get MSB GPIO output
        case getBitsHigh = 0x83

        // 3.7 Loopback
        /// Enable loopback
        case loopbackStart = 0x84
        /// Disable loopback
        case loopbackEnd = 0x85

        // 3.8 Clock
        /// Set TCK/SK divisor
        case setTCKDivisor = 0x86
        // 6 FT232H, FT2232H & FT4232H only
        /// Enable 60 MHz clock transitions (30MHz cycle)
        case disableClockDivide5 = 0x8a
        /// Enable 12 MHz clock transitions (6MHz cycle)
        case enableClockDivide5 = 0x8b
        /// Enable 3-phase data clocking (I2C)
        case enableClock3Phase = 0x8c
        /// Disable 3-phase data clocking
        case disableClock3Phase = 0x8d
        /// Clock for n+1 cycles with no data transfer (JTAG)
        case clockBitsNoData = 0x8e
        /// Clock for 8*(n+1) cycles with no data transfer
        case clockBytesNoData = 0x8f
        /// Clock until GPIOL1 goes low **
        case clockWaitOnHigh = 0x94
        /// Clock until GPIOL1 goes high **
        case clockWaitOnLow = 0x95
        /// Gate clock on RTCK read from GPIOL3 (ARM/JTAG)
        case enableAdaptiveClocking = 0x96
        /// Disable adaptive clocking
        case disableAdaptiveClocking = 0x97
        /// Clock until GPIOL1 is high or 8*(n+1) cycles
        case clockWaitOnHighTimeout = 0x9c
        /// Clock until GPIOL1 is low or 8*(n+1) cycles
        case clockWaitOnLowTimeout = 0x9d

        // 5 Instruction release/flow control

        // 5.1 Send Immediate
        /// Flush; request immediate response
        case sendImmediate = 0x87

        // 7.1 Drive on '0'; Tristate on '1'
        /// Set output pins to float on '1' (I2C)
        case onlyDriveZero = 0x9e

        /// per AN_135; should provoke "0xFA Bad Command" error
        case bogus = 0xab

        // ** documentation is unclear or inconsistent in its description
    }



    private func callMPSSE(command: MpsseCommand, arguments: Data) {
        let cmd = Data([command.rawValue]) + arguments
        device.bulkTransferOut(msg: cmd)
    }

    private func callMPSSE(command: MpsseCommand) {
        let cmd = Data([command.rawValue])
        device.bulkTransferOut(msg: cmd)
    }


    private func queueMPSSE(command: MpsseCommand, arguments: Data, expectingReplyCount: Int, promiseCallback: ((Data)->Void)? = nil) -> CommandResponsePromise {
        commandQueue.append(command.rawValue)
        commandQueue.append(arguments)

        let promise = CommandResponsePromise(ofCount: expectingReplyCount, onFulfill: promiseCallback)
        expectedResultCounts.append(promise)
        return promise
    }

    private func queueMPSSE(command: MpsseCommand, arguments: Data) {
        let _ = queueMPSSE(command: command, arguments: arguments, expectingReplyCount: 0)
    }

    func pretty(_ data: Data) -> String {
        let maxLength = 10
        return data.prefix(maxLength).map { "0x" + String($0, radix: 16)}.joined(separator: " ") + (data.count > maxLength ? "..." : "")
    }

    /// Send all enqueued commands and attempt to fulfill associated promises.
    func flushCommandQueue() {
        queueMPSSE(command: .sendImmediate, arguments: Data())
        logger.trace("bulk transfer writing \(pretty(commandQueue))")
        device.bulkTransferOut(msg: commandQueue)
        commandQueue.removeAll()

        var retries = 7  // FIXME: "7" was chosen at random
        var beingAssembled = Data()

        while !expectedResultCounts.isEmpty && retries > 0 {
            let newBytesRead = device.bulkTransferIn()
            logger.trace("bulk transfer read \(pretty(newBytesRead))")
            retries -= 1
            guard newBytesRead.prefix(1) == Data([0x32]) else {
                fatalError("unfamiliar modem status in response: \(pretty(newBytesRead))")
            }
            guard newBytesRead.count >= 2 else {
                fatalError("expected at least one byte to follow modem status")
            }
            if newBytesRead[1] != 0x60 {
                logger.debug("unusual modem status \(newBytesRead[1])")
            }

            if newBytesRead.count > 2 {
                beingAssembled.append(Data(newBytesRead.advanced(by: 2)))
            }

            while let needed = expectedResultCounts.first, needed.expectedCount <= beingAssembled.count {
                needed.fulfill(value: Data(beingAssembled.prefix(needed.expectedCount))) // FIXME: Xcode 11.6 / Swift 5.2.4: explicit constructor is needed to avoid crash in Data subrange if just use value!! This seems like a bug????
                let _ = expectedResultCounts.removeFirst()
                beingAssembled.removeFirst(needed.expectedCount)
            }
        }
        guard expectedResultCounts.isEmpty else {
            fatalError("failed to collect all expected replies; remaining: \(expectedResultCounts)")
        }
        guard beingAssembled.isEmpty else {
            fatalError("failed to consume all replies; outstanding: \(pretty(beingAssembled))")
        }
    }

    /// Assert we are in MPSSE mode.
    ///
    /// Sends a command that provides a positive response but does not change configuration
    /// or exchange data.
    /// Calls fatalError if MPSSE mode appears not to be set.
    func confirmMPSSEModeEnabled() {
        // per AN_135; should provoke "0xFA Bad Command" response
        let bogusReply = queueMPSSE(command: .bogus, arguments: Data(), expectingReplyCount: 2)
        flushCommandQueue()

        guard bogusReply.value == Data([0xfa, MpsseCommand.bogus.rawValue]) else {
            fatalError("expected \"bad opcode\" in \(pretty(bogusReply.value))")
        }
    }

    /// Set the clock output frequency. Set up 3-phase clocking if requested.
    ///
    /// frequencyHz is the desired full cycle rate on the clock pin.
    ///
    /// This sets up an internal clock that triggers each pin change managed by the
    /// data clocking logic. To drive a simple square wave, two triggers are needed per cycle:
    /// one for each XOR of the clock.
    ///
    /// For the three-phase clock, three state changes are required,
    /// so the effective frequency on the clocked pin is 1/3 the frequency
    /// of the internal operations.
    ///
    /// Note: Configuring the clock does not immediately affect the clock pin; the clock pin is automatically
    /// cycled only during data clocking commands.
    func configureClocking(frequencyHz: Int, forThreePhase: Bool = false) {
        let timedActionsPerCycle = forThreePhase ? 3 : 2

        // AN 135 5.3.2 suggests explicitly setting even default values:
        disableAdaptiveClock()  // default
        if forThreePhase {
            enableThreePhaseClock()
        } else {
            disableThreePhaseClock()  // default
        }

        // FIXME: only low speed implemented currently
        // FIXME: explicitly enabling/disabling divide-by-5 is recommended.
        let internalClock = 12_000_000

        /// AN 135 3.2.1
        let divisor = internalClock / (timedActionsPerCycle * frequencyHz) - 1

        let divisorSetting = UInt16(clamping: divisor)
        let divisorLE = withUnsafeBytes(of: divisorSetting.littleEndian) {Data($0)}

        callMPSSE(command: .setTCKDivisor, arguments: divisorLE)
    }

    func disableAdaptiveClock() {
        callMPSSE(command: .disableAdaptiveClocking)
    }

    /// Sustain data through a clock high or low phase instead of during a transition.
    ///
    /// Behavior of the "3-phase" clock: set up data for 1/3 cycle; change
    /// clock for 1/3 cycle; return clock to starting for 1/3 cycle.
    /// Full cycle takes three triggers of the internal clock used for state transitions, so
    /// the setClock frequency needs to be adjusted appropriately.
    func enableThreePhaseClock() {
        callMPSSE(command: .enableClock3Phase)
    }

    /// Use a 2-phase clock.
    ///
    /// On a 2-phase write, the clock is immediate XOr'd, then the value of dataOut is set. The first half
    /// of the clock cycle is counted out (one phase), then the clock is XOr'd. Then the second half of
    /// the cycle is counted out, with the data being kept valid across the phase change and through
    /// the completion of the clock cycle.
    func disableThreePhaseClock() {
        callMPSSE(command: .disableClock3Phase)
    }


    enum BitOrder {
        /// most-significant bit first
        case msb
        /// least-significant bit first
        case lsb
    }


    /// Write bytes in coordination with changing  the clock.
    ///
    /// Put one bit per clock cycle onto the dataOut pin, while operating the clock at its configured frequency.
    ///
    /// Data is guaranteed valid  during the specified window: It is set up ahead of time and
    /// maintained until the window has closed. See enableThreePhaseClock
    /// for semantics of a .clockHigh window.
    ///
    /// The clock pin is not immediately set by this function on entry, but instead must already be
    /// at the appropriate value for the starting phase. The clock will be XORd twice, so it will end in the same state it started.
    func writeWithClock(data: Data, during window: DataWindow, bitOrder: BitOrder = .msb) {
        guard data.count > 0 else {
            fatalError("write must send minimum of one byte")
        }

        let command: MpsseCommand

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

        queueMPSSE(command: command, arguments: sizePrologue + data)
    }

    /// Write of 1-8 bits in coordination with changing  the clock. Command is queued.
    ///
    /// When command queue is flushed: put one bit per clock cycle onto the dataOut pin
    /// while operating the clock at its configured frequency.
    ///
    /// Data is guaranteed valid  during the specified window: It is set up ahead of time and
    /// maintained until the window has closed. See enableThreePhaseClock
    /// for semantics of a .clockHigh window.
    ///
    /// The clock pin is not immediately set by this function on entry, but instead must already be
    /// at the appropriate value for the starting phase. The clock will be XORd twice, so it will end in the same state it started.
    func writeWithClock(bits: Int, ofDatum: UInt8, during window: DataWindow, bitOrder: BitOrder = .msb) {
        guard bits > 0 else {
            fatalError("write must send minimum of one bit")
        }

        let command: MpsseCommand

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

        queueMPSSE(command: command, arguments: Data([sizeSpec, ofDatum]))
    }


    /// Cycle the clock 1-8 times, reading bits during the specificed clock phase. Command is queued.
    ///
    /// Returns: promise of read data that will be fullfilled when flushCommandQueue assembles results.
    ///
    /// If provided, the callback is attached to the promise, allowing things
    /// like checking ACK to be performed while the response is being decoded.
    ///
    /// Warning: semantics of reading LSB format seem slightly strange: bits are populated from MSB
    /// and shifted on each entry. May require shift of (8 minus 'bits') to place into low bits.
    func readWithClock(bits: Int, during window: DataWindow, bitOrder: BitOrder = .msb, promiseCallback: ((Data)->Void)? = nil) -> CommandResponsePromise {
        guard bits > 0 else {
            fatalError("write must send minimum of one bit")
        }

        let command: MpsseCommand

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

        return queueMPSSE(command: command, arguments: Data([sizeSpec]), expectingReplyCount: 1, promiseCallback: promiseCallback)
    }

    enum GpioBlock {
        // lots of commands operate on either the high byte pins or the low byte
        // pins.

        // 3.6
        /// ACBUS 7-0
        case highBytes
        /// ADBUS 7-0
        case lowBytes

        // By encoding the parallel semantics of opCodes, we can reduce the number of
        // specialized implementations of functions. Because the compiler will enforce
        // case coverage, it reminds us to keep these opCode maps complete.
        /// Opcode to use to set bits for this block.
        func cmdSetBits() -> MpsseCommand {
            switch self {
            case .highBytes:
                return .setBitsHigh
            case .lowBytes:
                return .setBitsLow
            }
        }
    }

    /// Define pins as input or output.
    ///
    /// - Parameter value:desired levels on output pins
    /// - Parameter outputMask: bitwise indicator of pin use; 1 marks pin as an output
    /// - Parameter pins: high or low block of pins to configure
    func queueDataBits(values: UInt8, outputMask: UInt8, pins: GpioBlock) {
        let cmd = pins.cmdSetBits()
        let pinSpec = Data([values, outputMask])
        queueMPSSE(command: cmd, arguments: pinSpec)
    }

    /// Allow output pins to float on '1' (to be pulled up by bus or sunk down by other devices)
    ///
    /// - Parameter lowMask: bit field for pins; 1 = float on 'high'; 0 = actively pull high on 'high'
    /// - Parameter highMask: bit field for pins;1 = float on 'high'; 0 = actively pull high on 'high'
    ///
    /// Note:[Reference] AN 108 7.1 Set I/O to only drive on a ‘0’ and tristate on a ‘1’
    func setTristate(lowMask: UInt8, highMask: UInt8) {
        let pinSpec = Data([lowMask, highMask])
        callMPSSE(command: .onlyDriveZero, arguments: pinSpec)
    }
}
