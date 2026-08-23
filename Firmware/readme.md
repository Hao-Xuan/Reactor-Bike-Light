## Firmware Architecture
### Overview
The embedded system runs on a multi-core MCU which operates separate cores for sensor acquisition, motion processing, main control, BLE communication, and LED control. These modules exchange data through buffers stored in main memory. Access to shared resources is synchronized using hardware locks to prevent concurrent access conflicts.

<img width="1096" height="565" alt="reactor_architecture" src="https://github.com/user-attachments/assets/694fda7f-01dd-43af-bfd3-ad3f6f867c92" />

**Figure 1** - High-level firmware architecture showing concurrent execution across the Propeller's eight processing cores

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

## Implementation Highlights

This section is still under construction. Please come back later to see more highlights.

## Power Management

Reactor's main control firmware treats startup and shutdown as coordinated system-level processes rather than simply enabling or disabling individual peripherals. The same power-management logic that regulates LED output during normal operation also coordinates battery protection, thermal derating, user feedback, persistent state, and the controlled removal of power.

### Unit Initialization

A new Reactor unit begins with a newly programmed EEPROM containing the firmware and an installVerified flag indicating that the EEPROM has been installed in a new unit. The Propeller automatically boots the firmware after programming the EEPROM, so the initialization routine deliberately does not latch the main power on during this first execution. Instead, it records the installation as verified and remains in a holding loop until the touch sensors are released. This allows the development-board power to turn off after EEPROM programming without requiring a separate intervention.

On the subsequent startup from the production board, the normal power latch is established and the full initialization sequence proceeds:

```spin
'check for new installation
if (not installVerified)
  installVerified~~
  variableBackup(@installVerified,3+@installVerified)
  repeat
'latch main power
outa[powerPin]~
dira[powerPin]~~
```

The BLE control cog performs its own first-run initialization, configuring the radio, programming the Reactor characteristics, retrieving the module's unique identifier, and constructing the device serial number. The serial number is stored permanently in the BLE module's ROM, providing each Reactor with a persistent identity independent of the firmware image.

### Continuous Power Supervision

During normal operation, the Main cog continuously supervises battery voltage, temperature, user-selected brightness, and power-state commands. Battery voltage is derived from the raw ADC measurement using calibration endpoints established empirically across multiple Reactor boards. The calibrated voltage is then used both for battery indication and for low-voltage brightness derating.

User brightness is represented by brightMax, with four app-selectable levels. The actual LED command, brightLvl, retains 16 levels. Under normal conditions the four user settings map to [0, 5, 10, 15], leaving intermediate levels available for thermal regulation:

```spin
if (deciCelsius>tempMax)
  brightLvl--
else
  brightLvl++
  brightLvl<#=(5*brightMax)
```

This separation allows thermal protection to reduce brightness gradually without visibly dropping the user to the next brightness setting. Battery derating instead reduces brightMax, producing a conspicuous brightness change that provides the rider with feedback that the battery is approaching depletion.

The battery measurement itself is calibrated before being consumed by power management. The raw ADC value is shared between cogs through a locked mailbox, then converted from its calibrated ADC range into millivolts and a 0–255 battery-color index:

```spin
tempPowerLevel:=powerLevel
newPowerData:=0

milliVolts:=minVolt+delVolt*(tempPowerLevel-loVolt)/(hiVolt-loVolt)
batteryColor:=(((milliVolts-minVolt)/4)#>0)<#255
```

The loVolt and hiVolt values represent empirically averaged ADC measurements corresponding to the 3.0 V and 4.2 V battery endpoints across approximately ten Reactor PCBs. This allows the firmware to convert the raw measurement into an estimate of actual battery voltage despite variation between physical boards.

The power-management method also consumes commands produced by the touch state machine, including requests to display battery status, return to normal operation, and shut down. Commands from the BLE subsystem use an existing powerMode mailbox, with its otherwise-unused high bit carrying the application shutdown request:

```spin
if ((powerMode>>31)==1)
  powerMode&=$7FFF_FFFF
  powerStatus:=$FFFF_FFFF
```

