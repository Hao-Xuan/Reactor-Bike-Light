# Software

The Reactor software transforms the hardware into an intelligent lighting system capable of responding automatically to the motion of the bicycle. It combines real-time embedded control with a companion mobile application to provide sensing, communications, configuration, and system management across one or more Reactor units.

The embedded firmware performs the time-critical responsibilities of the system. It acquires motion data, processes rider input, controls the LED arrays, manages power, and coordinates wireless communication while maintaining deterministic real-time behavior. The firmware is responsible for implementing Reactor's central design principle: infer rider intent whenever it can be done reliably, and defer to deliberate rider input whenever it cannot.

The companion mobile application provides the higher-level interface for configuration, monitoring, and multi-device coordination. It allows riders to customize operating behavior, monitor battery status, receive crash notifications, and manage multiple Reactor units as a single integrated lighting system.

The following sections describe these software components in detail.

---

## Device Firmware

The firmware documentation describes the embedded architecture, task organization, sensor processing pipeline, state machines, communications infrastructure, and the engineering decisions that allow Reactor to respond predictably in real time.

**[Click Here for Firmware Details](https://github.com/Hao-Xuan/Reactor-Bike-Light/tree/main/Software/Device%20Firmware)**

---

## Mobile Application

The mobile application documentation describes the Bluetooth communication architecture, user interface, configuration system, and the software design decisions that provide a simple interface between the rider and the Reactor lighting system.

**[Click Here for Mobile App Details](https://github.com/Hao-Xuan/Reactor-Bike-Light/tree/main/Software/Mobile%20App)**
