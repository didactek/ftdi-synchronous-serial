# libusb-swift
FIXME: rename to "ftdi-sync-serial"?
FIXME: watch for, minimize, or bridge jargon

A lean stack written primarily in Swift for using the FTDI FT232H USB-to-serial adapter in I2C
and SPI applications, built on the portable C-library [libusb](https://libusb.info).


## Overview


This library provides
- support for a USB-connected FTDI device in MPSSE mode
- implementations of I2C and SPI protocols
- a small Swift bridge to libusb sufficient to support the above

Synchronous serial communication is data that is timed according to a separate clock
signal. While the FTDI also supports asynchronous [UART] communications (such as RS-232),
the operating system likely provides support for this mode through one of the /dev/cu*serial* 
special devices.



## Requirements:
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

## Goals:
- make installation and use as easy as possible
- minimize additions to the user's environment
- use usermode drivers
- avoid components that require root access to install or configure
- use Swift as much as possible
- aspire to code that is readable and idiomatic




