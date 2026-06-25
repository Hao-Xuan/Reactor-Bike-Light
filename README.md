# Reactor Bike Light

## The Engineering Question
Every bicycle already produces a rich stream of information about what its rider is doing. Slowing down, leaning into a turn, stopping, accelerating, or falling over are all natural motions of riding. Most bicycle lights ignore this information entirely and instead rely on the rider to manually issue commands through buttons or remotes. Reactor began with a simple engineering question:

**Can the natural motions of riding a bicycle serve as the controller for its lighting system?**

If the answer is yes, then many user interactions could disappear. The rider could spend less time operating the light and more time simply riding the bicycle. As the project evolved, the rest of the design began to organize itself around a simple principle: infer rider intent whenever it can be done reliably, and keep deliberate commands simple whenever it cannot. Answering that question ultimately required more than a brake light or a turn signal. It required a complete lighting system capable of observing the ride, interpreting what it meant, and coordinating multiple forms of visual communication around the bicycle.

The result is Reactor.

## The System

A Reactor unit can operate in one of three roles relevant to rider visibility and awareness: a white head light to illuminate forward, a red tail light to illuminate rearward, or a programmable ground light to illuminate downard. Multiple units can be combined to create a complete lighting system distributed around the bicycle.

Because these lights work together to communicate rider intent, they must also share behavior. The Reactor mobile application coordinates configuration, monitoring, and control across multiple lights, allowing the rider to interact with the system as a whole rather than managing individual devices. The sections that follow describe the hardware, firmware, and mobile application that make this possible.

## The Hardware

Reactor's hardware was developed as a complete embedded product, with electronics, mechanical packaging, power management, sensing, rider input, and mounting designed together to create a compact, durable, and easy-to-use bicycle lighting system. The hardware is responsible for both observing the ride and providing a simple, predictable interface for the actions that only the rider can decide.

The resulting hardware combines a multicore microcontroller, inertial measurement sensors, touch controls, wireless communication, rechargeable battery power, high-power LED control, and a purpose-built enclosure into a single self-contained device. The sections that follow document the electrical, mechanical, and manufacturing decisions that transformed Reactor from an idea into a working product.

## The Firmware

The firmware is responsible for transforming raw sensor measurements into lighting behavior. Motion data from the bicycle is filtered, interpreted, and evaluated in real time to determine what the rider is doing and how the lighting system should respond. This is where Reactor's central design principle is implemented: infer rider intent whenever it can be done reliably, and defer to rider input when it cannot.

To support this behavior, the firmware combines sensor processing, state machines, LED control, touch input handling, wireless communication, and system coordination into a deterministic real-time control system. The sections that follow document the architecture, timing decisions, control logic, and engineering tradeoffs that allow Reactor to remain responsive and predictable while balancing reliability, computational cost, and real-time performance.

## The Mobile App

While routine interactions are designed to occur directly on the bicycle, some tasks are more naturally performed through a mobile device. The Reactor mobile application serves as the coordination and control layer for multiple Reactor units, allowing them to behave as a unified lighting system. The sections that follow document the communication architecture, user interface design, and engineering decisions behind the mobile application.

## The Past and The Future


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
