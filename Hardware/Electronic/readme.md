# Electronics

---
## Architecture Summary

The architecture of Reactor's electronic system was developed to support three primary responsibilities: sensing the motion of the bicycle, controlling the lighting system in real time, and communicating with external devices. These responsibilities place very different demands on the hardware. Motion sensing requires clean power and reliable timing. Wireless communication requires its own dedicated radio subsystem. High-power LED operation requires significantly more energy than the rest of the electronics combined.

To accommodate these competing requirements, the system was divided into functional subsystems organized around four power domains. This approach simplified development and debugging while allowing sensing, communications, control, and lighting hardware to evolve independently as the design matured. This architecture also supports Reactor's low-power operating modes by allowing portions of the system to remain active only when required.

The block diagram in Figure 1 below provides a high-level view of the electronic architecture and the relationships between its major subsystems.

<img width="1009" height="854" alt="reactor_Electronics_Block_Diagram" src="https://github.com/user-attachments/assets/402fbcb4-3d4a-42bf-b069-757e22a427c5" />

**Figure 1** - System architecture showing the four functional power domains and their major hardware subsystems

### 🔵 Power Source

The Power Source block consists of a removable lithium-ion battery and the circuitry required to safely interface that battery to the rest of the system. The removable battery design allows riders to replace depleted cells and continue riding without waiting for a recharge cycle. Input protection circuitry guards the electronics against common fault conditions and provides a stable entry point for power distribution throughout the device.

### 🟢 Always-On Domain

The Always-On Domain provides the circuitry to monitor rider input and initiate system startup. It remains powered whenever a battery is installed and operates independently of the rest of the system. This arrangement allows Reactor to remain responsive while minimizing standby power consumption, since the lighting system and control electronics only need to be energized when the rider requests them.

### 🔴 High-Power Domain

The High-Power Domain serves as the primary operating power domain for Reactor. Once activated by the Always-On Domain, it supplies power to the lighting system and to the control electronics responsible for sensing, communications, and system coordination. This arrangement allows the majority of the hardware to remain unpowered when inactive while still supporting rapid startup when rider input is detected.

### 🟡 Control Domain

The Control Domain contains the circuitry responsible for sensing, computation, communications, data storage, battery monitoring, and system coordination. It receives power from the High-Power Domain and remains active only while the lighting system is operating. This arrangement provides a stable regulated supply while ensuring that the control electronics consume no power when the system is inactive.

---
## Domain Details

### 🔵 Power Source

The Power Source block provides energy to the entire system and protects downstream electronics from battery-related fault conditions. All power enters the PCB from a battery and passes through a small protection stage before reaching the remainder of the system. Figure 2 shows the schematic snippet for both subsystems.

<img width="480" height="427" alt="schematic_Power_Source" src="https://github.com/user-attachments/assets/ee1f9e37-4337-4eba-8f65-4d4c461ac154" />

**Figure 2**

#### Removable Li-ion Battery

Reactor is powered by a single rechargeable lithium-ion cell in the 18650 form factor. The 18650 was selected for its combination of energy density, availability, low cost, and well-established ecosystem of chargers and replacement cells.

A removable battery was chosen instead of an integrated rechargeable pack to improve usability during normal operation. Riders can carry spare cells and replace a depleted battery in seconds rather than waiting for the device to recharge. This approach also simplifies long-term maintenance, since battery capacity naturally degrades over time and replacement does not require disassembling the electronics.

#### PCB Input Protection

The PCB Input Protection subsystem forms the interface between the battery and the rest of Reactor's electronics. Battery voltage first passes through a transient voltage suppression diode that protects the circuit from electrostatic discharge events that may occur during battery handling, insertion, or removal.

Because Reactor uses removable batteries, incorrect installation must be considered a normal operating scenario rather than an exceptional event. A power MOSFET configured for reverse-polarity protection prevents damage if a battery is installed incorrectly.

The protected output of this stage appears at **VIN**, which serves as the entry point for the remainder of Reactor's power distribution system.

### 🟢 Always-On Domain

