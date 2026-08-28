---
# Firmware Architecture
## Overview
The embedded system runs on a multi-core MCU which operates separate cores for sensor acquisition, motion processing, main control, BLE communication, and LED control. These modules exchange data through buffers stored in main memory. Access to shared resources is synchronized using hardware locks to prevent concurrent access conflicts.

<img width="1096" height="565" alt="reactor_architecture" src="https://github.com/user-attachments/assets/694fda7f-01dd-43af-bfd3-ad3f6f867c92" />

**Figure 1** - High-level firmware architecture showing concurrent execution across the Propeller's eight processing cores

## Sensors
The sensor core acquires data from three sensor arrays. Battery voltage is measured on the accumulator of a sigma-delta ADC circuit. User input is detected by timing the activation of touch sensors on the sides of the device. Acceleration, angular velocity, and temperature measurements are acquired over I2C from an IMU.

## DMP
The motion processing core applies digital filtering and sensor fusion to combine the accelerometer and gyroscope data into an estimate of sensor orientation. This estimate is transformed into the bicycle's frame of reference and combined with the filtered IMU measurements to calculate orientation, acceleration, and turn-rate in rider space.

## Main
The main control core feeds the motion estimate, user input, battery voltage, and device temperature into a set of finite state machines responsible for motion detection, touch state, power management, and lighting behavior. The main core also manages system startup and persistent load/save operations.

## LED
The LED rendering core drives the left and right LED arrays according to motion detection state, operation mode, brightness settings, and strobe configuration.

## BLE
The BLE control core manages UART communications between the main control core and the external BLE radio module. Incoming packets from the mobile app are verified with CRC before being applied to user settings or firmware updates. Motion events and local setting changes are encoded and transmitted through BLE characteristics to synchronize the connected app.

## App
The Reactor mobile app provides centralized configuration and monitoring for multiple connected devices mounted to the bicycle. Users can activate turn signals and warning flashers through touch or voice control, monitor battery voltage and device temperature, and automatically notify selected contacts with GPS location data when a crash is detected. Firmware updates are transferred wirelessly through the app and verified before installation.

---
# Implementation Highlights

## Inter-Core Communication

The Reactor firmware uses shared hub RAM and the Propeller's hardware locks to exchange data between cogs. Inter-core data is organized into dedicated shared buffers rather than accessed directly as shared variables.

The basic pattern is simple: a producer builds a complete data snapshot, acquires a lock, copies the snapshot into hub RAM, and releases the lock. The consumer acquires the same lock, copies the snapshot into local variables, and releases the lock before processing it.

```spin
'publish local data
repeat until not lockset(LockID)
buffer[0] := value0
buffer[1] := value1
buffer[2] := value2
lockclr(LockID)
```

```spin
'acquire local copy
repeat until not lockset(LockID)
local0 := buffer[0]
local1 := buffer[1]
local2 := buffer[2]
lockclr(LockID)

'process local data
```

The lock protects only the transfer. Because lock acquisition is blocking, the critical sections are kept as short as possible.

### One-Way Snapshots

Most inter-core communication uses this snapshot pattern. The Sensor cog publishes its touch-sensor data under `LockID5`:

```spin
lockset   LockID5 wc
if_c      jmp       #$-1
wrlong    aHold,    AaHold
wrlong    bHold,    AbHold
lockclr   LockID5
```

The battery ADC uses the same pattern to publish its completed measurement and new-data flag:

```spin
shr       pwrLvl, #6
lockset   LockID2 wc
if_c      jmp       #$-1
wrlong    pwrLvl,   ApwrLvl
wrlong    newP,     AnewP
lockclr   LockID2
```

Larger snapshots use the same mechanism. Main publishes the complete LED rendering state under `LockID1`, and the LED cog copies that state into local variables before rendering. The motion-processing path extends the pattern into a pipeline:

```text
Sensor → raw IMU snapshot → DMP → fused-motion snapshot → Main
```

Each cog processes its data locally and publishes only the resulting data product to the next stage.

### Bidirectional Mailbox

The BLE interface requires a different pattern because it carries both continuous state and discrete transactions. Main and the BLE cog therefore share a larger mailbox protected by `LockID6`.

