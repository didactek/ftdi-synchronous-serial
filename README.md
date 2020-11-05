# ftdi-synchronous-serial

FIXME: rename to "ftdi-sync-serial"?
FIXME: watch for, minimize, or bridge jargon

A lean stack written primarily in Swift for using the FTDI FT232H USB-to-serial adapter in I2C,
SPI, and GPIO applications, built on the portable C-library [libusb](https://libusb.info).


## Overview

This library provides
- support for a USB-connected FTDI device in MPSSE mode
- implementations of I2C and SPI protocols
- a small Swift bridge to libusb sufficient to support the above

Synchronous serial communication is data that is timed according to a separate clock
signal. While the FTDI also supports asynchronous [UART] communications (such as RS-232),
the operating system likely provides support for this mode through one of the /dev/cu*serial* 
special devices.


## Requirements

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


## Goals

- make installation and use as easy as possible
- minimize additions to the user's environment
- use usermode drivers
- avoid components that require root access to install or configure
- use Swift as much as possible
- aspire to code that is readable and idiomatic


## Installation Notes

### Linux device permissions

On Linux, users will not have access to a hot-plugged FTDI device by default. 
The cleanest way to systematically grant permissions to the device is to set up a udev
rule that adjusts permissions whenever the device is connected.

The paths and group in the template below assume:
- Configuration files are under /etc/udev/rules.d
- The group 'plugdev' exists and includes the user wanting to use the device

Under /etc/udev/rules.d/, create a file (suggested name: "70-gpio-ftdi-ft232h.rules") with the contents:

    # FTDI FT232H USB -> GPIO + serial adapter
    # 2020-09-07 support working with the FT232H using Swift ftdi-synchronous-serial library
    ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6014", MODE="660", GROUP="plugdev"

eLinux.org has a useful wiki entry on [accessing devices without sudo](https://elinux.org/Accessing_Devices_without_Sudo).




