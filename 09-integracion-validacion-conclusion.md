---
layout: default
title: Integration, Validation, and Conclusion
nav_order: 7
parent: CPS IoT Competition 2026
permalink: /CPS/integracion-validacion-conclusion/
---

# Integration, Validation, and Conclusion

## 8. Functional integration of the complete system

Once all the modules described in the previous sections had been developed and incorporated, the final self-driving system was constituted as a hierarchical functional architecture capable of performing autonomous navigation within the virtual competition environment. This integration did not consist merely of gathering several independent scripts, but of articulating a coherent processing chain in which each block contributes a specific function within the overall behavior of the vehicle.

From an engineering standpoint, the value of integration lies in the fact that the system should no longer be analyzed as a set of isolated components, but rather as a continuous flow of information and decision-making. Global planning provides the nominal route; visual perception detects relevant objects in the environment; depth estimation adds geometric meaning to those detections; traffic-rule and safety logic interprets the road context; and finally the vehicle modifies its speed and steering according to that entire set of information.

In general terms, the integrated architecture can be summarized as a functional chain of the form:

$$
\text{Map} \rightarrow \text{Planning} \rightarrow \text{Perception} \rightarrow \text{Depth} \rightarrow \text{Decision} \rightarrow \text{Control}
$$

However, once the advanced layers of the project were incorporated, this structure became even richer, since the decision stage no longer considers only basic traffic signs, but also turn signals, traffic lights, pedestrians, passenger pickup, and robust safety braking.

### 8.1 Integration of the base pipeline

The main system flow first relies on the global trajectory computed over the map graph. If the optimal trajectory is denoted by $P^\star$, then it is obtained by solving:

$$
P^\star = \arg\min_{P \in \mathcal{P}(s,g)} \sum_{(i,j)\in P} \left(d_{ij} + p_{ij}\right)
$$

where:

- $s$ is the initial node,
- $g$ is the goal node,
- $d_{ij}$ is the geometric distance between nodes,
- $p_{ij}$ is the penalty associated with road complexity.

The output of this module is not used in discrete form, but is instead smoothed through PCHIP interpolation in order to obtain a continuous reference:

$$
x_s(\tau)=\operatorname{PCHIP}(t_k,x_k), \qquad
y_s(\tau)=\operatorname{PCHIP}(t_k,y_k)
$$

This smoothed trajectory represents the nominal path that the vehicle must follow as long as no event in the environment forces it to modify it.

### 8.2 Integration of visual perception with the trajectory

In parallel with trajectory tracking, the system receives images from the virtual environment through Simulink and sends them to Python in order to run inference with the YOLOv8 model exported to ONNX. The detector produces a structure of up to ten objects per frame, each described as:

$$
\mathbf{d}_i =
\begin{bmatrix}
c_i \\
\rho_i \\
x_{1,i} \\
y_{1,i} \\
x_{2,i} \\
y_{2,i}
\end{bmatrix}
$$

This representation constitutes the basic output of the perception module. However, it is still not sufficient for navigation decisions, since the vehicle needs to know not only what object it is seeing, but also how far away it is.

For that reason, the detector output passes through the `addDepth` function, where it is transformed into an enriched representation:

$$
\mathbf{o}_i =
\begin{bmatrix}
c_i \\
\rho_i \\
x_{1,i} \\
y_{1,i} \\
x_{2,i} \\
y_{2,i} \\
\hat{z}_i
\end{bmatrix}
$$

where $\hat{z}_i$ is the estimated depth of the object. This transition is key because it transforms visual perception into operational spatial perception.

### 8.3 Integration of rule-based traffic logic

Once the detections have been enriched with depth, the system can apply road logic to them. In a first layer, functions such as `stopLogic` are found, which are responsible for modifying vehicle speed in response to basic traffic signs such as STOP, YIELD, and roundabout signs.

In a general form, this stage can be described as a transformation of the nominal speed:

$$
v_{out}(t) = f(v_{in}(t), \mathbf{o}_i, t)
$$

where the output depends both on the type of detected object and on its distance, relative position, and temporal context. For example, the detection of a STOP sign generates a five-second stopping window, whereas a roundabout sign only causes a speed reduction.

