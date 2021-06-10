//
//  main.swift
//
//
//  Created by Kit Transue on 2020-07-31.
//  Copyright © 2020 Kit Transue
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation
import DeftLog
import PortableUSB
import FTDI

do { // use a block to trigger de-inits at the end of the block scope.
    DeftLog.settings = [
        ("com.didactek.ftdi-synchronous-serial", .trace),
        ("com.didactek", .debug),
    ]

    let usbSubsystem = PortableUSB.platformBus()
    let ftdiDevice = try! usbSubsystem
        .findDevice(idVendor: Ftdi.defaultIdVendor,
                    idProduct: Ftdi.defaultIdProduct)

    // Choose only one of the following demos: the adapter can be used in only
    // one mode at a time.

    //    demoSpiLed(ftdiAdapter: ftdiDevice)
    //    demoI2CRadio(ftdiDevice: ftdiDevice)
    demoGPIO(ftdiAdapter: ftdiDevice)
}
