//
//  main.swift
//
//
//  Created by Kit Transue on 2020-07-31.
//  Copyright © 2020 Kit Transue
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation
import LibUSB
import FTDI

do { // use a block to trigger de-inits at the end of the block scope.
    let usbSubsystem = USBBus()
    let ftdiDevice = try usbSubsystem
        .findDevice(idVendor: Ftdi.defaultIdVendor,
                    idProduct: Ftdi.defaultIdProduct)

    // Choose only one of the following demos: the adapter can be used in only
    // one mode at a time.

    //    demoSpiLed(ftdiAdapter: ftdiDevice)
    //    demoI2CRadio(ftdiDevice: ftdiDevice)
    demoGPIO(ftdiAdapter: ftdiDevice)
}
