import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(libusb_swiftTests.allTests),
    ]
}
#endif
