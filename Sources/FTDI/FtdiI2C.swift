//
//  FtdiI2C.swift
//  
//
//  Created by Kit Transue on 2020-08-10.
//

import Foundation

#if true // I think I2C might be a lot of work...

// references:
// https://en.wikipedia.org/wiki/I²C
// AN_135 FTDI MPSSE Basics Version 1.1
// AN_108 Command Processor for MPSSE and MCU Host Bus Emulation Modes
// https://www.ftdichip.com/Support/Documents/AppNotes/AN_113_FTDI_Hi_Speed_USB_To_I2C_Example.pdf


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
        setClock(frequencyHz: mode.clockSpeed())
        enableThreePhaseClock()

        let bitsHighAtStart: I2CHardwarePins = [.clock, .dataOut]
        setDataBits(values: bitsHighAtStart.rawValue,
                    outputMask: I2CHardwarePins.outputs.rawValue,
                    pins: .lowBytes)
        
        
        fatalError("not implemented")
    }
    
    func sendStart() {
        let startHold: I2CHardwarePins = [.clock, .dataOut]
        let startSetup: I2CHardwarePins = [.clock]
        let startBegin: I2CHardwarePins = []

        // loop count suggested in AN 113
        // goal of loop is to hold pins for 600ns
        // FIXME: confirm that there's a basis for this?
        for _ in 0 ..< 4 {
            setDataBits(values: startHold.rawValue,
                        outputMask: I2CHardwarePins.outputs.rawValue,
                        pins: .lowBytes)
        }
        for _ in 0 ..< 4 {
            setDataBits(values: startSetup.rawValue,
                        outputMask: I2CHardwarePins.outputs.rawValue,
                        pins: .lowBytes)
        }
        setDataBits(values: startBegin.rawValue,
                    outputMask: I2CHardwarePins.outputs.rawValue,
                    pins: .lowBytes)
    }
    
    func sendStop() {
        let stop1: I2CHardwarePins = [.clock]
        let stop2: I2CHardwarePins = [.clock, .dataOut]

        
        for _ in 0 ..< 4 {  // goal of loop is to hold pins for 600ns
            setDataBits(values: stop1.rawValue,
                        outputMask: I2CHardwarePins.outputs.rawValue,
                        pins: .lowBytes)
        }
        for _ in 0 ..< 4 {
            setDataBits(values: stop2.rawValue,
                        outputMask: I2CHardwarePins.outputs.rawValue,
                        pins: .lowBytes)
        }

        // example sets tristate, but I don't understand the need
    }
    
    // clock out 8 bits; read in 1
    // FIXME: do we return the bit read?
    func writeByteReadAck(byte: UInt8) {
        fatalError("not implemented")
    }

    /// Write bytes without sending a 'stop'
    func write(address: Int, data: Data) {
        // FIXME: should this include a 'start' as a matter of practice?
        // first byte: address + indication of 'write'
        // then: length
        // then: data
        fatalError("not implemented")
    }

    #if false
    public func write(data: Data, count: Int) {
        let writtenCount = data.withUnsafeBytes() { ptr in
            systemWrite(fileDescriptor, ptr.baseAddress, count)
        }
        assert(writtenCount == count)
    }
    
    public func read(data: inout Data, count: Int) {
        let receivedCount = data.withUnsafeMutableBytes() { ptr in
            systemRead(fileDescriptor, ptr.baseAddress, count)
        }
        assert(receivedCount == count)
    }
    
    public func writeAndRead(sendFrom: Data, sendCount: Int, receiveInto: inout Data, receiveCount: Int) {
        var sendCopy = sendFrom  // won't be written to, but ioctl signature allows writing, and having semantics dependent on flags makes this hard to prove. Use a copy so the compiler is rightfully happy about safety.
        sendCopy.withUnsafeMutableBytes { sendRaw in
            receiveInto.withUnsafeMutableBytes { recvRaw in
                let sendBuffer = sendRaw.bindMemory(to: __u8.self)
                let sendMsg = i2c_msg(
                    addr: __u16(nodeAddress),
                    flags: __u16(0),   // write is the default (no flags set)
                    len: __u16(sendCount),
                    buf: sendBuffer.baseAddress)
                
                let recvBuffer = recvRaw.bindMemory(to: __u8.self)
                let recvMsg = i2c_msg(
                    addr: __u16(nodeAddress),
                    flags: __u16(I2C_M_RD),
                    len: __u16(receiveCount),
                    buf: recvBuffer.baseAddress)

                var conversation = [sendMsg, recvMsg]
                conversation.withUnsafeMutableBufferPointer { messages in
                    var callInfo = i2c_rdwr_ioctl_data(msgs: messages.baseAddress, nmsgs: __u32(messages.count))
                    let receivedCount = ioctl(fileDescriptor, UInt(I2C_RDWR), &callInfo)
                    assert(receivedCount == receiveCount)
                }
            }
        }
    }
    #endif
    // FIXME: implement write
    // FIXME: implement read
    // FIXME: implement exchange?
    // FIXME: implement stop
}
#endif
