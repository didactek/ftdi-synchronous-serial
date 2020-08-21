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

// FIXME: buffer commands and send as a group
public class FtdiI2C: Ftdi {
    struct I2CHardwarePins: OptionSet {
        let rawValue: UInt8
        
        static let clock   = I2CHardwarePins(rawValue: 1 << 0)
        // the chip is wired so dataOut and dataIn pins are tied togther to form SDA: dataOut is used to pull the bus down or to let it float; data is read on the dataIn pin
        static let dataOut = I2CHardwarePins(rawValue: 1 << 1)
        static let dataIn  = I2CHardwarePins(rawValue: 1 << 2)
        // if one needs clock stretching, a pin should be allocated to watch for the bus pausing the clock signal
        // GPIOl0 might be used for Write Protect
        
        static let outputs: I2CHardwarePins = [.clock, .dataOut]
        static let inputs: I2CHardwarePins = [.dataIn]
        static let tristate: I2CHardwarePins = [.clock, .dataOut]
    }
    
    enum Mode {
        case standard // 100 kbps
        #if false  // unsupported
        case fast // 400 kbps
        case fastPlus // 1 Mbps
        case highSpeed // 3.4 Mbps
        case ultraFast // 5 Mbps
        case turbo // 1.4 Mbps  // Wikipedia
        #endif
        
        func clockSpeed() -> Int {
            switch self {
            case .standard:
                return 100_000
            }
        }
    }
    
    public override init() throws {
        try super.init()
        
        configurePorts()
        confirmMPSSEModeEnabled()
        configureMPSSEForI2C(mode: .standard)
        
        setI2CBus(state: .idle)
    }
    
    deinit {
        endMPSSE()
    }
    
    func configurePorts() {
        // Reset peripheral side
        //  rx buf purged
        //  bitmode: RESET
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
        setBitmode(.mpsse, outputPinMask: I2CHardwarePins.outputs.rawValue)
    }
    
    
    func configureMPSSEForI2C(mode: Mode) {
        // Output pins were set when MPSSE was enabled

        // I2C wires may be asserted by any device on the bus:
        setTristate(lowMask: I2CHardwarePins.tristate.rawValue, highMask: 0)

        // Clock
        disableAdaptiveClock()
        setClock(frequencyHz: mode.clockSpeed(), forThreePhase: true)
        enableThreePhaseClock()
    }
    
    //========================
    // Physical bus managment
    //========================

    /// UM10204, Chapter 6: signal timing requirements at various bus speeds. Table 10 defines wait periods for different modes.
    // FIXME: 600ns is typical of Fast-mode, yet loop was modeled after FTDI exmaple that was supposedly Standard-mode. Encode Table 10 and use the right delay!
    func hold600ns( pinCmd: () -> Void ) {
        // loop count suggested in AN 113
        // goal of loop is to hold pins for 600ns
        // FIXME: confirm this is effective?
        for _ in 0 ..< 4 {
            pinCmd()
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
    func setI2CBus(sda: TristateOutput, clock: TristateOutput) {
        // FIXME: if other pins are used for GPIO, avoid changing them....
        var floatingPins = I2CHardwarePins()
        if sda == .float {
            floatingPins.insert(.dataOut)
        }
        if clock == .float {
            floatingPins.insert(.clock)
        }
        
        setDataBits(values: floatingPins.rawValue,
                    outputMask: I2CHardwarePins.outputs.rawValue,
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
    func setI2CBus(state: NamedBusState) {
        let pins = state.values
        setI2CBus(sda: pins.sda, clock: pins.clock)
    }
    
    
    /// Signal the start of communications on a bus.
    ///
    /// UM10204: 3.1.4: a start condition is indicated by SDA going from high
    /// to low while the clock remains high. Both are then brought low, ready for the first command byte.
    func sendStart() {
        hold600ns {
            setI2CBus(state: .idle)
        }
        hold600ns {
            setI2CBus(sda: .zero, clock: .float)  // "reserveOrRelease"
        }
        setI2CBus(sda: .zero, clock: .zero)  // FIXME: .clockLow might be both functionally equivalent and more clear?
    }
    
    /// Signal the end of communications on a bus.
    ///
    /// UM10204: 3.1.4: stop is indicated when SDA goes high when clock is high.
    /// (Pins will remain high until a new conversation is started.)
    func sendStop() {
        hold600ns {
            setI2CBus(sda: .zero, clock: .float)
        }
        hold600ns {
            setI2CBus(state: .idle)
        }
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
        write(bits: 8, ofDatum: byte, during: .highClock)
        setI2CBus(state: .clockLow) // FIXME: why? isn't clock low & SDA released?
        let ack = read(bits: 1, during: .highClock)
        // FIXME: sendImmediate covered by read?
        guard ack == 0 else {
            // FIXME: throw is better for dynamic errors
            fatalError("failed to get ACK writing byte")
        }
        setI2CBus(state: .clockLow)  // FIXME: why? clock cycle should return clock to low?
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

        let datum = read(bits: 8, during: .highClock)
        write(bits: 1, ofDatum: response.rawValue, during: .highClock)

        hold600ns {  // FIXME: this seems spurious given the clocked write of the (n)ack.
            setI2CBus(state: .clockLow)
        }

        return datum
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
    
    func read(address: UInt8, count: Int) -> Data{
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
