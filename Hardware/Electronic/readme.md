**This section is still under construction. Please come back later to learn more about the design of Reactor's electronic system.**

# Electronics

---
## Architecture Summary

The architecture of Reactor's electronic system was developed to support three primary responsibilities: sensing the motion of the bicycle, controlling the lighting system in real time, and communicating with external devices. These responsibilities place very different demands on the hardware. Motion sensing requires clean power and reliable timing. Wireless communication requires its own dedicated radio subsystem. High-power LED operation requires significantly more energy than the rest of the electronics combined.

To accommodate these competing requirements, the system was divided into a collection of functional subsystems organized around several independent power domains. This approach simplified development and debugging while allowing sensing, communications, control, and lighting hardware to evolve independently as the design matured. It also provided a foundation for Reactor's low-power operating modes by allowing portions of the system to remain active only when required.

The block diagram below provides a high-level view of the electronic architecture and the relationships between its major subsystems.

<img width="1006" height="852" alt="reactor_Electronics_Block_Diagram" src="https://github.com/user-attachments/assets/fee37ae8-e217-413f-afb5-abafc2e6bc7a" />

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

---

