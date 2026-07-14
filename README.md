# Reactor Bike Light

## The Engineering Question

This project began with a simple engineering question:

**Can the natural motions of riding a bicycle serve as the controller for its lighting system?**

If the answer is yes, many rider interactions can be eliminated. Brake lights, turn signals, hazard flashers, and other lighting changes can occur automatically, allowing the rider to focus on riding rather than operating the lighting system. The project therefore evolved around a simple design principle: **infer rider intent whenever it can be done reliably, and keep deliberate commands simple whenever it cannot.**

The result is the **Reactor Bike Light**.

## The System

A Reactor unit can operate in one of three lighting roles: a white head light, a red tail light, or a color-changing ground light. Multiple units can be combined to create a coordinated lighting system distributed around the bicycle.

Each unit continuously monitors bicycle motion, communicates with companion devices, and reacts automatically to changes in rider behavior. A companion mobile application provides configuration, monitoring, and coordination across multiple Reactor units, allowing the rider to interact with the lighting system as a whole rather than managing individual lights.

The following documentation describes the four major engineering disciplines involved in the project.

### Electronics

The electronics integrate power management, motion sensing, embedded processing, wireless communication, persistent storage, battery monitoring, and individually addressable LED control into a compact multilayer PCB. Together these subsystems provide the foundation that allows Reactor to observe rider behavior and generate responsive lighting effects.

**[Click Here for Electronics Details](https://github.com/Hao-Xuan/Reactor-Bike-Light/tree/main/Electronics)**

### Mechanical

The mechanical design packages the electronics into a compact, weather-resistant enclosure while providing battery access, optical control, rider interaction, and a universal silicone mounting system. Particular attention was given to manufacturability, durability, thermal performance, and ease of everyday use.

**[Click Here for Mechanical Details](https://github.com/Hao-Xuan/Reactor-Bike-Light/tree/main/Mechanical)**

### Firmware

The embedded firmware transforms raw sensor measurements into lighting behavior. It performs sensor acquisition, signal processing, real-time control, wireless communication, power management, and LED rendering while maintaining deterministic system behavior. The firmware implements Reactor's central design principle by automatically inferring rider intent whenever it can be done reliably.

**[Click Here for Firmware Details](https://github.com/Hao-Xuan/Reactor-Bike-Light/tree/main/Firmware)**

### Mobile

The companion mobile application provides the interface between the rider and the lighting system. It allows multiple Reactor units to operate as a coordinated platform while providing configuration, battery monitoring, crash notifications, and customization features that would be impractical to manage directly from the device itself.

**[Click Here for Mobile Details](https://github.com/Hao-Xuan/Reactor-Bike-Light/tree/main/Mobile)**

## Future Work
This section is still under construction. Please come back later to learn more about the future of the Reactor Bike Light.

---