This logic constitutes the first layer of environment interpretation and allows the vehicle to respond coherently according to basic traffic rules.

### 8.4 Integration of local obstacle avoidance

In addition to traffic signs, the system must react to physical obstacles, such as the cone placed in the competition environment. To achieve this, the `avoidCone` function temporarily modifies the nominal vehicle steering through a sinusoidal law:

$$
\delta_{avoid}(t) = A \sin\left(\frac{2\pi (t-t_0)}{T_{total}}\right)
$$

where:

- $A$ is the maximum steering amplitude,
- $T_{total}$ is the total duration of the maneuver,
- $t_0$ is the activation instant of the avoidance maneuver.

The final steering is then expressed as:

$$
\delta_{out}(t) =
\begin{cases}
\delta_{avoid}(t), & \text{if avoidance is active} \\
\delta_{in}(t), & \text{otherwise}
\end{cases}
$$

This module is integrated on top of the nominal trajectory without the need to recompute the entire global path. In architectural terms, this is important because it demonstrates that the system can solve local events reactively without compromising the overall planning.

### 8.5 Integration of road behavior through turn signals

Once the smoothed global trajectory has been generated, specific segments were also defined where the vehicle must activate its turn signals. This was achieved by projecting maneuver rules between nodes onto specific indices of the interpolated trajectory.

If the smoothed trajectory is denoted by $\mathcal{P}$, then the sets:

$$
\mathcal{S}_{izq} = \{[a_1,b_1], [a_2,b_2], \dots\}
$$

$$
\mathcal{S}_{der} = \{[c_1,d_1], [c_2,d_2], \dots\}
$$

represent the trajectory intervals where the left and right turn signals must be activated, respectively.

This module is important because it adds a layer of expressive road behavior to the system. That is, the vehicle not only follows a route and avoids obstacles, but also visually communicates its turning maneuvers according to predefined rules over the topology of the map.

### 8.6 Integration of the dynamic environment in QLabs

All the previous modules are validated within a programmatically generated environment in QLabs. In this environment, the following are integrated:

- the physical map of the circuit,
- the walls and boundaries,
- traffic signs,
- crosswalks,
- dynamic traffic lights,
- a static person for pickup simulation,
- a dynamic pedestrian crossing a crosswalk,
- a cone as a competition obstacle.

This means that the self-driving architecture is not evaluated in an abstract or idealized world, but in a scenario with dynamic events and relevant signals that demand contextual reactions. From the validation standpoint, this environment is indispensable because it provides the physical stimuli upon which the perception and decision modules are tested.

### 8.7 Integration of advanced traffic and safety logic

In the final development stage, the basic logic was extended through the `trafficSignsLogic` function, which integrates into a single decision layer:

- STOP,
- YIELD,
- roundabout,
- traffic lights,
- pickup person,
- and an external pedestrian braking flag.

Additionally, `pedestrianStopLogic` was developed, whose purpose is to act as an immediate frontal safety layer based on visual detection, depth analysis, and a logic with temporal hysteresis.

This introduces a very important control hierarchy. Immediate safety dominates over rule-based traffic logic. In terms of priority, the final architecture can be understood as follows:

$$
\text{Immediate frontal safety} \;>\; \text{Rule-based traffic logic} \;>\; \text{Nominal trajectory tracking}
$$

This decision is correct from the standpoint of autonomous vehicle design, since an obstacle or pedestrian in front of the vehicle must have absolute priority over any other operational consideration.

---

## 9. General system validation

System validation was carried out in a modular and integral way. This means that not only the final behavior of the vehicle was evaluated, but also the individual performance of each subsystem, in order to guarantee that the complete integration was supported by previously verified components.

### 9.1 Validation of the planning module

Global planning was validated by observing that the trajectory generated from the graph was coherent with the topology of the map and with the road constraints introduced through penalties. In particular, it was verified that:

- the optimal route correctly connected the initial node and the goal node,
- the selected path avoided unnecessarily costly segments from an operational standpoint,
- the correction of intersections through the auxiliary node improved the local geometry of certain crossings,
- PCHIP interpolation produced a continuous curve that was physically trackable by the vehicle.

