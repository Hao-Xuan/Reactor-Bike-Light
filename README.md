# Reactor Bike Light

## The Engineering Question
The Reactor Bike Light began with a simple engineering question:

**Can the natural motions of riding a bicycle serve as the controller for its lighting system?**

If the answer is yes, then the rider could spend less time operating the light and more time simply riding the bicycle. As the project evolved, the rest of the design began to organize itself around a simple principle: infer rider intent whenever it can be done reliably, and keep deliberate commands simple whenever it cannot. Answering that question ultimately required a complete lighting system capable of observing the ride, interpreting what it meant, and coordinating multiple forms of visual communication around the bicycle.

The result is Reactor.

## The System

A Reactor unit can operate in one of three roles relevant to rider visibility and awareness: a white head light to illuminate forward, a red tail light to illuminate rearward, or a programmable ground light to illuminate downard. Multiple units can be combined to create a complete lighting system distributed around the bicycle.

Because these lights work together to communicate rider intent, they must also share behavior. The Reactor mobile application coordinates configuration, monitoring, and control across multiple lights, allowing the rider to interact with the system as a whole rather than managing individual devices. The sections that follow describe the hardware, firmware, and mobile application that make this possible.

## The Hardware

Reactor's hardware was developed as a complete embedded product, with electronics, mechanical packaging, power management, sensing, rider input, and mounting designed together to create a compact, durable, and easy-to-use bicycle lighting system. The hardware is responsible for both observing the ride and providing a simple, predictable interface for the actions that only the rider can decide.

The resulting hardware combines a multicore microcontroller, inertial measurement sensors, touch controls, wireless communication, rechargeable battery power, high-power LED control, and a purpose-built enclosure into a single self-contained device. The sections that follow document the electrical, mechanical, and manufacturing decisions that transformed Reactor from an idea into a working product.

## The Firmware

The firmware is responsible for transforming raw sensor measurements into lighting behavior. Motion data from the bicycle is filtered, interpreted, and evaluated in real time to determine what the rider is doing and how the lighting system should respond. This is where Reactor's central design principle is implemented: infer rider intent whenever it can be done reliably, and defer to rider input when it cannot.

To support this behavior, the firmware combines sensor processing, state machines, LED control, touch input handling, wireless communication, and system coordination into a deterministic real-time control system. The sections that follow document the architecture, timing decisions, control logic, and engineering tradeoffs that allow Reactor to remain responsive and predictable while balancing reliability, computational cost, and real-time performance.

## The Mobile App

While routine interactions are designed to occur directly on the bicycle, some tasks are more naturally performed through a mobile device. The Reactor mobile application serves as the coordination and control layer for multiple Reactor units, allowing them to behave as a unified lighting system. The sections that follow document the communication architecture, user interface design, and engineering decisions behind the mobile application.

## The Past and The Future

---
