# Reactor Bike Light

## The Engineering Question
This project began with a simple engineering question:

**Can the natural motions of riding a bicycle serve as the controller for its lighting system?**

If the answer is yes, then many user interactions could be eliminated. Brake lights, turn signals, hazard flashers, and other color changes could occur automatically, allowing the rider to focus on simply riding the bicycle. The project therefore evolved around a simple principle: infer rider intent whenever it can be done reliably, and keep deliberate commands simple whenever it cannot.

The result is the Reactor Bike Light.

## The System

A Reactor unit can operate in one of three roles relevant to rider visibility and awareness: a white head light to illuminate forward, a red tail light to illuminate rearward, or a color-changing ground light to illuminate downard. Multiple units can be combined to create a complete lighting system distributed around the bicycle.

Because these lights work together to communicate rider intent, they must also share behavior. The Reactor mobile application coordinates configuration, monitoring, and control across multiple lights, allowing the rider to interact with the system as a whole rather than managing individual devices. The sections that follow describe the hardware, firmware, and mobile application that make this possible.

## The Hardware

Reactor's hardware was developed as a complete embedded product, with electronics, mechanical packaging, power management, sensing, rider input, and mounting designed together to create a compact, durable, and easy-to-use bicycle lighting system. The hardware is responsible for both observing the ride and providing a simple, predictable interface for the actions that only the rider can decide.

The resulting hardware combines a multicore microcontroller, inertial measurement sensors, touch controls, wireless communication, rechargeable battery power, high-power LED control, and a purpose-built enclosure into a single self-contained device. Follow the link to see the electrical, mechanical, and manufacturing decisions that transformed Reactor from an idea into a working product.

[Click for Hardware Details](https://github.com/Hao-Xuan/Reactor-Bike-Light/tree/main/Hardware)

## The Software

Reactor's software is divided into two closely integrated components: the embedded firmware running on each Reactor unit and the companion mobile application used to configure and coordinate the lighting system. Together they transform the hardware into a responsive, connected product that can infer rider intent, communicate with external devices, and provide a consistent user experience across multiple lights.

The embedded firmware performs the real-time responsibilities of the system. It acquires sensor data, interprets rider motion, manages wireless communication, controls the LED arrays, and coordinates every aspect of device operation. Built around deterministic control logic, the firmware implements Reactor's central design principle: infer rider intent whenever it can be done reliably, and defer to deliberate rider input when it cannot.

The companion mobile application provides the higher-level interface for configuration, monitoring, and system management. It allows multiple Reactor units to behave as a coordinated lighting system while giving riders access to operating modes, battery status, customization options, and crash notifications that would be impractical to manage directly from the device itself.

Follow the link below to explore the software architecture, including the embedded firmware and companion mobile application.

[Click for Software Details](https://github.com/Hao-Xuan/Reactor-Bike-Light/tree/main/Software)

## The Past and The Future

---
