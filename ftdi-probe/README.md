# FTDI-Probe

*Important:* This is documentation that supports the extensions in FtdiConfiguration.swift.
Nothing in this directory is needed to build or use the FTDI library.

Catalog USB control transfer operations performed by FTDI's D2XX library to change the
operation of the FT232H serial controller.

## Rationale

To use the chip for functions beyond standard serial mode (which is supported automatically
by both Linux and macOS), it is necessary to change the operating mode of the FT232H.
The steps required to change modes seem not to be documented; FTDI offers encapsulates
the mode changes through its D2XX API. I have resorted to monitoring this library to 
understand mode changes.

Most of the specifications required to use the FT232H is provided by FTDI  in their
[Documents](https://www.ftdichip.com/Support/FTDocuments.htm) repository. The
documentation fully covers MPSSE functions that are heavily used in this library, and is
referenced in this codebase where applicable. It is much easier and clearer to use FTDI's
documentation where it exists.

## Implementation

The probe uses Linux's [usbmon](https://www.kernel.org/doc/Documentation/usb/usbmon.txt) 
kernel probe to capture the operations on the USB interface.

## Application

The sample program (probe.c) links against the FTDI D2XX library. The sample makes calls
to the library operations that are essential for using the chip but that cannot be implemented
using the chip documentation.

## Usage

The included Makefile contains commands for obtaining the library from FTDI, compiling and
linking the sample, and running the shell script that collects the sample. The run-probe.sh
script has several sudo commands that should be audited. None are intended to have
lasting effects on a system: the library is used locally; the sudo commands are needed to
transiently unload competing drivers when the chip is connected, and to gain permissions to
monitor the USB interface.
