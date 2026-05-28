# Reactor Bike Light
Reactor Bike Light is a real-time embedded lighting system for bicycles built on a multicore microcontroller architecture. The system uses IMU-based motion estimation and sensor fusion to detect braking, turning, and crash events, communicating them through adaptive LED behavior and BLE connectivity. The device supports three modes: tail light mode uses red illumination, head light mode uses white, and the unique ground light mode projects dynamic color patterns onto the ground around the bicycle.

### Technical Highlights
  + Multicore real-time embedded architecture
  + IMU-based motion estimation with sensor fusion
  + Finite state machines for motion-reactive lighting control
  + BLE communications with CRC-validated firmware updates
---
## Architecture
<img width="1387" height="715" alt="reactor_Block_Diagram" src="https://github.com/user-attachments/assets/181189e6-4c52-4d8e-ba44-052b4c1bbbd0" />

#
### Overview
The embedded system operates separate cores for sensor acquisition, motion processing, main control, BLE communication, and LED control. These modules exchange data through buffers stored in main memory. Access to shared resources is synchronized using hardware locks to prevent concurrent access conflicts.

### Sensors
The sensor core acquires data from three sensor arrays. Battery voltage is measured on the accumulator of a sigma-delta ADC circuit. User input is detected by timing the activation of touch sensors on the sides of the device. Acceleration, angular velocity, and temperature measurements are acquired over I2C from an IMU.

### DMP
The motion processing core applies digital filtering and sensor fusion to combine the accelerometer and gyroscope data into an estimate of sensor orientation. This estimate is transformed into the bicycle's frame of reference and combined with the filtered IMU measurements to calculate orientation, acceleration, and turn-rate in rider space.

### Main
The main control core feeds the motion estimate, user input, battery voltage, and device temperature into a set of finite state machines responsible for motion detection, touch state, power management, and lighting behavior. The main core also manages system startup and persistent load/save operations.

### LED
The LED rendering core drives the left and right LED arrays according to motion detection state, operation mode, brightness settings, and strobe configuration.

### BLE
The BLE control core manages UART communications between the main control core and the external BLE radio module. Incoming packets from the mobile app are verified with CRC before being applied to user settings or firmware updates. Motion events and local setting changes are encoded and transmitted through BLE characteristics to synchronize the connected app.

### App
The Reactor mobile app provides centralized configuration and monitoring for multiple connected devices mounted to the bicycle. Users can activate turn signals and warning flashers through touch or voice control, monitor battery voltage and device temperature, and automatically notify selected contacts with GPS location data when a crash is detected. Firmware updates are transferred wirelessly through the app and verified before installation.

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
## Validation & Debugging
  + GPIO timing instrumentation
  + Stack usage analysis
  + Fault injection testing
  + Runtime debugger logging
  + Oscilloscope and DMM verification
---
