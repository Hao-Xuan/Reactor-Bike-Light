**This section is still under construction. Please come back later to learn more about the design of Reactor's electronic system.**

# Electronics

---
## Architecture Summary

The architecture of Reactor's electronic system was developed to support three primary responsibilities: sensing the motion of the bicycle, controlling the lighting system in real time, and communicating with external devices. These responsibilities place very different demands on the hardware. Motion sensing requires clean power and reliable timing. Wireless communication requires its own dedicated radio subsystem. High-power LED operation requires significantly more energy than the rest of the electronics combined.

To accommodate these competing requirements, the system was divided into a collection of functional subsystems organized around several independent power domains. This approach simplified development and debugging while allowing sensing, communications, control, and lighting hardware to evolve independently as the design matured. It also provided a foundation for Reactor's low-power operating modes by allowing portions of the system to remain active only when required.

The block diagram below provides a high-level view of the electronic architecture and the relationships between its major subsystems.

<img width="1006" height="852" alt="reactor_Electronics_Block_Diagram" src="https://github.com/user-attachments/assets/fee37ae8-e217-413f-afb5-abafc2e6bc7a" />

**Figure 1**

### Power Source

The Power Source block consists of a removable lithium-ion battery and the circuitry required to safely interface that battery to the rest of the system. The removable battery design allows riders to quickly replace depleted cells and continue riding without waiting for a recharge cycle. Input protection circuitry guards the electronics against common fault conditions and provides a stable entry point for power distribution throughout the device.

### Always-On Domain

The Always-On Domain provides the minimum circuitry required to monitor rider input and initiate system startup. It remains powered whenever a battery is present and operates independently of the rest of the electronics. This arrangement allows Reactor to remain responsive while minimizing standby power consumption, since the lighting system and control electronics only need to be energized when the rider requests them.

### High-Power Domain

The High-Power Domain serves as the primary operating power domain for Reactor. Once activated by the Always-On Domain, it supplies power to the lighting system and to the control electronics responsible for sensing, communications, and system coordination. This arrangement allows the majority of the hardware to remain completely unpowered when the system is inactive, while still supporting rapid startup when rider input is detected.

### Control Domain

The Control Domain contains the circuitry responsible for sensing, computation, communications, data storage, battery monitoring, and system coordination. It receives power from the High-Power Domain and remains active only while the lighting system is operating. This arrangement allows the control electronics to benefit from a stable regulated supply while ensuring that they consume no power when the system is inactive.

---
## Domain Details

### Power Source

The Power Source block provides energy to the entire system and protects downstream electronics from battery-related fault conditions. All power enters the PCB from a removable lithium-ion battery and passes through a small protection stage before reaching the remainder of the system. Figure 2 shows the schematic snippet for these two sub-systems.

<img width="480" height="427" alt="schematic_Power_Source" src="https://github.com/user-attachments/assets/ee1f9e37-4337-4eba-8f65-4d4c461ac154" />

**Figure 2**

#### Removable Li-ion Battery

Reactor is powered by a single rechargeable lithium-ion cell in the 18650 form factor. The 18650 was selected for its combination of energy density, availability, low cost, and well-established ecosystem of chargers and replacement cells.

A removable battery was chosen instead of an integrated rechargeable pack to improve usability during normal operation. Riders can carry spare cells and replace a depleted battery in seconds rather than waiting for the device to recharge. This approach also simplifies long-term maintenance, since battery capacity naturally degrades over time and replacement does not require disassembling the electronics.

The dimensions of the battery became one of the primary drivers of the mechanical design. The size of the cell established the minimum cross-sectional size of the enclosure and strongly influenced the overall form factor, mounting architecture, and battery access mechanism described elsewhere in this documentation.

#### PCB Input Protection

The PCB Input Protection subsystem forms the interface between the removable battery and the rest of Reactor's electronics. Because Reactor uses removable batteries, incorrect installation must be considered a normal operating scenario rather than an exceptional event.

Battery voltage enters the system through the **VBAT** node. A transient voltage suppression diode protects the circuit from electrostatic discharges that may occur during battery insertion or other electrical disturbances. A power MOSFET configured for reverse-polarity protection prevents damage if a battery is installed incorrectly while introducing only a minimal voltage drop during normal operation.

The protected output of this stage appears at **VIN**, which serves as the entry point for the remainder of Reactor's power distribution system.

### Always-On Domain

The Always-On Domain provides the circuitry required for Reactor to remain responsive while inactive. Unlike the remainder of the system, which is completely powered down when the bike light is off, the Always-On Domain remains active whenever a battery is installed. Its primary responsibility is to monitor rider input and determine when the system should transition from standby into normal operation. Figure 3 shows the schematic snippet for the Always-On Domain

<img width="1235" height="504" alt="schematic_Always_On" src="https://github.com/user-attachments/assets/bab3b0bf-8429-4055-86c8-f4fe9804b0a4" />

The Always-On Domain consists of two primary subsystems: the touch sensing circuitry used to detect rider input and the wakeup logic responsible for enabling the rest of the electronic system.

#### Dual Touch Sensors

Rider input is detected by dual sensing pads integrated into the left and right sides of the PCB and bonded to the inside of the mechanical enclosure. Each pad is continuously monitored by a dedicated touch controller IC which produces a digital output when a touch is detected. These outputs appear as the **TOUCH_A** and **TOUCH_B** signals, which are used by the Always-On Domain to initiate system startup and later by firmware to interpret rider commands.

Capacitive sensing was selected because it provides a sealed user interface with no mechanical buttons or switches. This improves durability in outdoor environments and eliminates openings that would otherwise complicate weather resistance.

#### Wakeup Logic

The Wakeup Logic subsystem controls the transition between Reactor's standby and operating states.

A simultaneous touch on both sensing pads generates the **4V_EN** signal, enabling the High-Power Domain. Requiring both sensors to be activated reduces the likelihood of accidental startup while still allowing the rider to power the system on with a simple gesture. Once the system has started, control of the power state is transferred to firmware through the **POWER_EN** signal. This allows the microcontroller to keep the system powered after the original touch event has ended and later return the device to standby when appropriate.

By separating wakeup detection from normal operation, Reactor remains responsive while consuming very little power when inactive. The rider experiences immediate startup, while the majority of the electronics remain unpowered until needed.

---

