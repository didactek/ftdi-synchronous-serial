//
//  FtdiI2C.swift
//
//
//  Created by Kit Transue on 2020-08-10.
//  Copyright © 2020 Kit Transue
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation
import Logging
import LibUSB

private var logger = Logger(label: "com.didactek.ftdi-synchronous-serial.ftdi-i2c")

/// Use an FTDI FT232H to communicate with devices using I2C.
///
/// # References
/// - [UM10204: I2C-bus specification and user manual](https://www.nxp.com/docs/en/user-guide/UM10204.pdf)
/// - [AN_135 FTDI MPSSE Basics Version 1.1](https://www.ftdichip.com/Support/Documents/AppNotes/AN_135_MPSSE_Basics.pdf)
/// - [AN_108 Command Processor for MPSSE and MCU Host Bus Emulation Modes](https://www.ftdichip.com/Support/Documents/AppNotes/AN_108_Command_Processor_for_MPSSE_and_MCU_Host_Bus_Emulation_Modes.pdf)
/// - [Interfacing FT2232H Hi-Speed Devices to I2C Bus](https://www.ftdichip.com/Support/Documents/AppNotes/AN_113_FTDI_Hi_Speed_USB_To_I2C_Example.pdf)
/// - [I²C at Wikipedia](https://en.wikipedia.org/wiki/I²C)
public class FtdiI2C: Ftdi {
    let mode: I2CModeSpec

    /// - Parameter overrideClockHz: Frequency at which to drive the bus; if not supplied, default to maxium for the mode.
    public init(ftdiAdapter: USBDevice, overrideClockHz: Int? = nil) throws {
        logger.logLevel = .trace
        self.mode = .fast
        try super.init(ftdiAdapter: ftdiAdapter)

        // I2C wires may be asserted low by any device on the bus.
        // Notably this is used when reading data (resting state of dataOut
        // should not interfere with read) and for clock stretching (clock
        // may be held low by a device that is not ready to respond).
        setTristate(lowMask: SerialPins.outputs.rawValue, highMask: 0)

        var clockSpeed = mode.maxClockSpeed
        if let overrideClockHz = overrideClockHz {
            clockSpeed = min(mode.maxClockSpeed, overrideClockHz)
        }
        configureClocking(frequencyHz: clockSpeed, forThreePhase: true)

        queueI2CBus(state: .idle)
        flushCommandQueue()
    }

    /// The FT232H doesn't support clock stretching. See notes for `Ftdi.enableAdaptiveClock`.
    ///
    /// A possible workaround while wriring might be to connect the clock to a GPIO input pin and then:
    /// 1. Set the data line to the deisred output bit
    /// 1. clockWaitOnLow, which will attempt to clock but only return when the bus has allowed the clock
    /// 1. clock out the remaining 7 bits
    ///
    /// Something simiilar could be done for read?
    /// This makes lots of assumptions about when the clock stretching might happen.
    public func supportsClockStretching() -> Bool {
        return false
    }

    //========================
    // Physical bus managment
    //========================

    /// UM10204, Chapter 6: signal timing requirements at various bus speeds. Table 10 defines wait periods for different modes.
    ///
    /// This is inteded to provide delay sufficient to meet "hold for start of clock" (tHD;STA), "setup time for repeated start"
    /// (tSU;STA), and *half* the time for "time between a STOP and a START" (tBUF).
    // FIXME: 600ns is typical of Fast-mode, yet loop was modeled after FTDI exmaple that was supposedly Standard-mode. Encode Table 10 and use the right delay!
    func holdDelay( pinCmd: () -> Void ) {
        // loop count suggested in AN 113
        // goal of loop is to hold pins for 600ns
        // FIXME: confirm this is effective?
        // FIXME: could more accurate timing be achieved using "clock for N cycles" to get the timing right, but with the clock output disabled? (This would mean it could only float high, unless another pin was used to sink it low?) Why isn't there an operation for this? (If pulling low with another pin, output need not be disabled because tristate.)
        // FIXME: might an alternate way of doing this invovle inverting the clock output and clocking? The required dwell times are the same as the clock timing (unsurprisingly)
        switch mode {
        case .fast:  // 600ns
            for _ in 0 ..< 4 {
                pinCmd()
            }
        }
    }

    /// Schedule setting the I2C output pins on the command queue.
    ///
    /// - Parameter state: Desired pin states.
    /// - Note: This function does not provide any delay required to hold the lines for a clock cycle or
    /// stabilization period. If needed, timing steps should be added by callers, as by the idle prologue in
    /// sendStart and again(?!) by the idle epilogue in sendStop.
    func queueI2CBus(state: I2CBusState) {
        // FIXME: if other pins are used for GPIO, avoid changing them....
        var floatingPins = SerialPins()
        if state.sda == .float {
            floatingPins.insert(.dataOut)
        }
        if state.scl == .float {
            floatingPins.insert(.clock)
        }

        queueDataBits(values: floatingPins.rawValue,
                      outputMask: SerialPins.outputs.rawValue,
                      pins: .lowBytes)
    }

    /// Signal the start of communications on a bus.
    ///
    /// Indicate start condition by pulling SDA from high to low while the clock remains high,
    /// then bring both low, signifying a reserved and ready bus.
    /// - Note:[UM10204: 3.1.4:](https://www.nxp.com/docs/en/user-guide/UM10204.pdf)
    func sendStart() {
        holdDelay {
            queueI2CBus(state: .idle)
        }
        holdDelay {
            queueI2CBus(state: I2CBusState(sda: .zero, scl: .float))  // "reserveOrRelease"
        }
        queueI2CBus(state: I2CBusState(sda: .zero, scl: .zero))  // FIXME: .clockLow might be both functionally equivalent and more clear?
        flushCommandQueue()
        logger.trace("START condition set")
    }

