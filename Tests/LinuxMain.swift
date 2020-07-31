import XCTest

import libusb_swiftTests

var tests = [XCTestCaseEntry]()
tests += libusb_swiftTests.allTests()
XCTMain(tests)