Main uses the mailbox to publish the current Reactor state:

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

This data is snapshot-oriented: Main is always free to overwrite it with newer state because the BLE cog is interested in the current value, not every intermediate value. The BLE cog decides when each characteristic should actually be notified to the application. A ground-light color change, battery-voltage change, or temperature change does not necessarily need to generate a BLE notification on every firmware cycle, allowing the BLE cog to throttle transmissions independently of the Main cog.

The reverse direction is transaction-oriented. The BLE cog receives configuration changes, commands, status information, and OTA data from the application and places them into the same mailbox. A transaction flag in the first mailbox element indicates that new data is waiting, while the status field identifies which portions of the mailbox are valid. For OTA transactions, the mailbox can also carry the current update status and firmware data:

```spin
'open ble data access lock
  repeat until not lockset(LockID6)
'send ble status data
  long[bleDataAddr][0]~~
  long[bleDataAddr][1]:=bleStatus
'send color configuration data
  if (bleStatus&(1<<5)<>0)
    long[bleDataAddr][2]:=colorMode
    long[bleDataAddr][3]:=colorIdx
    long[bleDataAddr][4]:=lightMode
'send power configuration data
  if (bleStatus&(1<<6)<>0)
    long[bleDataAddr][5]:=powerMode
    long[bleDataAddr][6]:=brightMax
    long[bleDataAddr][7]:=strobeRate
'send reactions data
  if (bleStatus&(1<<7)<>0)
    long[bleDataAddr][10]:=brakeActive
    long[bleDataAddr][11]:=leftTurnActive
    long[bleDataAddr][12]:=rightTurnActive
    long[bleDataAddr][13]:=flashActive
    long[bleDataAddr][14]:=crashActive
'send ota update data
  if (bleStatus&(1<<8)<>0)
    long[bleDataAddr][15]:=otaStatus
    if ((otaStatus==1) or (otaStatus==2))
      bytemove(otaBuffAddr,@otaBytes,18)
'close ble data access lock
  lockclr(LockID6)
```

Unlike Main's state snapshot, this data cannot safely be overwritten until Main has consumed it. After publishing a transaction, the BLE cog therefore waits for Main to clear the transaction flag:

```spin
'wait for receipt confirmation from main control
repeat
  repeat until not lockset(LockID6)
  if (not long[bleDataAddr][0])
    lockclr(LockID6)
    quit
  lockclr(LockID6)
```

The acknowledgment is intentionally asymmetric. `LockID6` provides mutual exclusion in both directions, but only BLE → Main requires transaction acknowledgment. Main can continuously publish newer Reactor state because intermediate snapshots do not need to be preserved. BLE, by contrast, must know that Main has consumed a discrete transaction before reusing the mailbox.

This distinction is particularly important for OTA updates, where every firmware block must be consumed before the next block is transferred. The same mechanism also prevents application commands or configuration changes from being overwritten before Main processes them.

The result is two closely related IPC patterns:

* One-way channels use snapshots: the producer publishes the latest complete state, and the consumer copies it locally.
* The Main → BLE path uses the same snapshot semantics, while the BLE cog controls when those values are transmitted over the wireless link.
* The BLE → Main path uses a handshaked mailbox: each transaction remains pending until Main acknowledges that it has been consumed.

Across all of these interfaces, the same principle keeps the multicore system manageable: process data locally, exchange compact and coherent data products, and confine synchronization to the smallest possible critical section.

## Finite State Machines

The Reactor firmware uses finite state machines throughout the control system to turn continuous, timing-sensitive inputs into predictable behavior. The implementation is deliberately lightweight: each FSM maintains a numeric state variable, and a Spin `case` statement selects the behavior associated with that state. FSM states are evaluated once per Main loop at 50 Hz.

### Touch Sensor Decoding

The `touchState` FSM is the primary example. The touch-sensor cog measures how long each sensor has been held and publishes those values to Main. The `userTouch` method takes a snapshot of those timers and progressively interprets them as higher-level gestures.

The initial states distinguish between no activity, one sensor being held, and both sensors being held:

