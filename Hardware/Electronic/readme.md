**This section is still under construction. Please come back later to learn more about the design of Reactor's electronic system.**

# Hardware Overview

The Reactor Bike Light began as a new approach to bicycle ground effects lighting. Ground lights are already common on bicycles, but most existing systems are purely decorative. The original goal of this project was to create a ground light that could change color in reaction to the motion of the bicycle and communicate useful safety information to nearby traffic.

A key realization early in the project was that the same hardware could also serve as a head light or tail light. That decision transformed Reactor from a single-purpose device into a modular lighting platform and established many of the constraints that shaped the physical design. The hardware needed to accommodate sensing, communications, power, and mounting while operating in multiple lighting roles around the bicycle. Much of Reactor's hardware development can therefore be understood as the process of balancing those competing requirements within a single product.


## Electronic Architecture

Reactor's electronics are responsible for sensing the motion of the bicycle, processing rider input, controlling the lighting system, and coordinating communication with external devices. Although the system ultimately presents itself as a bicycle light, the underlying electronics more closely resemble a distributed embedded control system, combining sensing, computation, power management, wireless communication, and high-power LED control within a compact battery-powered device.

The architecture was developed around a simple principle: separate each major responsibility into an independent subsystem with a clearly defined role. This approach simplified both development and debugging while allowing individual portions of the hardware and firmware to evolve independently as the design matured. The following diagram represents this structure.

<img width="1006" height="852" alt="reactor_Electronics_Block_Diagram" src="https://github.com/user-attachments/assets/fee37ae8-e217-413f-afb5-abafc2e6bc7a" />


---

