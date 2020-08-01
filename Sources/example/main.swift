//
//  main.swift
//
//
//  Created by Kit Transue on 2020-07-31.
//

import Foundation
import LibUSB

FtdiSPI.initializeUSBLibrary()
defer {
    FtdiSPI.closeUSBLibrary()
}

let bus = try! FtdiSPI(speedHz: 10_000_000)
let data = Data(repeating: 0xff, count: 10)
bus.write(data: data, count: data.count)
