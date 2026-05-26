# Reactor Bike Light
The Reactor Bike Light is a sensor-driven embedded lighting system for bicycles that uses real-time motion estimates to control a pair of LED arrays. The system detects motion such as braking, turning, and crashing and automatically communicates those motions to nearby traffic using the familiar light signals. The device may be operated in three modes: tail light mode is red, head light mode is white, and the unique ground light mode creates a splash of jewel-tone color on the ground around the bicycle. A companion mobile app expands the user interface and enhances the safety features of the system.

---
## Architecture
<img width="1390" height="733" alt="reactor_Block_Diagram" src="https://github.com/user-attachments/assets/680843c3-795f-4f19-ab16-61f0f2a79f4a" />


### Overview
The embedded system is implemented on a multicore microcontroller operating separate cores for sensor acquisition, motion processing, main control, BLE communication, and LED control. These modules share data via buffers stored in the microcontroller's main RAM. Access to the buffers is restricted by hardware locks to ensure that data is transferred with no collisions.
#
### Sensors
The sensor core acquires data from three sensor arrays. Battery voltage is measured on the accumulator of a sigma-delta ADC circuit. User input is detected by timing the activation of touch sensors on the sides of the device. Acceleration, angular velocity, and temperature measurements are acquired over I2C from an IMU.
#
### DMP
The motion processing core applies digital filtering and sensor fusion to combine the accelerometer and gyroscope data into an estimate of the spatial orientation of the IMU sensor. This estimate is rotated into the bicycle's frame of reference and recombined with the raw data to produce a real-time estimate of the bicycle's orientation, acceleration, and turn-rate in the rider's space.
#
### Main
The main control core feeds the motion estimate, user input, battery voltage, and device temperature to a set of finite state machines that perform the system's motion detection, touch state, power management, and LED control functions. The main core is also responsible for system startup and load/save operations.
#
### LED
The LED rendering core programs a left/right pair of LED arrays according to its operation mode, motion detection, and settings for strobe and brightness.
#
### BLE
The BLE control core manages serial communications between main control and the external BLE radio module over UART. Data packets are received from the linked mobile app and verified by CRC before being used to control user settings and update firmware. Motion reactions and local changes to user settings are encoded and written to the BLE characteristics to notify the app.
#
### App
The Reactor mobile app provides a convenient plaform for the user to manage and synchronize the settings of multiple connected devices mounted to the bicycle. Users can select turn signals and warning flashers by touch or voice control, monitor battery voltage and device temperature, and automatically notify selected phone contacts with GPS location data when a crash is detected. The user may download firmware updates from the app to the device, where they are verified before being installed.

---
## Engineering Challenges
  + Real-time responsiveness constraints
  + Sensor noise and filtering
  + Long-term reliability
  + BLE data integrity

---
## Key Design Decisions
  +
---
## Test & Debug Methods
  +
---
## Future Improvements
  +
---