The Always-On Domain provides the circuitry required for Reactor to remain responsive while inactive. Unlike the remainder of the system, which is unpowered when the bike light is off, the Always-On Domain remains active whenever a battery is installed. The Always-On Domain consists of two primary subsystems: the touch sensing circuitry used to detect rider input and the wakeup logic responsible for enabling the rest of the electronic system. Figure 3 shows the schematic snippet for the Always-On Domain.

<img width="1168" height="603" alt="schematic_Always_On" src="https://github.com/user-attachments/assets/3ede6553-6507-4f0e-8b2b-1a189ddee6c5" />

**Figure 3**

#### Power Distribution

The Always-On Domain is powered by a dedicated 2.5V supply generated directly from the lithium-ion battery through a low-dropout linear regulator which is always enabled. A regulator was selected to maximize the usable battery discharge range while minimizing standby power consumption. Its low quiescent current allows the Always-On Domain to remain active for extended periods without significantly affecting battery life, while providing sufficient dropout margin to maintain regulation throughout the normal operating range of a single lithium-ion cell.

#### Dual Touch Sensors

Rider input is detected by dual sensing pads integrated into the left and right sides of the PCB and bonded  to the inside of the mechanical enclosure. Each pad is continuously monitored by a dedicated touch controller IC that produces a digital output when a touch is detected. These outputs appear as the **TOUCH_A** and **TOUCH_B** signals, which are used by the Always-On Domain to initiate system startup and later by firmware to interpret rider commands.

Capacitive sensing was selected because it provides a sealed user interface with no mechanical buttons or switches. This improves durability in outdoor environments and eliminates openings that would otherwise complicate weather resistance.

#### Wakeup Logic

The Wakeup Logic subsystem controls the transition between Reactor's standby and operating states.

A simultaneous touch on both sensing pads generates the **4V_EN** signal, enabling the High-Power Domain. Requiring both sensors to be activated reduces the likelihood of accidental startup while still providing a simple power-on gesture. Once the system has started, control of the power state is transferred to firmware through the **POWER_EN** signal. This allows the microcontroller to keep the system powered after the original touch event has ended and later return the device to standby when appropriate.

By separating wakeup detection from normal operation, Reactor remains responsive while consuming very little power when inactive. The rider experiences immediate startup, while the majority of the electronics remain unpowered until needed.

### 🔴 High-Power Domain

The High-Power Domain provides the regulated power required for normal system operation. Once enabled by the Always-On Domain, it supplies energy to both the lighting system and the control electronics responsible for sensing, communications, and system coordination.

In addition to power conversion, this domain manages the startup sequence that brings the remainder of the system online and ensures that downstream circuitry receives stable operating voltages across the full battery discharge range. Figure 4 shows the schematic snippet for the High-Power Domain power distribution circuitry.

<img width="723" height="508" alt="schematic_High_Power_Regulator" src="https://github.com/user-attachments/assets/d4faa1d0-2106-4fdd-a27e-b4b789d5b61c" />

**Figure 4**

#### Power Distribution

The High-Power Domain is enabled through the **4V_EN** signal generated by the Always-On Domain. Once asserted, a buck/boost regulator produces the primary 4.0V supply that powers both LED arrays directly.

A buck/boost topology was selected because the voltage of a single lithium-ion cell varies substantially throughout its normal discharge cycle. This allows the regulator to maintain a constant 4.0V output whether the battery voltage is above or below the target net voltage, ensuring consistent LED performance across the full operating range of the battery.

In addition to powering the LED arrays, the regulated 4.0V regulator supplies the downstream 3.3V regulator that supplies the Control Domain.

#### Dual LED Arrays

The lighting system consists of two independent chains of addressable RGB LEDs. Each array contains eight LEDs and is controlled independently by firmware through dedicated serial data connections. Figure 5 shows the schematic snippet for both LED arrays.

<img width="1567" height="469" alt="schematic_High_Power_LEDs" src="https://github.com/user-attachments/assets/501e373b-33c8-4fc5-9cb1-c212ae9ad76b" />

**Figure 5**

