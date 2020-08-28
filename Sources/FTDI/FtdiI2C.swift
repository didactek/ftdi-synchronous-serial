//
//  FtdiI2C.swift
//  
//
//  Created by Kit Transue on 2020-08-10.
//

import Foundation


// references:
// https://en.wikipedia.org/wiki/I²C
// AN_135 FTDI MPSSE Basics Version 1.1
// AN_108 Command Processor for MPSSE and MCU Host Bus Emulation Modes
// https://www.ftdichip.com/Support/Documents/AppNotes/AN_113_FTDI_Hi_Speed_USB_To_I2C_Example.pdf
// UM10204: I2C-bus specification and user manual
// https://www.nxp.com/docs/en/user-guide/UM10204.pdf


public class FtdiI2C: Ftdi {
    enum Mode {
        #if false  // unsupported
        /// 100 kbps
        case standard
        #endif
        /// 400 kbps
        case fast
        #if false  // unsupported
        /// 1 Mbps
        case fastPlus
        /// 3.4 Mbps
        case highSpeed
        /// 5 Mbps
        case ultraFast
        /// 1.4 Mbps
        case turbo  // not in spec, but per Wikipedia
        #endif
        
        func clockSpeed() -> Int {
            switch self {
                #if false
            case .standard:
                return 100_000
                #endif
            case .fast:
                return 400_000
            }
        }
    }
    
    let mode: Mode
    