```spin
case touchState
  0:'no touch sensor activity
    if ((tempABHold[0]<>0) and (tempABHold[1]==0))
      touchState:=8                               'A-side touch detected
    elseif ((tempABHold[0]==0) and (tempABHold[1]<>0))
      touchState:=9                               'B-side touch detected
    elseif ((tempABHold[0]<>0) and (tempABHold[1]<>0))
      touchState:=10                              'both touches detected
```

From there, the FSM uses hold duration to distinguish between gestures. A single sensor held for more than one second enters a dedicated state:

```spin
8:'A-side held
  if (tempABHold[1]==0)
    if (tempABHold[0]==0)
      touchState:=1                               'short A-side touch completed
    elseif (tempABHold[0]>clkfreq)
      touchState:=11                              'A-side held >1 second
  else
    touchState:=10                                'B-side touch added
```

Simultaneous touches are handled similarly. Releasing either sensor after a short dual touch produces one command, while holding both sensors beyond one second advances to another state:

```spin
10:'both sides held
  if ((tempABHold[0]==0) or (tempABHold[1]==0))
    touchState:=3                                 'short dual touch completed
  else
    if ((tempABHold[0]>clkfreq) and (tempABHold[1]>clkfreq))
      touchState:=6                               'dual touch held >1 second
```

Longer gestures continue through additional states, including the five-second hold used to select power-off:

```spin
6:'both sides held for >1 sec (battery color selected)
  if ((tempABHold[0]==0) or (tempABHold[1]==0))
    touchState:=13                                'one sensor released
  elseif ((tempABHold[0]>(5*clkfreq)) and (tempABHold[1]>(5*clkfreq)))
    touchState:=7                                 'dual touch held >5 seconds
```

The important architectural result is that the rest of the firmware does not need to understand the raw touch timing. `touchState` acts as an abstraction layer between the physical inputs and the rest of the control system.

Once a gesture has been decoded, the resulting operation can be very simple. The `userMode` method consumes the decoded states and modifies the appropriate user settings:

```spin
case touchState
  4:'color mode change
    blinkFlag~~
    colorMode++
    colorMode//=3

  5:'power mode change
    powerMode++
    powerMode//=3
```

The numeric state values are effectively magic numbers because Spin does not provide enums, but the state-specific comments make the transitions explicit and keep the machines readable.

The same basic architecture is used for physical behaviors, although some FSMs are considerably more sophisticated.

### Brake Detection

The `brakeState` FSM uses temporal hysteresis to prevent noisy acceleration measurements from causing the brake light to flicker. Once braking is detected, the debounce timer is continually restarted while the braking condition persists:

```spin
case brakeState
    0:'no brake detected
      if (brakeActive or (azB<brakeAcc))                'check for braking acceleration threshold
        Bcnt:=(3*clkfreq/2)+cnt                         'set 1.5s debounce timer
        brakeActive~~                                   'raise brakeActive flag
        brakeState:=1                                   'transition to state 1
    1:'brake detected
      if (azB<brakeAcc)                                 'check for braking acceleration threshold
        Bcnt:=(3*clkfreq/2)+cnt                         'restart debounce timer if still braking
      else
        if ((cnt-Bcnt)>0)                               'wait for debounce timer to expire
          brakeActive~                                  'clear brakeActive flag
          brakeState:=0                                 'transition to state 0
    other:'error correction
      brakeActive~                                      'reset brake signal state machine
      brakeState:=0
```

The brake indication therefore remains active until the braking acceleration condition has cleared and remained clear for the full debounce interval, rather than responding directly to every threshold crossing.

### Crash Detection

The `crashState` FSM applies the same state-driven architecture to a more complicated problem: determining whether two independent sensor events constitute a crash. Rather than triggering on excessive roll or acceleration alone, the FSM requires both conditions to occur within a defined time window. Either event can arrive first.

State 0 is the idle state. If excessive roll and acceleration are detected during the same cycle, the crash is immediately recognized. If only one event occurs, the FSM enters an intermediate state and waits for the other:

```spin
case crashState
  0:'no active crash
    if ((roll>crashRoll) or (roll<(-crashRoll)))
      if (aTM>crashAcc)
        crashActive~~
        crashState:=3                           'both events detected
      else
        crashState:=1                           'roll detected; wait for acceleration
    else
      if (aTM>crashAcc)
        crashState:=2                           'acceleration detected; wait for roll
```