Addressable LEDs were selected because they integrate the LED drivers and communication interface into a single package. This significantly reduces component count and routing complexity compared to a discrete LED implementation, while providing individual color and brightness control of every LED. The resulting flexibility allows a single hardware platform to support head, tail, and ground light modes as well as brake, turn, and hazard indications entirely through firmware.

The arrays are powered directly from the regulated 4.0V supply and arranged as independent serial chains, allowing each array to operate independently when required. Each LED includes local bypass capacitance to reduce supply disturbances caused by rapid switching of the internal LED drivers.

### 🟡 Control Domain

The Control Domain contains the circuitry responsible for sensing, computation, communications, persistent storage, and battery monitoring. Operating from the regulated 3.3V supply, it serves as the central coordination point for Reactor's electronic system.

At its heart is a multicore microcontroller that acquires sensor data, executes the control algorithms, manages wireless communications, stores configuration data, monitors battery condition, and generates the commands transmitted to the LED arrays. Supporting peripherals provide motion sensing, wireless connectivity, non-volatile storage, and battery measurement capabilities.

The following sections describe each subsystem in detail.

#### Power Distribution

The Control Domain is powered from a dedicated 3.3V low-noise linear regulator sourced from the High-Power Domain's 4.0V supply. This regulator provides a clean, stable supply for the microcontroller, inertial measurement unit, wireless communications module, battery monitor, and persistent memory. Figure 6 shows the schematic snippet for the Control Domain power supply.

<img width="540" height="315" alt="schematic_Control_Domain_LDO" src="https://github.com/user-attachments/assets/5a34cbd3-66d6-4322-a4e7-60b1979ecb7c" />

**Figure 6**

The regulator is enabled through the **3V3_EN** signal, which is held low by the power-good output of the 4.0V regulator and released after its output has stabilized. This startup sequence ensures that the control electronics are energized only after the primary supply has reached a valid operating voltage, preventing the system from attempting to initialize from an unstable supply.

#### Microcontroller

The microcontroller coordinates every function within Reactor's electronic system. It receives sensor data from the inertial measurement unit, processes rider input from the touch sensors, manages wireless communications, monitors battery condition, retrieves configuration data from non-volatile memory, and generates lighting commands for the LED arrays. Figure 6 shows the microcontroller and its supporting circuitry, including the external crystal oscillator and local decoupling network required for reliable operation.

<img width="603" height="632" alt="schematic_Control_Domain_MCU" src="https://github.com/user-attachments/assets/ece6e7aa-b6e8-4bd2-ad30-27eaa227fc2f" />

**Figure 7**

The Propeller P8X32A serves as the central controller for Reactor. The device provides eight independent processing cores that share access to memory and I/O resources, allowing sensing, communications, lighting control, and system management tasks to execute concurrently.

Unlike most modern microcontrollers, the Propeller provides only a minimal set of hardware peripherals. As a result, many low-level system functions were implemented directly in software. Communication interfaces, LED signaling, timing infrastructure, battery measurement, and subsystem coordination were all developed as bare-metal firmware components tailored to the requirements of the project.

This approach required a deeper understanding of both the hardware and software layers of the system but also provided complete control over timing behavior and resource allocation. The resulting architecture allowed motion sensing, wireless communications, power management, and lighting control to operate simultaneously while maintaining deterministic system behavior.

#### Inertial Measurement

The inertial measurement unit (IMU) provides the motion data that allows Reactor to respond automatically to changing riding conditions. It continuously measures linear acceleration and angular velocity, providing the information required to detect braking, turning, crashes, and changes in bicycle orientation. Figure 7 shows the IMU and its supporting circuitry.

<img width="601" height="500" alt="schematic_Control_Domain_IMU" src="https://github.com/user-attachments/assets/c5256526-324b-471a-b80c-2063286a77c1" />

**Figure 8**

The IMU communicates with the microcontroller over an I²C interface and serves as the primary sensing device within Reactor. An interrupt output provides a dedicated hardware signal for communicating time-critical events to the microcontroller, while pull-up resistors on the I²C bus ensure reliable communication between the two devices.

Because many of Reactor's safety features depend on accurate motion measurements, the IMU was supplied by the dedicated low-noise 3.3 V regulator within the Control Domain. Local decoupling capacitors were placed adjacent to the device to maintain a stable supply during operation and minimize high-frequency supply disturbances.

