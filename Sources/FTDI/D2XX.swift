//
//  D2XX.swift
//  
//  FTDI D2XX-like configuration functions ported from PyFtdi.
//  https://eblot.github.io/pyftdi/
//
//  Copyright (C) 2010-2020 Emmanuel Blot <emmanuel.blot@free.fr>
//  Copyright (c) 2016 Emmanuel Bouaziz <ebouaziz@free.fr>
//  All rights reserved.
//
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//      * Redistributions of source code must retain the above copyright
//        notice, this list of conditions and the following disclaimer.
//      * Redistributions in binary form must reproduce the above copyright
//        notice, this list of conditions and the following disclaimer in the
//        documentation and/or other materials provided with the distribution.
//      * Neither the name of the Neotion nor the names of its contributors may
//        be used to endorse or promote products derived from this software
//        without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//  ARE DISCLAIMED. IN NO EVENT SHALL NEOTION BE LIABLE FOR ANY DIRECT, INDIRECT,
//  INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
//  LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA,
//  OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
//  LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
//  NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
//  EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import Foundation


extension Ftdi {
    enum BRequestType: UInt8 {
        case reset = 0x0  // Reset the port
        case setModemControl = 0x1  // Set the modem control register
        case setFlowControl = 0x2  // Set flow control register
        case setBaudrate = 0x3  // Set baud rate
        case setData = 0x4  // Set the data characteristics of the port
        case getModemStatus = 0x5  // Get line status
        case setEventChar = 0x6  // Change event character
        case setErrorChar = 0x7  // Change error character
        case setLatencyTimer = 0x9  // Change latency timer
        case getLatencyTimer = 0xa  // Get latency timer
        case setBitmode = 0xb  // Change bit mode
        case getBitmode = 0xc  // Read GPIO pin configuration
    }

    // FIXME: not provided by ftdi and possibly needed:
    // getQueueStatus
    // resetPort

    func setLatency(mSec: UInt16) {
        controlTransferOut(bRequest: .setLatencyTimer, value: mSec, data: Data())
    }
    
    func setBitmode(_ mode: BitMode, outputPinMask: UInt8 = 0) {
        let value = mode.rawValue << 8 | UInt16(outputPinMask)
        controlTransferOut(bRequest: .setBitmode, value: value, data: nil)
    }
    

    // type-safe bridge to device
    func controlTransferOut(bRequest: BRequestType, value: UInt16, data: Data?) {
        // FIXME: Is it possible to confirm wIndex semantics?
        // My guess is that it's the endpoint (should use "UInt16(device.writeEndpoint)")
        // but ftdi.py just uses "1".
        device.controlTransferOut(bRequest: bRequest.rawValue, value: value, wIndex: 1, data: data)
    }
}
