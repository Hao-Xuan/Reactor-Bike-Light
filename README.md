# Reactor Bike Light
Reactor Bike Light is a real-time embedded lighting system for bicycles built on a multicore microcontroller architecture. The system uses IMU-based motion estimation and sensor fusion to detect braking, turning, and crash events and communicate them through adaptive LED behavior and BLE connectivity.
The device may be operated in three modes: tail light mode is red, head light mode is white, and the unique ground light mode creates a splash of color on the ground around the bicycle.

### Technical Highlights
  + Multicore real-time embedded architecture
  + IMU-based motion estimation with sensor fusion
  + Finite state machines determine light reactions from motion
  + BLE communications with CRC-validated firmware updates
---
## Architecture
<img width="1382" height="710" alt="reactor_Block_Diagram" src="https://github.com/user-attachments/assets/53963840-a915-4f46-a7e2-8597dd7e6fc2" />

#
### Overview
The embedded system operates separate cores for sensor acquisition, motion processing, main control, BLE communication, and LED control. These modules share data via buffers stored in the microcontroller's main RAM. Access to the buffers is restricted by hardware locks to ensure that data is transferred with no collisions.
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
The Reactor mobile app provides a convenient platform for the user to manage and synchronize the settings of multiple connected devices mounted to the bicycle. Users can select turn signals and warning flashers by touch or voice control, monitor battery voltage and device temperature, and automatically notify selected phone contacts with GPS location data when a crash is detected. The user may download firmware updates from the app to the device, where they are verified before being installed.

---
## Engineering Challenges

### Real-time responsiveness constraints
One of the primary engineering challenges was implementing a motion estimation pipeline that produced stable orientation estimates while remaining responsive enough for real-time lighting control. I evaluated both Kalman and complementary filtering approaches and ultimately selected a complementary filter due to its significantly lower computational cost. Extensive tuning and testing were required to balance responsiveness, stability, and noise rejection under real-world riding conditions.

### Real-world motion validation
Developing reliable motion detection required both controlled testing and real-world validation. A desktop test rig was used to compare estimated orientation against known pitch and roll angles under quasi-static conditions, while live ride logging was used to tune filtering and motion thresholds during actual operation. These tests helped improve the reliability of braking, turning, and crash detection behaviors.

### Timing and synchronization
Maintaining consistent real-time behavior required careful attention to timing and synchronization across multiple interacting subsystems. Firmware execution was instrumented using GPIO timing traces and runtime logging to identify bottlenecks, synchronization issues, and long-duration timing failures. Several issues related to counter rollover and inter-core coordination were identified and resolved during testing.

### BLE data integrity
The BLE communication subsystem was designed to support telemetry, user control, and firmware updates while remaining robust against interruptions and corrupted data. CRC validation and resumable transfer mechanisms were implemented to improve reliability during firmware updates. Additional buffering and verification logic were added to reduce the likelihood of communication failures during long-duration operation.

---
## Test & Debug Methods
  + Timing verification
  + Core stack usage
  + Fault injection
  + Debugger logs
  + Oscilloscope and DMM
---
