// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ftdi-synchronous-serial",
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .executable(
            name: "example",
            targets: ["example"]),
        .library(
            name: "FTDI",
            targets: ["FTDI"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/didactek/deft-simple-usb", "0.0.1" ..< "0.1.0"),
        .package(url: "https://github.com/didactek/deft-log.git", from: "0.0.1"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "example",
            dependencies: ["FTDI"]),
        .target(
            name: "FTDI",
            dependencies: [
                .product(name: "DeftLog", package: "deft-log"),
                .product(name: "PortableUSB", package: "deft-simple-usb"),
            ]),
        .testTarget(
            name: "ftdi-synchronous-serialTests",
            dependencies: [.product(name: "SimpleUSB", package: "deft-simple-usb")]),
    ]
)
