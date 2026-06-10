# Reactor Bike Light
Reactor Bike Light is a real-time embedded lighting system for bicycles built on a multicore microcontroller architecture. The system uses IMU-based motion estimation to detect braking, turning, and crash events, communicating them through adaptive LED behavior and BLE connectivity. The device supports three modes: tail light mode uses red illumination, head light mode uses white, and the unique ground light mode projects dynamic color patterns onto the ground around the bicycle.

### Technical Highlights
  + Multicore real-time embedded architecture
  + IMU-based motion estimation with sensor fusion
  + Finite state machines for motion-reactive lighting control
  + BLE communications with CRC-validated firmware updates
---
## Architecture
<img width="1387" height="715" alt="reactor_architecture" src="https://github.com/user-attachments/assets/2a8e6289-25fc-4531-a36a-915c486eec51" />

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
## Debugging & Validation

Development emphasized measurement-driven debugging and systematic verification throughout the hardware and firmware stack.

- GPIO instrumentation and oscilloscope analysis for execution-time measurement and latency characterization
- Verification of custom communication protocols using oscilloscope and logic analyzer measurements
- Long-duration reliability testing to identify rollover, synchronization, and state-machine failures
- Structured telemetry and event logging for root-cause analysis of intermittent faults
- Incremental integration testing of sensing, processing, communication, and rendering subsystems
- Validation of motion-estimation algorithms using controlled test conditions
- Power profiling and optimization for battery-operated deployment
- Firmware-update fault injection and recovery testing
- End-to-end verification of timing, communication, and data integrity requirements

Some examples are shown below.

### Synchronization of sensor acquisition and motion processing pipeline

Critical inter-core communication paths were instrumented using GPIO markers and verified on hardware with an oscilloscope. The traces below validate both synchronization between processing stages and the latency of data transfer between Sensor and DMP cores.

#### Figure 1 - Validation of synchronized data handoff between sensor and DMP cores
<img width="982" height="555" alt="validation_ipc_synchronization" src="https://github.com/user-attachments/assets/6932a127-fd3c-4026-a6a7-9449c2137f9f" />

(1) Sensor acquisition cycle begins, (2) new IMU sample committed to shared memory, (3) DMP core consumes new sample, (4) updated motion estimate committed to shared memory

#### Figure 2 - Inter-core data transfer latency
<img width="982" height="555" alt="validation_ipc_latency" src="https://github.com/user-attachments/assets/ad37efea-af8c-4bf4-ae77-b05aada6f5f8" />

(1) Sensor core commits new IMU sample to shared memory, (2) DMP core copies new sample approximately 200 us later

### Custom I2C implementation

Because the Propeller P8X32A lacks a dedicated I2C peripheral, a bare-metal driver was implemented in Propeller assembly (PASM). Oscilloscope captures were used to verify protocol timing and reliable data transfer.

#### Figure 3 - Validation of assembly-language I2C driver
<img width="982" height="555" alt="validation_i2c_protocol" src="https://github.com/user-attachments/assets/00555a53-0b94-462f-89ff-8dc0341a7f55" />

(1) START condition generated, (2) address and acknowledgement phase begins, (3) data transfer begins 

### Physical layer

The bike light design required custom electronic and mechanical hardware, all of which was designed together using standard schematic capture, PCB layout, 3D modeling, and simulation techniques. Several design iterations resulted in a compact and reliable prototype suitable for real-world use.

#### Figure 4 - Physical prototype
<img width="1164" height="951" alt="reactor_physical" src="https://github.com/user-attachments/assets/8b68d90d-0faf-4ba7-8091-087c0641ac89" />

Completed enclosure, populated control PCB, and illuminated prototype hardware. The system integrates custom electronics, multicore firmware, BLE communications, IMU sensing, and motion-reactive LED control into a battery-powered bicycle lighting platform.

---
