#!/bin/bash

# Find the bus that the 0403 (FTDI) device is on:
BUS=$(sudo cat /sys/kernel/debug/usb/devices |\
       	grep --before-context=2 Vendor=0403 |\
       	grep Bus |\
	sed 's/.*Bus=0*\([0-9][0-9]*\).*/\1/' )


# Unload the Linux drivers for the FTDI (if they've been loaded)
# These are loaded dynamically, so have no long-term side-effects
sudo rmmod ftdi_sio
sudo rmmod usbserial

# Load the USB monitor:
sudo modprobe usbmon

# Start logging the bus:
sudo cat /sys/kernel/debug/usb/usbmon/${BUS}u > usb-bus.log &

# Do the work
./probe

# Stop logging
kill %1

echo "Control transfers are:"
grep Co: usb-bus.log
