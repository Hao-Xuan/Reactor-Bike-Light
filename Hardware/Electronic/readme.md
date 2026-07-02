**This section is still under construction. Please come back later to learn more about the design of Reactor's electronic system.**

# Electronics

---
## Architecture Summary

The architecture of Reactor's electronic system was developed to support three primary responsibilities: sensing the motion of the bicycle, controlling the lighting system in real time, and communicating with external devices. These responsibilities place very different demands on the hardware. Motion sensing requires clean power and reliable timing. Wireless communication requires its own dedicated radio subsystem. High-power LED operation requires significantly more energy than the rest of the electronics combined.

To accommodate these competing requirements, the system was divided into functional subsystems organized around several independent power domains. This approach simplified development and debugging while allowing sensing, communications, control, and lighting hardware to evolve independently as the design matured. This architecture also supports Reactor's low-power operating modes by allowing portions of the system to remain active only when required.

The block diagram below provides a high-level view of the electronic architecture and the relationships between its major subsystems.

<img width="1006" height="852" alt="reactor_Electronics_Block_Diagram" src="https://github.com/user-attachments/assets/fee37ae8-e217-413f-afb5-abafc2e6bc7a" />

**Figure 1**

### Power Source

The Power Source block consists of a removable lithium-ion battery and the circuitry required to safely interface that battery to the rest of the system. The removable battery design allows riders to quickly replace depleted cells and continue riding without waiting for a recharge cycle. Input protection circuitry guards the electronics against common fault conditions and provides a stable entry point for power distribution throughout the device.

### Always-On Domain

The Always-On Domain provides the minimum circuitry required to monitor rider input and initiate system startup. It remains powered whenever a battery is installed and operates independently of the rest of the system. This arrangement allows Reactor to remain responsive while minimizing standby power consumption, since the lighting system and control electronics only need to be energized when the rider requests them.

### High-Power Domain

The High-Power Domain serves as the primary operating power domain for Reactor. Once activated by the Always-On Domain, it supplies power to the lighting system and to the control electronics responsible for sensing, communications, and system coordination. This arrangement allows the majority of the hardware to remain unpowered when inactive while still supporting rapid startup when rider input is detected.

### Control Domain

The Control Domain contains the circuitry responsible for sensing, computation, communications, data storage, battery monitoring, and system coordination. It receives power from the High-Power Domain and remains active only while the lighting system is operating. This arrangement provides a stable regulated supply while ensuring that the control electronics consume no power when the system is inactive.

---
## Domain Details

### Power Source

The Power Source block provides energy to the entire system and protects downstream electronics from battery-related fault conditions. All power enters the PCB from a removable lithium-ion battery and passes through a small protection stage before reaching the remainder of the system. Figure 2 shows the schematic snippet for both subsystems.

<img width="480" height="427" alt="schematic_Power_Source" src="https://github.com/user-attachments/assets/ee1f9e37-4337-4eba-8f65-4d4c461ac154" />

**Figure 2**

#### Removable Li-ion Battery

Reactor is powered by a single rechargeable lithium-ion cell in the 18650 form factor. The 18650 was selected for its combination of energy density, availability, low cost, and well-established ecosystem of chargers and replacement cells.

A removable battery was chosen instead of an integrated rechargeable pack to improve usability during normal operation. Riders can carry spare cells and replace a depleted battery in seconds rather than waiting for the device to recharge. This approach also simplifies long-term maintenance, since battery capacity naturally degrades over time and replacement does not require disassembling the electronics.

The dimensions of the battery became one of the primary drivers of the mechanical design. The size of the cell established the minimum cross-sectional size of the enclosure and strongly influenced the overall form factor, mounting architecture, and battery access mechanism described elsewhere in this documentation.

#### PCB Input Protection

The PCB Input Protection subsystem forms the interface between the removable battery and the rest of Reactor's electronics. Because Reactor uses removable batteries, incorrect installation must be considered a normal operating scenario rather than an exceptional event.

Battery voltage enters the system through the **VBAT** node. A transient voltage suppression diode protects the circuit from electrostatic discharge events that may occur during battery handling, insertion, or removal. A power MOSFET configured for reverse-polarity protection prevents damage if a battery is installed incorrectly while introducing only a minimal voltage drop during normal operation.

The protected output of this stage appears at **VIN**, which serves as the entry point for the remainder of Reactor's power distribution system.

### Always-On Domain

The Always-On Domain provides the circuitry required for Reactor to remain responsive while inactive. Unlike the remainder of the system, which is unpowered when the bike light is off, the Always-On Domain remains active whenever a battery is installed. Its primary responsibility is to monitor rider input and determine when the system should transition from standby into normal operation. Figure 3 shows the schematic snippet for the Always-On Domain.

<img width="1168" height="603" alt="schematic_Always_On" src="https://github.com/user-attachments/assets/3ede6553-6507-4f0e-8b2b-1a189ddee6c5" />

**Figure 3**

The Always-On Domain consists of two primary subsystems: the touch sensing circuitry used to detect rider input and the wakeup logic responsible for enabling the rest of the electronic system.

#### Dual Touch Sensors

Rider input is detected by dual sensing pads integrated into the left and right sides of the PCB and bonded to the inside of the mechanical enclosure. Each pad is continuously monitored by a dedicated touch controller IC that produces a digital output when a touch is detected. These outputs appear as the **TOUCH_A** and **TOUCH_B** signals, which are used by the Always-On Domain to initiate system startup and later by firmware to interpret rider commands.

Capacitive sensing was selected because it provides a sealed user interface with no mechanical buttons or switches. This improves durability in outdoor environments and eliminates openings that would otherwise complicate weather resistance.