State 1 handles the case where the roll event arrived first. The FSM continues waiting for excessive acceleration while the bike remains outside the upright range. If the roll condition clears before acceleration arrives, the machine can either continue waiting for acceleration or return to the idle state:

```spin
1:'roll event detected, waiting for acceleration event or roll reset
  if ((roll>uprightRoll) or (roll<(-uprightRoll)))
    if (aTM>crashAcc)
      crashActive~~                             'both events now detected
      Ccnt:=0
      crashState:=3                             'begin crash settling period
  else
    if (aTM>crashAcc)
      crashState:=2                             'acceleration arrived after roll recovered
    else
      crashState:=0                             'roll recovered; no crash
```

State 2 handles the opposite ordering: acceleration arrived first. The FSM waits for excessive roll while a five-second timeout limits how long the acceleration event remains valid:

```spin
2:'acceleration event detected, waiting for roll event or timeout
  if ((roll>crashRoll) or (roll<(-crashRoll)))
    crashActive~~                               'both events now detected
    Ccnt:=0
    crashState:=3                               'begin crash settling period
  else
    Ccnt++                                      'continue acceleration timeout
    if (Ccnt>(5*hertz))
      crashState:=0                             'timeout expired; cancel crash candidate
      Ccnt:=0
```

Once both events have been correlated, the FSM does not immediately declare the crash condition settled. State 3 provides a ten-second settling period before moving to the recovery state:

```spin
3:'crash detected, counting settling time
  Ccnt++
  if (Ccnt>(10*hertz))
    crashState:=4                               'crash settling period complete
```

State 4 then waits for the bike to return to an upright orientation before clearing the crash indication:

```spin
4:'crash settled, waiting for recovery
  if ((roll<uprightRoll) and (roll>(-uprightRoll)))
    crashState:=0                               'roll recovered
    Ccnt:=0
    crashActive~                                 'clear crash indication
```

An `other` case provides error correction by returning the FSM to its known idle state:

```spin
other:
  Ccnt:=0
  crashState:=0
  crashActive~
```

The resulting state progression gives the crash detector several layers of protection against false positives: either roll or acceleration may initiate detection, the second event must arrive within a limited window, and a confirmed crash remains active through a settling period until the bike returns to an upright orientation. The FSM therefore converts noisy, asynchronous sensor events into a single stable system-level condition.

Together, these state machines illustrate how the same lightweight mechanism can handle very different classes of control problems. While `touchState` translates user input into discrete commands, `brakeState` filters noisy sensor behavior over time, and `crashState` correlates multiple events into a stable system-level condition. Each FSM remains independently understandable, while more complex behavior emerges from their interaction.

## Power Management

Reactor's main control firmware treats power management as a coordinated system-level process rather than simply switching individual peripherals on and off. The Main cog supervises battery voltage, temperature, brightness, power-state commands, and the controlled shutdown of the entire system.

### Startup

On normal startup, the first instruction executed by the Main cog establishes the system power latch governing `POWER_EN`:

```spin
'latch main power
outa[powerPin]~
dira[powerPin]~~
```

From this point, power management continuously supervises the conditions that determine whether the Reactor should remain fully powered, reduce its light output, or begin shutting down.

### Continuous Power Supervision

Battery voltage is derived from a calibrated ADC measurement shared by the sensor and Main cogs. The calibrated value is converted to millivolts and a 0–255 battery-color index:

```spin
  repeat until not lockset(LockID2)
  if (newPowerData==0)
    lockclr(LockID2)
    status~                     'clear status if no new power data
  else
    tempPowerLevel:=powerLevel
    newPowerData:=0
    lockclr(LockID2)
    milliVolts:=minVolt+delVolt*(tempPowerLevel-loVolt)/(hiVolt-loVolt)         'calculate battery voltage
    batteryColor:=(((milliVolts-minVolt)/4)#>0)<#255                            'calculate battery color index
    status~~                                                                    'raise battery level status flag
```

