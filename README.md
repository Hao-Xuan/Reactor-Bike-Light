# Reactor Bike Light
Overview of Project Design and Implementation
#
# Description
The Reactor Bike Light is a sensor-driven embedded lighting system for bicycles that uses real-time motion estimates to control a pair of LED arrays. The system detects motion such as braking, turning, and crashing and automatically communicates those motions to nearby traffic with familiar light signals. The device may be operated in three modes: tail light mode is red, head light mode is white, and the unique ground light mode creates a splash of changing jewel-tone color on the ground around the bicycle. A companion mobile app may be used to enhance an
#
# Architecture
The system is implemented on a multicore microcontroller operating separate cores for sensor acquisition, motion processing, main control, BLE communication, and LED control. These modules share data via buffers stored in the microcontroller's main RAM. Access to the buffers is restricted by hardware locks to ensure that data is transferred with no collisions.
<img width="1100" height="788" alt="reactor_Block_Diagram" src="https://github.com/user-attachments/assets/f92d6e2b-eab3-49f4-85e4-88b5445915d5" />
#
The sensor core acquires data from three sensor arrays. Battery voltage is measured by timing the input of a sigma-delta analog-to-digial conversion. User input is detected by timing the activation of touch sensors on the left and right sides of the device. Acceleration, angular velocity, and temperature measurements are acquired over I2C from an IMU.
#
The motion processing core applies digital filtering and sensor fusion to combine the accelerometer and gyroscope data into a low-noise estimate of the IMU sensor's orientation in space. This estimate is rotated into the bicycle's frame of reference and recombined with the raw data to produce a real-time estimate of the bicycle's orientation, acceleration, and turn-rate vectors in the rider's space.
#
The main control core performs the system startup, load/save, and user input operations. Motion state, user touch, battery voltage, and device temperature data drive a set of finite state machines that perform the system's motion detection and power management functions. These states are converted into commands and RGB codes that determine LED behavior.
#
The LED rendering core decodes its commands to actuate a left/right pair of LED arrays according to its operation mode, motion detection, and settings for strobe and brightness.
#
The BLE control core manages UART communications between main control and the onboard external BLE radio module. Data packets are received from the linked mobile app and verified by CRC before being used to control user settings and update firmware. Motion reactions and local changes to user settings are encoded and written to the BLE characteristics to notify the app.
#
The Reactor mobile app provides a convenient plaform for the user to manage and synchronize the settings of multiple connected devices mounted to the bicycle. Users can select turn signals and warning flashers by touch or voice control, monitor battery voltage and system temperature, and automatically notify selected phone contacts with GPS location data upon the detection of a crash.
