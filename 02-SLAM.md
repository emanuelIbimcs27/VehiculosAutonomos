---
layout: default
title: CPS IoT Competition 2026
nav_order: 4
has_children: true
permalink: /CPS/
---

# Methodology for the Design and Validation of the Self-Driving Algorithm for the CPS IoT Competition 2026

## Introduction

The work presented in this section corresponds to the design, integration, and validation of an autonomous driving algorithm implemented in the **Quanser City** virtual environment using the **virtual QCar 2** within **QLabs**, with a main architecture developed in **MATLAB/Simulink**. The solution was conceived for the **CPS IoT Self-Driving Competition 2026**, taking the competition environment as its foundation and extending it with custom modules for path planning, visual perception, depth estimation, traffic-rule logic, and obstacle avoidance.

From the perspective of autonomous systems engineering, the vehicle was not treated as a simple trajectory-following block, but rather as a hierarchical architecture composed of multiple functional layers. First, it was necessary to define the parametrization of the virtual vehicle and the timing conditions under which each subsystem would operate. Next, a global trajectory planning strategy based on directed graphs and road-related penalties was designed. On top of this foundation, a visual perception system was incorporated using a neural network specifically trained to detect objects present in the Quanser City environment. Finally, spatial interpretation and decision-making modules were added so that the vehicle could react to traffic signs and obstacles.

One of the most important contributions of the project was the design of a hybrid pipeline between Simulink and Python. Simulink was used as the core environment for integration and control, while Python operated as an external inference service for the neural network exported to ONNX. Thanks to this strategy, the system was able to receive images from the virtual environment, detect relevant objects, estimate their distances, and modify the vehicle’s speed and steering in real time.

---

## General architecture of the solution

The implemented solution was structured into several functional levels that operate in a coordinated manner. At the first level is the **vehicle parametrization**, where sampling times, control gains, environment configurations, and geometric parameters are defined. At the second level is the **global planning** module, responsible for computing an optimal trajectory between an initial node and a target node on the competition map. At the third level lies the **visual perception** module, implemented using a YOLOv8 neural network trained to recognize objects in the environment. At the fourth level is the **depth estimation** stage, whose objective is to transform each two-dimensional detection into a detection with spatial meaning. Finally, at the fifth level is the **decision-making** stage, where behavioral rules in response to signs and obstacles are implemented.

This architecture can be conceptually represented as the following processing pipeline:

$$
\text{Map} \rightarrow \text{Planning} \rightarrow \text{Perception} \rightarrow \text{Depth} \rightarrow \text{Decision} \rightarrow \text{Control}
$$

From the point of view of autonomous navigation, this decomposition is important because it clearly separates three fundamental questions of the problem. Planning answers **where the vehicle should go**. Perception answers **what is present in the environment**. Decision logic answers **what the vehicle should do based on what it perceives**. This modular structure facilitates the individual validation of each component and strengthens the overall robustness of the system.