The `loVolt` and `hiVolt` calibration values represent empirically averaged ADC measurements corresponding to the 3.0 V and 4.2 V battery endpoints across approximately ten Reactor PCBs. This compensates for variation between physical boards while keeping the runtime conversion simple.

Battery protection and thermal protection operate at different levels of the brightness hierarchy. `brightMax` represents the user's selected brightness level, while `brightLvl` provides finer-grained control for thermal regulation. Under normal conditions, the user's four brightness settings map to levels separated by five steps, leaving the intermediate levels available for gradual thermal derating:

```spin
if (deciCelsius>tempMax)
  brightLvl--
else
  brightLvl++
  brightLvl<#=(5*brightMax)
```

Thermal regulation can therefore reduce brightness gradually and restore it gradually as temperature changes. Battery derating instead reduces `brightMax`, producing a more noticeable reduction in output as the battery approaches its minimum operating voltage.

### Controlled Shutdown

Shutdown can be initiated in three ways: the user can hold both touch sensors for more than five seconds, the battery can fall below the minimum voltage after brightness has already been reduced to zero, or the application can issue a power-off command over BLE.

All three conditions converge on the same `powerStop` routine:

```spin
'set power status and initiate power stop if indicated
if ((powerMode>>31)==1)
  powerMode&=$7FFF_FFFF
  powerStatus:=$FFFF_FFFF

if ((brightLvl<0) or (touchState==7) or (powerStatus==$FFFF_FFFF))
  powerStop
```

This keeps the shutdown procedure independent of how shutdown was requested. The touch-sensor FSM supplies the five-second condition, the battery supervisor supplies the low-voltage condition, and the BLE subsystem passes the application command through the existing `powerMode` data path.

`powerStop` then coordinates the active cogs before releasing the physical power latch. The LED cog is signaled first so that the LEDs are extinguished immediately, providing visible confirmation that shutdown has been accepted:

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

The shutdown sequence allows each subsystem to complete its own shutdown processing before power is removed. The sequence includes conservative timing margins between subsystem shutdown operations and removal of power.

When shutdown originates from the five-second dual-touch gesture, the Main cog also waits for both sensors to be released before removing power:

```spin
if (touchState==7)
  repeat
    timerCheck
    userTouch
  until (touchState==0)
```

This prevents the initiating gesture from remaining active as the High-Power Domain is disconnected. Because the LEDs have already been turned off, the user receives immediate confirmation and can naturally release the sensors.

User configuration is normally saved during shutdown, but this step is skipped when a firmware installation has just completed. The `installFlag` prevents the newly installed firmware from overwriting the existing persistent configuration during the shutdown that immediately follows installation:

```spin
if (not installFlag)
  variableBackup(@colorMode,3+@colorMode)
  variableBackup(@groundColor,3+@groundColor)
  variableBackup(@lightMode,3+@lightMode)
  variableBackup(@calPitch,3+@calPitch)
  variableBackup(@powerMode,3+@powerMode)
  variableBackup(@strobeRate,3+@strobeRate)
```

Finally, the Main cog releases the power latch and enters a permanent halt:

```spin
waitcnt(cnt+clkfreq/10)
dira[powerPin]~
repeat
```

The result is a deterministic power lifecycle: the system starts by establishing its power domain, continuously manages battery and thermal constraints during operation, and funnels every shutdown condition through a single coordinated sequence before physically removing power.

## Firmware Updates

Reactor's firmware update system uses a two-stage process: the new firmware is first downloaded safely into a spare EEPROM bank, then explicitly installed into the primary bank. The app supplies firmware data, but the Reactor controls the transfer, validates each block, and determines when it is safe to advance.

The app distributes a precompiled JavaScript object containing the complete 32 kB firmware image, divided into 2,048 sixteen-byte blocks. Each block is transmitted as a 20-byte packet containing a two-byte address, sixteen bytes of firmware data, and a two-byte CRC.

When an update begins, the Reactor initializes the transfer and requests the first block. The app responds with the block identified by the requested address. The BLE cog validates the address and CRC before publishing the packet to Main:

