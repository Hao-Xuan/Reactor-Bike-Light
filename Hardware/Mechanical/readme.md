**This section is still under construction. Please come back later to learn more about Reactor's hardware design.**

# Hardware Overview

The Reactor Bike Light began as a new approach to bicycle ground effects lighting. Ground lights are already common on bicycles, but most existing systems are purely decorative. The original goal of this project was to create a ground light that could change color in reaction to the motion of the bicycle and communicate useful safety information to nearby traffic.

A key realization early in the project was that the same hardware could also serve as a head light or tail light. That decision transformed Reactor from a single-purpose device into a modular lighting platform and established many of the constraints that shaped the physical design. The hardware needed to accommodate sensing, communications, power, and mounting while operating in multiple lighting roles around the bicycle. Much of Reactor's hardware development can therefore be understood as the process of balancing those competing requirements within a single product.

---
## Form Factor Constraints

The design of the physical device was driven by a number of competing requirements. Reactor needed to function as a head light, tail light, or ground light depending on where it was mounted. It needed to remain visible from multiple directions, withstand outdoor use, support wireless communication and motion sensing, provide convenient battery replacement, and mount securely to several different parts of a bicycle without requiring tools.

As a result, the final form factor emerged gradually through prototyping and testing rather than being defined at the beginning of the project. The sections below describe several of the major constraints that shaped the enclosure and overall hardware architecture.

### Replaceable Power

A major constraint was the requirement for a removable power source capable of running the light for several hours. A rechargeable lithium-ion cell in the 18650 form factor was chosen for its balance of capacity and compactness, and that decision heavily influenced the overall size and shape of the enclosure.

### Optical Separation

Early field testing revealed the need for spatial separation between the left and right LED arrays. Without sufficient dark space, it was difficult to distinguish them as separate light sources, making the standard turn signal pattern ambiguous beyond a few meters. At the same time, excessive separation was detrimental to the goal of illuminating the forward path in head light mode.

### Multiple Lighting Roles

Reactor was designed to operate as a head light, tail light, or ground light depending on where it was mounted. Supporting those roles introduced a range of mounting constraints. Head tubes, down tubes, and seat posts vary significantly in size and orientation, often even on the same bicycle, requiring a highly adaptible mounting system.

While the tail and ground light roles are relatively tolerant of mounting angle, the head light must illuminate the ground in front of the bicycle. Because head tubes are typically angled upward, the mounting system needed a way to rotate the light into a downward orientation.

### Rider Interaction

Although Reactor is designed to infer rider intent whenever possible, some actions still require deliberate input. Turn signals, hazard flashers, and certain configuration tasks must remain available while the bicycle is in use. Those controls therefore needed to be easy to locate and operate in the dark without requiring the rider to divert significant attention away from the ride itself.

### Manufacturability

Every design decision was evaluated in terms of both functionality and manufacturability. Reactor's mechanical components were designed with eventual factory production in mind, incorporating considerations such as draft, wall thickness, fillets, and assembly from the earliest revisions. Simultaneously, the system of parts was simplified wherever possible to make prototyping, assembly, and iteration practical. Many otherwise attractive solutions were discarded because they increased part count, assembly complexity, or manufacturing cost without providing sufficient benefit.

---
## Mechanical Architecture

The final enclosure emerged as a compromise between the competing requirements described in the previous section. Many visible features of the design perform multiple functions simultaneously, balancing power, visibility, mounting, rider interaction, and manufacturability within a single form factor.

The sections below describe the major mechanical subsystems and the role each plays within the overall design.

### Central Battery Spine

### LED Array Placement

### Rider Controls

### Mounting System

### Design for Assembly

---

