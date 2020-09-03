# libusb-swift

A lean stack written primarily in Swift for using the FTDI FT232H USB-to-serial adapter in I2C and SPI applications.

Requirements:
- Swift Package Manager
- Swift 5.2+
- macOS or Linux
- for FTDI serial devices: an FT232H connected via USB

Mac requirements
- brew (for SPM to install libraries)
- pkg-config (from brew, for SPM to locate and validate installed libraries)
- Xcode 11.6+ suggested


SPM Dependencies
- swift-log

C library dependencies
- libusb

Goals:
- make installation and use as easy as possible
- minimize additions to the user's environment
- use usermode drivers
- avoid components that require root access to install or configure
- use Swift as much as possible
- aspire to code that is readable and idiomatic