This piggybacks the shutdown command onto an existing communication path rather than requiring an additional mailbox field.

Power-state commands are passed to the LED control cog through a shared status word. The LED cog interprets these states independently, allowing the Main cog to supervise system power without directly controlling LED rendering.

### Controlled Shutdown

Shutdown is implemented as a coordinated sequence across the active cogs. The Main cog first signals the LED, BLE, and motion-processing cogs to perform their own shutdown routines. The LED cog immediately extinguishes the arrays, providing the user with visible confirmation that the shutdown command has been accepted, while the remaining shutdown sequence continues in the background.

```spin
'send power stop flag to led driver
repeat until not lockset(LockID1)
  ledData[0]|=$8000_0000
lockclr(LockID1)
'stop sensor fusion cog
dmp.stop
'stop led control cog
waitcnt(cnt+clkfreq/10)
led.stop
```

The 100 ms delays provide a conservative margin for each subsystem to complete its shutdown routine. The final delay also gives the EEPROM time to complete its persistent-state backup before the power latch is released. The delays were not precisely measured; 100 ms provided substantially more time than the operations required while remaining short enough to be imperceptible to the user.

When shutdown is initiated by the five-second dual-touch gesture, the firmware waits for both sensors to be released before removing power:

```spin
if (touchState==7)
  repeat
    timerCheck
    userTouch
  until (touchState==0)
```

This ensures that the High-Power Domain is not physically shut down until the initiating input has returned to its inactive state. Since the LEDs have already been turned off, the user receives immediate feedback that the shutdown command was accepted and can naturally release the sensors.

User configuration is normally saved during shutdown, but this step is skipped when installFlag indicates that new firmware has just been installed:

```spin
if (not installFlag)
  variableBackup(@colorMode,3+@colorMode)
  variableBackup(@groundColor,3+@groundColor)
  variableBackup(@lightMode,3+@lightMode)
  variableBackup(@calPitch,3+@calPitch)
  variableBackup(@powerMode,3+@powerMode)
  variableBackup(@strobeRate,3+@strobeRate)
```

The running firmware must relinquish control without overwriting persistent data during this transition. The user's configuration does not survive the firmware update itself, but the mobile application restores it when the updated Reactor reconnects.

Finally, the Main cog releases the power latch and enters a permanent halt:

```spin
waitcnt(cnt+clkfreq/10)
dira[powerPin]~
repeat
```

The result is a deterministic shutdown sequence in which visible lighting, inter-cog shutdown, user input, persistent storage, and physical power removal occur in a defined order rather than independently.

## Inter-Core Communication

The Propeller provides two practical IPC mechanisms: the PAR register for simple command/parameter passing, and shared hub RAM protected by hardware semaphores for larger data transfers. Because most Reactor interfaces exchange multiple related values, the firmware primarily uses a lock-protected snapshot pattern.

The producer processes and assembles a complete data product locally, acquires the lock, publishes the snapshot, and immediately releases the lock. The consumer copies the snapshot into local variables and then processes it without holding the lock.

A typical producer/consumer exchange looks like this:

```spin
`process local data
repeat until not lockset(LockID)
buffer[0] := value0
buffer[1] := value1
buffer[2] := value2
lockclr(LockID)
```
```spin
repeat until not lockset(LockID)
local0 := buffer[0]
local1 := buffer[1]
local2 := buffer[2]
lockclr(LockID)
'process local data
```

The lock protects the transfer, not the processing. Because lock acquisition is blocking, critical sections are kept as short as possible.

### One-Way Snapshots

This pattern is used throughout the firmware. The Sensor cog, for example, measures both touch sensors and publishes their hold times together every 20 ms:

```spin
lockset   LockID5 wc
if_c      jmp       #$-1
wrlong    aHold,    AaHold
wrlong    bHold,    AbHold
lockclr   LockID5
```

Publishing both measurements together gives Main a coherent snapshot from the same measurement cycle. Hold time is accumulated in 20 ms increments rather than tracked at the counter level, providing sufficient resolution for the 50 Hz touch state machine while keeping the acquisition code simple.

The battery ADC uses the same transfer pattern, but the Sensor cog first averages a group of 64 measurements. It then publishes the completed result and a new-data flag:

```spin
shr       pwrLvl, #6
lockset   LockID2 wc
if_c      jmp       #$-1
wrlong    pwrLvl,   ApwrLvl
wrlong    newP,     AnewP
lockclr   LockID2
```

This keeps the averaging workload on the Sensor cog and reduces the amount of data crossing the core boundary.

The same approach scales to larger snapshots. Main constructs the complete LED rendering state and publishes it as a five-long snapshot under LockID1; the LED cog copies the snapshot into local state before rendering.

The motion-processing path extends the pattern into a pipeline:

Sensor → raw IMU snapshot → DMP → fused-motion snapshot → Main

Each cog processes its own data locally and publishes only the resulting data product to the next stage.

### Bidirectional BLE Mailbox

The BLE interface requires a different pattern because communication occurs in both directions and individual transactions cannot safely be overwritten before they are consumed. Main and the BLE cog therefore share a larger mailbox protected by LockID6.

Main publishes Reactor state for the BLE cog:

```spin
repeat until not lockset(LockID6)
bleData[2] := colorMode
bleData[3] := groundColor
bleData[4] := lightMode
bleData[5] := powerMode
bleData[6] := brightMax
bleData[7] := strobeRate
bleData[8] := milliVolts
bleData[9] := deciCelsius
bleData[10] := brakeActive
bleData[11] := leftTurnActive
bleData[12] := rightTurnActive
bleData[13] := flashActive
bleData[14] := crashActive
bleData[16] := otaAddress
lockclr(LockID6)
```

The BLE cog uses the same mailbox to send configuration changes, commands, status information, and OTA data back to Main. A transaction flag indicates when new data is available.

After publishing a transaction, the BLE cog waits for Main to acknowledge that the mailbox has been consumed:

```spin
repeat
  repeat until not lockset(LockID6)
  if (not long[bleDataAddr][0])
    lockclr(LockID6)
    quit
  lockclr(LockID6)
```

The semaphore and transaction flag have separate roles. LockID6 provides mutual exclusion while the transaction flag provides producer/consumer synchronization. The acknowledgment prevents new BLE data from overwriting a pending transaction.

The firmware therefore uses two closely related IPC patterns:

One-way channels use snapshots: the producer publishes the latest complete state, and the consumer takes a local copy.
The bidirectional BLE channel uses a handshaked mailbox: each side can produce and consume data, with an acknowledgment ensuring that each transaction is consumed before the mailbox is reused. Across all of these interfaces, the same principle keeps the multicore system manageable: process data locally, transfer compact and coherent data products, and keep synchronization confined to the smallest possible critical section.

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

#### Figure 2 - Validation of synchronized data handoff between sensor and DMP cores

<img width="982" height="555" alt="validation_ipc_synchronization" src="https://github.com/user-attachments/assets/6932a127-fd3c-4026-a6a7-9449c2137f9f" />

(1) Sensor acquisition cycle begins, (2) new IMU sample committed to shared memory, (3) DMP core consumes new sample, (4) updated motion estimate committed to shared memory

#### Figure 3 - Inter-core data transfer latency
<img width="982" height="555" alt="validation_ipc_latency" src="https://github.com/user-attachments/assets/ad37efea-af8c-4bf4-ae77-b05aada6f5f8" />

(1) Sensor core commits new IMU sample to shared memory, (2) DMP core copies new sample approximately 200 us later

### Custom I2C implementation

Because the Propeller P8X32A lacks a dedicated I2C peripheral, a bare-metal driver was implemented in Propeller assembly (PASM). Oscilloscope captures were used to verify protocol timing and reliable data transfer.

#### Figure 4 - Validation of assembly-language I2C driver
<img width="982" height="555" alt="validation_i2c_protocol" src="https://github.com/user-attachments/assets/00555a53-0b94-462f-89ff-8dc0341a7f55" />

(1) START condition generated, (2) address and acknowledgement phase begins, (3) data transfer begins 