    public override init() throws {
        self.mode = .fast
        try super.init()
        
        configureMPSSEForI2C()
        
        queueI2CBus(state: .idle)
        flushCommandQueue()
    }
    
    
    func configureMPSSEForI2C() {
        // I2C wires may be asserted low by any device on the bus.
        // Notably this is used when reading data (resting state of dataOut
        // should not interfere with read) and for clock stretching (clock
        // may be held low by a device that is not ready to respond).
        setTristate(lowMask: SerialPins.outputs.rawValue, highMask: 0)

        configureClocking(frequencyHz: mode.clockSpeed(), forThreePhase: true)
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
    
    enum TristateOutput {
        case float  // let the bus float; normally biased high, but may be sunk to zero by another device
        case zero  // pull down to zero
    }
    
    /// Set the I2C output pins to specified values
    ///
    /// This function does not provide any delay required to hold the lines
    /// for a clock cycle or stabilization period. If needed, timing should be provided by callers, as by the idle prologue in
    /// sendStart and again(?!) by the idle epilogue in sendStop.
    func queueI2CBus(sda: TristateOutput, clock: TristateOutput) {
        // FIXME: if other pins are used for GPIO, avoid changing them....
        var floatingPins = SerialPins()
        if sda == .float {
            floatingPins.insert(.dataOut)
        }
        if clock == .float {
            floatingPins.insert(.clock)
        }
        
        queueDataBits(values: floatingPins.rawValue,
                    outputMask: SerialPins.outputs.rawValue,
                    pins: .lowBytes)
    }
    
    struct BusState {
        let sda: TristateOutput
        let clock: TristateOutput
    }

    enum NamedBusState {
        case idle
        case clockLow
        
        var values: BusState {
            switch(self) {
            /// UM10204, 3.1.1: SDA and CLK high -> bus is free.
            case .idle:  // unclaimed, idle
                return BusState(sda: .float, clock: .float)
            /// Hold the clock low; neutral state between operations
            case .clockLow:  // clockLow, ready
                return BusState(sda: .float, clock: .zero)
            }
        }
    }
    
    // Set the bus to a standard state.
    func queueI2CBus(state: NamedBusState) {
        let pins = state.values
        queueI2CBus(sda: pins.sda, clock: pins.clock)
    }
    
    
    /// Signal the start of communications on a bus.
    ///
    /// UM10204: 3.1.4: a start condition is indicated by SDA going from high
    /// to low while the clock remains high. Both are then brought low, ready for the first command byte.
    func sendStart() {
        holdDelay {
            queueI2CBus(state: .idle)
        }
        holdDelay {
            queueI2CBus(sda: .zero, clock: .float)  // "reserveOrRelease"
        }
        queueI2CBus(sda: .zero, clock: .zero)  // FIXME: .clockLow might be both functionally equivalent and more clear?
        flushCommandQueue()
    }
    
    /// Signal the end of communications on a bus.
    ///
    /// UM10204: 3.1.4: stop is indicated when SDA goes high when clock is high.
    /// (Pins will remain high until a new conversation is started.)
    func sendStop() {
        holdDelay {
            queueI2CBus(sda: .zero, clock: .float)
        }
        holdDelay {
            queueI2CBus(state: .idle)
        }
        flushCommandQueue()
    }
    
    /// Write a byte and check its ACK
    ///
    /// See UM10204, 3.1.5 Byte Format
    func writeByteReadAck(byte: UInt8) {
        // bus is in ready state (clock low)

        // UM10204, 3.1.3 Data Validity
        // The data on the SDA line must be stable during the HIGH period of the clock.
        // AN 135, 5.4 Serial Communications
        // has oscilloscope example of 0x10: byte out using MSB/rising
        // By starting to set SDA with the clock low, SDA is stable when the clock goes high,
        // thus fulfilling the spec.
        writeWithClock(bits: 8, ofDatum: byte, during: .highClock)
        queueI2CBus(state: .clockLow) // FIXME: why? isn't clock low & SDA released?
        
        let _ = readWithClock(bits: 1, during: .highClock, promiseCallback:
        { ackBit in
            guard ackBit[0] == 0 else {
                // FIXME: throw is better for dynamic errors
                fatalError("failed to get ACK writing byte")
            }
        })
        queueI2CBus(state: .clockLow)  // FIXME: why? clock cycle should return clock to low?
    }
    
    /// Read a byte on the bus and respond in ACK time slot.
    ///
    /// If last is not set, then this function will ACK the byte receipt
    /// and the node will send another byte during the next clock cycle.
    /// If last is true, this function will NACK (not acknowledge) on the bus, and the
    /// node will end its writing state and look for the next command.
    /// UM10204: 3.1.6
    func readByte(last: Bool = false) -> UInt8 {
        enum Acknowledgment: UInt8 {
            case ack = 0  // pull SDA low
            // FIXME: use 0b1 or 0b1000_0000 depending on which bit gets sent:
            case nack = 0xff // let SDA float high
        }
        let response: Acknowledgment = last ? .nack : .ack

        let promisedResponse = readWithClock(bits: 8, during: .highClock)
        writeWithClock(bits: 1, ofDatum: response.rawValue, during: .highClock)

        holdDelay {  // FIXME: this seems spurious given the clocked write of the (n)ack.
            queueI2CBus(state: .clockLow)
        }

        flushCommandQueue()
        return promisedResponse.value[0]
    }

    //========================
    // Logical layer
    //========================

    enum RWIndicator: UInt8 {
        case read = 0x01
        case write = 0x00
    }
    
    func makeControlByte(address: UInt8, direction: RWIndicator) -> UInt8 {
        guard address < 0x80 else {
            fatalError("address out of range")
        }
        return address << 1 | direction.rawValue
    }

    /// Write bytes without sending a 'stop'
    func write(address: UInt8, data: Data) {
        sendStart()
        let controlByte = makeControlByte(address: address, direction: .write)
        let segment = Data([controlByte]) + data
        for byte in segment {
            writeByteReadAck(byte: byte)
        }
    }
    
    func read(address: UInt8, count: Int) -> Data {
        guard count > 0 else {
            fatalError("read request must be for at least one byte")
        }
        sendStart()
        let controlByte = makeControlByte(address: address, direction: .read)
        writeByteReadAck(byte: controlByte)
        
        var data = Data()
        for _ in 0 ..< (count - 1) {
            data.append(readByte())
        }
        data.append(readByte(last: true))

        return data
    }
}
