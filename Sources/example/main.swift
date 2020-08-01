//
//  main.swift
//
//
//  Created by Kit Transue on 2020-07-31.
//

import Foundation
import LibUSB

let bus = try! LinuxSPI(speedHz: 10_000_000)
let data = Data(repeating: 0xff, count: 10)
bus.write(data: data, count: data.count)
