# Device Firmware

This directory contains selected source files from the Reactor Bike Light embedded firmware. Included files represent the primary application logic and demonstrate the multicore architecture used for sensing, motion processing, control, LED rendering, and BLE communication.

Included modules:

* Main control core - reactor_Main
* Sensor acquisition core - reactor_Sensors
* Motion processing (DMP) core - reactor_DMP
* LED rendering core - reactor_LED
* BLE communication core - reactor_BLE

Third-party libraries, vendor code, debugging utilities, and non-essential support modules have been omitted for clarity. The included files are intended to demonstrate system architecture, synchronization methods, state-machine design, sensor processing, and communication protocols.