The hardware provides only the raw motion data. Filtering, sensor fusion, coordinate transformations, and motion classification algorithms that convert these measurements into lighting behavior are implemented entirely in firmware and are described in the Firmware documentation.

#### Radio Communications

The Bluetooth Low Energy (BLE) subsystem provides wireless communication between Reactor and the companion mobile application. Through this interface, riders can configure device behavior, monitor battery status, and receive crash notifications without requiring a wired connection. Figure 8 shows the BLE module and its supporting circuitry.

<img width="671" height="575" alt="schematic_Control_Domain_BLE" src="https://github.com/user-attachments/assets/d655e51c-f023-4651-a7cf-c707e1c2f64f" />

**Figure 9**

Wireless communication is provided by a self-contained BLE module that integrates the radio, protocol stack, and application processor into a single package. Using a pre-certified module significantly reduced hardware complexity and eliminated the need to develop a custom RF design.

The module communicates with the microcontroller through a UART interface. A dedicated **BLE_RST** signal allows firmware to place the module in a known state during startup and recover from communication faults if necessary. Two configurable GPIO outputs are connected to the microcontroller as **BLE_P1_6** and **BLE_P1̅_7**, providing simple hardware status signals that reduce firmware polling overhead. The remaining module I/O pins are unused and tied to their recommended default states in accordance with the manufacturer's reference design.

#### Battery Monitor

The Battery Monitor subsystem measures battery voltage so firmware can estimate remaining charge, report battery status to the rider, and notify the rider when the battery requires replacement or recharging. Figure 9 shows the analog front-end used to interface the battery to the microcontroller.

<img width="434" height="388" alt="schematic_Control_Domain_ADC" src="https://github.com/user-attachments/assets/d868707f-83b2-4bf5-b5a2-832eca590724" />

**Figure 10**

Battery voltage is reduced to a safe measurement range by a resistor divider before being presented to the microcontroller. RC filtering removes high-frequency noise and switching transients from the supply, improving measurement stability during normal operation.

Because the Propeller P8X32A does not include a hardware analog-to-digital converter, battery voltage is measured using the device's built-in sigma-delta counter mode. The filtered divider output is connected to the measurement input (**ADC_M**), while a second GPIO (**ADC_P**) provides the feedback signal required by the sigma-delta conversion circuit. This approach provides a simple, low-cost method of measuring battery voltage without requiring an external ADC.

#### Persistent Memory

The Persistent Memory subsystem provides non-volatile storage for both Reactor's application firmware and user configuration data. Unlike many modern microcontrollers, the Propeller P8X32A contains no internal program flash. Instead, its built-in bootloader retrieves the application image from an external I²C EEPROM during every system startup. Figure 10 shows the EEPROM interface circuitry.

<img width="517" height="464" alt="schematic_Control_Domain_EEPROM" src="https://github.com/user-attachments/assets/5a4bbdef-a4f1-4de4-8466-7c61575fc41f" />

**Figure 11**

The EEPROM is connected to the microcontroller through a dedicated I²C interface that is separate from the inertial measurement unit. This isolates program memory accesses from motion sensor communications while allowing firmware to read and write persistent data whenever required.

A dual-bank EEPROM was selected to support safe firmware updates. New firmware images are written to the inactive memory bank before replacing the active application, reducing the risk of rendering the device inoperable if power is interrupted during the update process.

In addition to storing the application firmware, unused EEPROM space is used to retain configuration data across power cycles. Rider preferences, lighting configuration, and other operating parameters remain intact even when the battery is removed, eliminating the need to reconfigure the device after normal battery replacement.

---
## PCB Layout

The Reactor PCB was designed as a compact four-layer board that integrates the lighting, sensing, power management, and communications subsystems into a single assembly. Component placement, routing, power distribution, and thermal management were considered together to support reliable operation while conforming to the mechanical constraints of the enclosure. The resulting layout separates high-current lighting circuitry from the control electronics while providing continuous ground planes, dedicated internal power distribution, and integrated capacitive touch electrodes. Figure 12 shows the annotated view of this layout.