Visual validation through the final trajectory plot was especially important, since it made it possible to verify that the generated red curve matched the useful geometry of the circuit and preserved continuity in critical areas.

### 9.2 Validation of the perception module

The object detector was validated both quantitatively and qualitatively. Quantitatively, metrics such as the following were analyzed:

- $mAP_{50}$,
- $mAP_{50:95}$,
- precision,
- recall.

These metrics made it possible to verify that the trained model was capable of recognizing relevant objects in the environment with sufficiently solid performance for the competition context.

Qualitatively, it was verified that the model exported to ONNX continued to detect correctly on images from the test set and later within the flow connected to Simulink. This step was very important, since it guaranteed that the model behavior was preserved during deployment and not only during training.

### 9.3 Validation of the depth module

The `addDepth` function was validated by checking that the distances assigned to the detections were consistent with the physical region observed in the environment. It was verified that:

- the bounding box was properly cropped within the valid image limits,
- the depth region associated with the object excluded invalid values,
- the median of the region provided a stable depth estimate,
- the sentinel value 999 was assigned only when depth could not be measured reliably.

This validation was important because all subsequent logic depends directly on the reliability of $\hat{z}_i$.

### 9.4 Validation of the basic sign and avoidance logic

The `stopLogic` and `avoidCone` functions were validated by observing that:

- the vehicle stopped correctly for 5 seconds when facing a STOP sign,
- it performed a brief pause when facing a YIELD sign,
- it reduced speed when approaching roundabouts,
- it activated the sinusoidal avoidance maneuver when a cone was within the specified threshold.

Here, temporal validation was especially relevant, since the correct duration of the maneuvers was as important as their activation.

### 9.5 Validation of the turn signals

The turn signal system was validated by projecting the node-based rules onto the smoothed trajectory and visually verifying that the green and red segments coincided with the correct areas of the map.

This validation made it possible to confirm that:

- turning maneuvers were correctly identified,
- the central auxiliary node improved the representation of left crossings,
- turn signal activation covered the entire maneuver segment and not just an isolated point.

### 9.6 Validation of the dynamic environment in QLabs

The scenario generation script was validated by verifying that all actors and environment elements appeared correctly positioned and behaved as expected. In particular, it was verified that:

- the QCar spawned at the selected position,
- the static person appeared on the sidewalk,
- the dynamic pedestrian repeatedly crossed the crosswalk,
- the cone was placed in the intended position,
- the traffic lights changed state according to the programmed cycle.

This was fundamental, since without a reproducible environment it would not be possible to validate the rest of the system consistently.

### 9.7 Validation of the advanced traffic and safety logic

The final validation layer consisted of observing the behavior of the complete system under combined events. This included checking that:

- `trafficSignsLogic` correctly integrated traffic signs, traffic lights, and pickup behavior,
- the vehicle committed to crossing the intersection only when the traffic light was stably green,
- the pickup routine was executed as a temporal sequence of approach and stop,
- `pedestrianStopLogic` activated braking only after several consistent frames,
- braking was also released with hysteresis, avoiding rapid oscillations.

At this stage, the complete hierarchical logic of the system was validated.

---

## 10. Technical discussion of the integrated system

The developed system demonstrates that a well-designed modular architecture makes it possible to build a more complex self-driving behavior without losing traceability or control over each component. Each module was added on top of a previously validated foundation, which made it possible to scale the system in an orderly way.

From the functional standpoint, the project evolved from a simple trajectory follower into a more complete autonomous agent. Initially, the main reference consisted only of the computed route. Later, rule-based signs were added, then local obstacles, then turn signals, and finally advanced layers of safety and road context. This progression shows that the architecture was correctly designed to support incremental growth.

Another important aspect is that the system is not limited to a single form of intelligence. It combines:

- **algorithmic planning**, through graphs and shortest path;
- **deep-learning-based perception**, through YOLOv8;
- **geometric estimation**, through depth;
- **symbolic logic**, through rules and state machines;
- **reactive safety**, through hysteresis and frontal gating.

It is precisely this combination of approaches that makes the system technically valuable and worthy of being presented in the context of a self-driving competition.

---