#### Wakeup Logic

The Wakeup Logic subsystem controls the transition between Reactor's standby and operating states.

A simultaneous touch on both sensing pads generates the **4V_EN** signal, enabling the High-Power Domain. Requiring both sensors to be activated reduces the likelihood of accidental startup while still providing a simple power-on gesture. Once the system has started, control of the power state is transferred to firmware through the **POWER_EN** signal. This allows the microcontroller to keep the system powered after the original touch event has ended and later return the device to standby when appropriate.

By separating wakeup detection from normal operation, Reactor remains responsive while consuming very little power when inactive. The rider experiences immediate startup, while the majority of the electronics remain unpowered until needed.

### High-Power Domain

The High-Power Domain provides the regulated power required for normal system operation. Once enabled by the Always-On Domain, it supplies energy to both the lighting system and the control electronics responsible for sensing, communications, and system coordination.

In addition to power conversion, this domain manages the startup sequence that brings the remainder of the system online and ensures that downstream circuitry receives stable operating voltages across the full battery discharge range. Figure 4 shows the schematic snippet for the High-Power Domain power distribution circuitry.

<img width="1257" height="532" alt="schematic_High_Power_Regulators" src="https://github.com/user-attachments/assets/b162e02d-3762-4c70-93b6-06cbafe62a1d" />

**Figure 4**

#### Main Power Distribution

The High-Power Domain is built around two regulated supply rails. A buck/boost regulator generates the primary 4.0V rail used to power the lighting system, while a low-noise LDO regulator generates the 3.3V rail used by the Control Domain. This arrangement separates high-current LED operation from the sensing, communications, and processing circuitry while providing stable operating voltages across the full battery discharge range.

The High-Power Domain is enabled through the **4V_EN** signal generated by the Always-On Domain. Once asserted, a buck/boost regulator produces the primary 4.0V supply rail. A buck/boost topology was selected because the voltage of a lithium-ion cell varies substantially during normal operation. This allows the system to maintain a constant output voltage whether the battery voltage is above or below the target rail voltage, ensuring consistent performance throughout the discharge cycle.

The 4.0V rail powers both LED arrays directly and serves as the source for the downstream 3.3V regulator that supplies the Control Domain.  A low-noise linear regulator was selected to provide a clean supply for the microcontroller, inertial measurement unit, wireless communications module, and non-volatile memory. This LDO is enabled through the **3V3_EN** signal, which is released by the power-good output of the 4.0V regulator after its output is stable. This sequencing ensures that the control electronics are powered only after the primary supply rail has reached a valid operating voltage, preventing startup from an unstable supply.

#### Dual LED Arrays

The lighting system consists of two independent chains of addressable RGB LEDs. Each array contains eight LEDs and is controlled independently by firmware through dedicated serial data connections. Figure 5 shows the schematic snippet for both LED arrays.

<img width="1321" height="395" alt="schematic_High_Power_LEDs" src="https://github.com/user-attachments/assets/1d1299eb-b3a5-4c46-820b-a9e48135607c" />

**Figure 5**

Addressable LEDs were selected because they integrate the LED drivers and communication interface into a single package. This significantly reduces component count and routing complexity compared to a discrete LED implementation, while providing individual control of the color and brightness of every LED. The resulting flexibility allows a single hardware platform to support head, tail, and ground light modes as well as brake, turn, and hazard indications entirely through firmware.

The arrays are powered directly from the regulated 4.0V supply and arranged as independent serial chains, allowing each array to operate independently when required. Each LED includes local bypass capacitance to reduce supply disturbances caused by rapid switching of the internal LED drivers.

### Control Domain

The Control Domain contains the circuitry responsible for sensing, computation, communications, persistent storage, and battery monitoring. Operating from the regulated 3.3V supply, it serves as the central coordination point for Reactor's electronic system.

At the center of the Control Domain is a multicore microcontroller that acquires sensor data, executes the control algorithms, manages wireless communications, stores configuration data, monitors battery condition, and generates the commands transmitted to the LED arrays. Supporting peripherals provide motion sensing, wireless connectivity, non-volatile storage, and battery measurement capabilities.

The following sections describe each subsystem in detail.

#### Microcontroller

The microcontroller serves as the central coordinator for Reactor's electronic system. It receives sensor data from the inertial measurement unit, processes rider input from the touch sensors, manages wireless communications, monitors battery condition, retrieves configuration data from non-volatile memory, and generates lighting commands for the LED arrays. Figure 6 shows the microcontroller and its supporting circuitry, including the external crystal oscillator and local decoupling network required for reliable operation.

<img width="603" height="632" alt="schematic_Control_Domain_MCU" src="https://github.com/user-attachments/assets/ece6e7aa-b6e8-4bd2-ad30-27eaa227fc2f" />

**Figure 6**

The Propeller P8X32A serves as the central controller for Reactor. The device provides eight independent processing cores that share access to memory and I/O resources, allowing sensing, communications, lighting control, and system management responsibilities to execute concurrently.

Unlike most modern microcontrollers, the Propeller provides only a minimal set of hardware peripherals. As a result, many low-level system functions were implemented directly in software. Communication interfaces, LED signaling, battery measurement, timing infrastructure, and subsystem coordination were all developed as bare-metal firmware components tailored to the requirements of the project.

This approach required a deeper understanding of both the hardware and software layers of the system, but it also provided complete control over timing behavior and resource allocation. The resulting architecture allowed motion sensing, wireless communications, power management, and lighting control to operate simultaneously while maintaining predictable system behavior.

---