<img width="600" height="867" alt="PCB_Annotated_Small" src="https://github.com/user-attachments/assets/3f302906-1c99-447a-986c-c2b417ecbcaf" />

**Figure 12**
| Domain | ID | Module |
|:------|:---:|:-------|
| 🔵 **Power Source** | **P1** | Removable Li-ion Battery |
| 🔵 **Power Source** | **P2** | PCB Input Protection |
| 🟢 **Always-On** | **A1** | Always-On Supply |
| 🟢 **Always-On** | **A2** | Dual Touch Sensors |
| 🟢 **Always-On** | **A3** | Wakeup Logic |
| 🔴 **High-Power** | **H1** | High-Power Supply |
| 🔴 **High-Power** | **H2** | Control Supply |
| 🔴 **High-Power** | **H3** | Dual LED Arrays |
| 🟡 **Control** | **C1** | Microcontroller |
| 🟡 **Control** | **C2** | Battery Monitor |
| 🟡 **Control** | **C3** | Radio Communications |
| 🟡 **Control** | **C4** | Inertial Measurement |
| 🟡 **Control** | **C5** | Persistent Memory |

### Layer 1 – Component Placement and Signal Routing

<img width="702" height="981" alt="pcb_Layout_Full_Top" src="https://github.com/user-attachments/assets/c6830c8f-917c-462f-95e5-0310573ac74c" />

**Figure 13**

The top layer contains all components, all signal routing, and the battery power distribution. Keeping every signal on a single layer simplified routing, eliminated vias on critical interfaces, and provided complete control over return current paths through the adjacent ground plane. High-current lighting traces were routed with appropriate width while sensitive control signals were kept short and isolated from switching power circuitry.

Component placement follows the functional partitioning established in the schematic. Power conversion circuitry is located near the battery input, the control electronics occupy the center of the board, and the LED arrays are positioned along the perimeter to maximize optical coverage while minimizing routing complexity.

### Layer 2 – Ground Plane

<img width="700" height="958" alt="pcb_Layout_Full_L2" src="https://github.com/user-attachments/assets/1700d79d-6df7-4ca0-aba5-8b15ef13a8a5" />

**Figure 14**

The second layer is dedicated almost entirely to an uninterrupted ground plane. Providing a continuous return plane directly beneath the signal layer improves signal integrity, minimizes loop area, and reduces susceptibility to switching noise from the power electronics. The solid copper area also contributes significant thermal spreading, distributing heat generated by the LED arrays and power converters across the PCB.

### Layer 3 – Power Distribution

<img width="702" height="969" alt="pcb_Layout_Full_L3" src="https://github.com/user-attachments/assets/3f1e585a-aa55-425e-8029-3bf6251b2b2d" />

**Figure 15**

The third layer distributes the regulated 2.5V, 3.3V, and 4.0V supply domains throughout the board. Separating power distribution from signal routing reduces routing congestion while allowing each supply domain to be delivered with low impedance to its respective circuitry. The wide copper regions also contribute additional thermal mass, helping conduct heat toward the aluminum enclosure and the steel mounting pins used by the silicone mounting strap.

### Layer 4 – Ground Plane

<img width="688" height="974" alt="pcb_Layout_Full_Bottom" src="https://github.com/user-attachments/assets/29cdfd44-303a-4d8b-85f6-f938c8749bdf" />

**Figure 16**

The bottom layer provides a second continuous ground plane. Together with Layer 2, it forms a low-impedance return path for the entire system while improving electromagnetic performance and increasing the board's overall thermal conductivity. The dual-plane arrangement also increases mechanical rigidity despite the relatively thin PCB profile required by the enclosure.

## Testing / Validation

**This section is still under construction. Please come back later to learn more about the testing and validation of Reactor's electronic system.**

The electronic design was validated through a combination of oscilloscope measurements, logic analyzer captures, power supply characterization, and long-duration functional testing. These measurements were used to verify startup sequencing, regulator stability, communications timing, battery measurement accuracy, and reliable operation of the lighting system under normal riding conditions.

---