```spin
tOtaAddress:=256*otaBytes[0]+otaBytes[1]
if (tOtaAddress==otaAddress)
  crc:=0
  repeat idx from 0 to 19
    crcByte:=otaBytes[idx]<<8
    crcIndex:=(crc^crcByte)>>8
    crc:=(crc<<8)^word[@crcTable][crcIndex]
  if (crc==0)
    otaStatus:=2
```

The CRC is calculated across the entire 20-byte packet, including the transmitted CRC value, so a valid packet produces a zero remainder. If the address or CRC check fails, the Reactor requests the same block again rather than advancing the transfer.

Once validated, the BLE cog publishes the packet through the inter-core mailbox. Main writes the sixteen firmware bytes to the spare EEPROM bank and **only then** advances `otaAddress`:

```spin
if (tOtaAddress==otaAddress)
  ramToRom(2+@otaBytes,17+@otaBytes,32_768+otaAddress)
  otaAddress+=16
  variableBackup(@otaAddress,3+@otaAddress)
```

This makes `otaAddress` a persistent checkpoint rather than simply a counter. The address is advanced only after the corresponding block has been committed to EEPROM, and the new value is immediately backed up. If power is lost during the download, the primary EEPROM bank still contains the running firmware, while the saved address identifies the next block that needs to be transferred.

An interrupted download can therefore resume without restarting from the beginning. The Reactor continues requesting blocks from its existing `otaAddress`, while the app simply supplies whatever block is requested.

After all 2,048 blocks have been written successfully, the download is complete, but the new firmware is not installed automatically. Installation is a separate user-initiated operation. The complete image is copied from the spare EEPROM bank into the primary bank:

```spin
installFlag~~
repeat idx from 0 to 255
  romToRam(@updateBytes,127+@updateBytes,32_768+128*idx)
  ramToRom(@updateBytes,127+@updateBytes,128*idx)
waitcnt(cnt+clkfreq)
powerStop
```

The installation takes approximately 30 seconds and intentionally blocks the firmware while the EEPROM transfer is performed. Unlike the download phase, the installation phase cannot be safely interrupted. Once the transfer to the primary bank begins, removing power before it finishes can leave the active firmware incomplete. The user therefore only needs to ensure that the Reactor's battery remains connected during installation. Once the copy is complete, the Reactor enters its normal shutdown sequence, and the next power-on boots the newly installed firmware.

The `installFlag` provides a final safeguard during this transition. Because the outgoing firmware is about to be replaced, `powerStop` skips its normal user-state backup when an update has just been installed. The flag itself does not survive the power cycle; the app can instead offer to restore the user's previous settings after the new firmware boots and reconnects.

The result is a deliberately conservative update process: download, validate, commit, checkpoint, then install.

Indexed packets provide sequencing, the CRC detects corrupted transmissions, the persistent `otaAddress` makes interrupted downloads resumable, and the spare EEPROM bank ensures that a failed download never overwrites the firmware currently running the Reactor.

---
## Engineering Challenges

### Real-time responsiveness constraints
One of the primary engineering challenges was implementing a motion estimation pipeline that produced stable orientation estimates while remaining responsive enough for real-time lighting control. I evaluated both Kalman and complementary filtering approaches and ultimately selected a complementary filter due to its significantly lower computational cost. Extensive tuning and testing were required to balance responsiveness, stability, and noise rejection under real-world riding conditions.

### Real-world motion validation
Developing reliable motion detection required both controlled testing and real-world validation. A desktop test rig was used to compare estimated orientation against known pitch and roll angles under quasi-static conditions, while live ride logging was used to tune filtering and motion thresholds during actual operation. These tests helped improve the reliability of braking, turning, and crash detection behaviors.

### Timing and synchronization
Maintaining consistent real-time behavior required careful attention to timing and synchronization across multiple interacting subsystems. Firmware execution was instrumented using GPIO timing traces and runtime logging to identify bottlenecks, synchronization issues, and long-duration timing failures. Several issues related to counter rollover and inter-core coordination were identified and resolved during testing.

### BLE data integrity
The BLE communication subsystem was designed to support telemetry, user control, and firmware updates while remaining robust against interruptions and corrupted data. CRC validation and resumable transfer mechanisms were implemented to improve reliability during firmware updates.

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
