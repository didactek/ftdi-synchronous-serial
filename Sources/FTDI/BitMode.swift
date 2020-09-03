//
//  BitMode.swift
//
//
//  Created by Kit Transue on 2020-09-03.
//  Copyright © 2020 Kit Transue
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation

/// FTDI Bit Mode: major operational modes of the FTDI family of devices.
///
/// - Note:[Reference] D2XX Programmer's Guide, 5.3
enum BitMode: UInt16 {
    /// Reset.
    case reset = 0x00

    #if false
    /// Multi-bit data bus with timing support; read and write happen in same clock phase;
    /// direction defined by operation; typically used with R(-)W(+) pin?
    /// - Important: Unsupported.
    // - Note:[Reference] AN232BM-01  FT232BM/FT245BM BIT BANG MODE
    case asynchronousBitbang = 0x01
    #endif

    /// Multi-Purpose Synchronous Serial Engine mode: hardware timing support for data and clock.
    case mpsse = 0x02

    #if false
    /// Parallel data bus with timing support; read and write occur during different clock phases?
    /// - Important: Unsupported.
    // - Note:[Reference] AN232BM-01  FT232BM/FT245BM BIT BANG MODE
    case synchronousBitbang = 0x04

    /// MCU 8048/8051 emulation mode.
    /// - Important: Unsupported.
    /// - Note:[Reference] AN_108 Command Processor for MPSSE and MCU Host Bus Emulation Modes
    /// - Note:[Reference]https://en.wikipedia.org/wiki/Intel_MCS-51
    case mcu = 0x08

    /// Fast serial mode; suggested application with hardware opto-isolators.
    /// - Important: Unsupported.
    /// - Note:[Reference] AN_108: 4.9: Fast Serial Interface Mode Description
    case fastSerial = 0x10

    /// 4-bit wide bus on CBUS pins.
    /// - Important: Unsupported.
    /// - Important: Requires EEPROM change to enable.
    /// - Note:[Reference]FIXME
    case cbus = 0x20

    /// Single Channel Synchronous 245 FIFO mode.
    /// - Important: Unsupported.
    /// - Note:[Reference] DS_FT232H: 4.4 FT245 Synchronous FIFO Interface Mode Description
    case singleChannelSynchronous = 0x40
    #endif
}
