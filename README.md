# Reactor Bike Light

## The Engineering Question
This project began with a simple engineering question:

**Can the natural motions of riding a bicycle serve as the controller for its lighting system?**

If the answer is yes, then many user interactions could be eliminated. Brake lights, turn signals, hazard flashers, and other color changes could occur automatically, allowing the rider to focus on simply riding the bicycle. The project therefore evolved around a simple principle: infer rider intent whenever it can be done reliably, and keep deliberate commands simple whenever it cannot.

The result is the Reactor Bike Light.

## The System

A Reactor unit can operate in one of three roles relevant to rider visibility and awareness: a white head light to illuminate forward, a red tail light to illuminate rearward, or a color-changing ground light to illuminate downard. Multiple units can be combined to create a complete lighting system distributed around the bicycle.

Because these lights work together to communicate rider intent, they must also share behavior. The Reactor mobile application coordinates configuration, monitoring, and control across multiple lights, allowing the rider to interact with the system as a whole rather than managing individual devices. The sections that follow describe the hardware, firmware, and mobile application that make this possible.

## Hardware

The Reactor Bike Light began as a new approach to bicycle ground-effect lighting. While ground lights are common on bicycles, most existing systems are purely decorative. Reactor was designed to use motion sensing to transform ground lighting into an active safety feature, automatically communicating rider intent through changes in color and lighting behavior.

Early in development, it became clear that the same hardware could also operate as a head light or tail light. That realization transformed Reactor from a single-purpose device into a modular lighting platform and established many of the constraints that shaped its design. The electronics, enclosure, optics, power system, rider interface, and mounting hardware were all developed together to support multiple operating roles within a single compact product.

The resulting hardware consists of two closely integrated systems: the electronic hardware that senses, processes, communicates, and controls the lighting system, and the mechanical hardware that packages these functions into a durable, weather-resistant product suitable for everyday use.

The following sections describe these systems in detail.

### Electronic Hardware

The electronic design includes power management, motion sensing, embedded processing, wireless communication, persistent storage, battery monitoring, and individually addressable LED control. Together, these subsystems provide the foundation that allows Reactor to interpret rider behavior and produce responsive lighting effects.

**[Click Here for Electronics Details](https://github.com/Hao-Xuan/Reactor-Bike-Light/tree/main/Hardware/Electronic)**

### Mechanical Hardware

The mechanical design integrates the enclosure, optics, battery access, rider interface, and mounting system into a compact assembly that protects the electronics while supporting the lighting system's multiple operating modes. Particular attention was given to manufacturability, durability, and ease of use during everyday riding.

**[Click Here for Mechanical Details](https://github.com/Hao-Xuan/Reactor-Bike-Light/tree/main/

## Software
The Reactor software transforms the hardware into an intelligent lighting system capable of responding automatically to the motion of the bicycle. It combines real-time embedded control with a companion mobile application to provide sensing, communications, configuration, and system management across one or more Reactor units.

The embedded firmware performs the time-critical responsibilities of the system. It acquires motion data, processes rider input, controls the LED arrays, manages power, and coordinates wireless communication while maintaining deterministic real-time behavior. The firmware is responsible for implementing Reactor's central design principle: infer rider intent whenever it can be done reliably, and defer to deliberate rider input whenever it cannot.

The companion mobile application provides the higher-level interface for configuration, monitoring, and multi-device coordination. It allows riders to customize operating behavior, monitor battery status, send crash notifications, and manage multiple Reactor units as a single integrated lighting system.

The following sections describe these software components in detail.

### Device Firmware

The firmware documentation describes the embedded architecture, task organization, sensor processing pipeline, state machines, communications infrastructure, and the engineering decisions that allow Reactor to respond predictably in real time.

**[Click Here for Firmware Details](https://github.com/Hao-Xuan/Reactor-Bike-Light/tree/main/Software/Device%20Firmware)**

### Mobile Application

The mobile application documentation describes the Bluetooth communication architecture, user interface, configuration system, and the software design decisions that provide a simple interface between the rider and the Reactor lighting system.

**[Click Here for Mobile App Details](https://github.com/Hao-Xuan/Reactor-Bike-Light/tree/main/Software/Mobile%20App)**

## The Past and The Future

---