    /// Signal the end of communications on a bus.
    ///
    /// Indicate stop condition by bringing SDA high when clock is high.
    /// (Pins will remain high until a new conversation is started.)
    /// - Note:[UM10204: 3.1.4:](https://www.nxp.com/docs/en/user-guide/UM10204.pdf)
    func sendStop() {
        holdDelay {
            queueI2CBus(state: I2CBusState(sda: .zero, scl: .float))
        }
        holdDelay {
            queueI2CBus(state: .idle)
        }
        flushCommandQueue()
        logger.debug("STOP condition set")
    }

    /// Schedule write of a byte and a check of its ACK bit into the command queue.
    ///
    /// - Note: the ACK check is a callback on the read of the ACK bit.
    ///  If a NACK is detected, execution ends with a fatalError.
    /// - Note:[UM10204, 3.1.5 Byte Format](https://www.nxp.com/docs/en/user-guide/UM10204.pdf)
    /// - Precondition: bus is in ready state (clock low)
    func writeByteReadAck(byte: UInt8) {
        // UM10204, 3.1.3 Data Validity
        // The data on the SDA line must be stable during the HIGH period of the clock.
        // AN 135, 5.4 Serial Communications
        // has oscilloscope example of 0x10: byte out using MSB/rising
        // By starting to set SDA with the clock low, SDA is stable when the clock goes high,
        // thus fulfilling the spec.
        logger.trace("Queuing write 0x\(String(byte, radix: 16))")
        writeWithClock(bits: 8, ofDatum: byte, during: .highClock)
        queueI2CBus(state: .clockLow) // FIXME: why? isn't clock low & SDA released?

        let _ = readWithClock(bits: 1, during: .highClock,
                              promiseCallback: { ackBit in
                                guard ackBit[0] == 0 else {
                                    // FIXME: throw is better for dynamic errors
                                    fatalError("failed to get ACK writing byte")
                                }
                                logger.trace("ACK of write 0x\(String(byte, radix: 16)) accepted")
                              })
        queueI2CBus(state: .clockLow)  // FIXME: why? clock cycle should return clock to low?
    }

    /// Schedule read of a byte on the bus and ACK time slot response into the command queue.
    ///
    /// - Parameter last: if false, then this function will ACK the byte receipt
    /// and the node will send another byte during the next clock cycle.
    /// If last is true, this function will NACK (not acknowledge) on the bus, and the
    /// node will end its writing state and look for the next command.
    /// - Note:[UM10204, 3.1.6 Acknowledge (ACK) and Not Acknowledge (NACK)](https://www.nxp.com/docs/en/user-guide/UM10204.pdf)
    func readByte(last: Bool = false) -> CommandResponsePromise {
        enum Acknowledgment: UInt8 {
            /// pull SDA low
            case ack = 0
            /// let SDA float high
            case nack = 0xff // FIXME: use 0b1 or 0b1000_0000 depending on which bit gets sent

        }
        let response: Acknowledgment = last ? .nack : .ack

        let promisedResponse = readWithClock(bits: 8, during: .highClock) { byteIn in
            let hex = String(byteIn[0], radix: 16)
            let plannedAck = last ? "NACK" : "ACK"
            logger.trace("Read byte 0x\(hex); planned response is \(plannedAck)")
        }
        writeWithClock(bits: 1, ofDatum: response.rawValue, during: .highClock)

        holdDelay {  // FIXME: this seems spurious given the clocked write of the (n)ack.
            queueI2CBus(state: .clockLow)
        }

        return promisedResponse
    }

    //========================
    // Logical layer
    //========================

    /// Bit 0 of the control byte; indicates direction of subsequent bytes.
    /// - Note:[UM10204 3.1.10: R/W̅ bit](https://www.nxp.com/docs/en/user-guide/UM10204.pdf)
    enum RWIndicator: UInt8 {
        case read = 0x01
        case write = 0x00
    }

    /// Create an I2C control byte.
    /// - Parameter address: address of the node that should respond to this conversation.
    /// - Parameter direction: write: data is sent from the initiating adapter;
    /// read: responding node sends data during the clock provided by the initiator.
    func makeControlByte(address: UInt8, direction: RWIndicator) -> UInt8 {
        guard address < 0x80 else {
            fatalError("address out of range")
        }
        // FIXME: would a structure be better for debug logging? And more clear at write site?
        return address << 1 | direction.rawValue
    }

    /// Write bytes without sending a 'stop'.
    /// - Parameter address: the node to which the data will be sent.
    /// - Parameter data: bytes to send to the node.
    func write(address: UInt8, data: Data) {
        logger.debug("writing \(data.count) bytes")
        sendStart()
        let controlByte = makeControlByte(address: address, direction: .write)
        writeByteReadAck(byte: controlByte)
        for byte in data {
            writeByteReadAck(byte: byte)
        }
        flushCommandQueue()
        logger.trace("done writing \(data.count) bytes")
    }

    /// Read bytes without sending a 'stop'.
    /// - Parameter address: the node from which data should be read.
    /// - Parameter count: the number of bytes to read.
    func read(address: UInt8, count: Int) -> Data {
        guard count > 0 else {
            fatalError("read request must be for at least one byte")
        }
        logger.debug("reading \(count) bytes")
        sendStart()
        let controlByte = makeControlByte(address: address, direction: .read)
        writeByteReadAck(byte: controlByte)

        var promises: [CommandResponsePromise] = []
        for _ in 0 ..< (count - 1) {
            promises.append(readByte())
        }
        promises.append(readByte(last: true))

        flushCommandQueue()
        let bytes = promises.map {$0.value[0]}
        logger.trace("done reading \(count) bytes")
        return Data(bytes)
    }
}
