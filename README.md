# CPS IoT Self-Driving Competition — Team Autonomous Wolf

## Context

This repository documents the development of our autonomous driving algorithm for the CPS IoT Self-Driving Car Competition, using the Quanser QCar 2 platform in the virtual QLabs environment.

We are currently in the **virtual stage**, where the main objective is to validate our perception system and state estimation before moving to the full implementation of the autonomous navigation algorithm.

---

## Objective of the Current Milestone

In this initial phase, we focus on:

- Validating QCar sensor readings:
  - Lidar  
  - IMU  
  - Wheel encoder  
  - Depth camera  
  - RGB fisheye cameras  
- Implementing a bicycle kinematic model  
- Comparing different yaw (heading) estimation methods  
- Estimating vehicle pose using wheel odometry  

This step is essential to ensure reliable state estimation before implementing path planning and control strategies.

---

## Simulink Model Architecture

The model developed in MATLAB/Simulink includes the following components:

### 1. Sensor Acquisition Module

Real-time data is obtained from the QLabs environment:

- IMU → linear acceleration and angular velocity  
- Lidar → point cloud data  
- Encoder → wheel angular velocity  
- Cameras → visual perception  

---

### 2. Heading (Yaw) Estimation

Two methods are compared:

**Method 1 — IMU**

$$
\psi_{imu}(t) = \int \omega_z \, dt
$$

**Method 2 — Lidar**

Estimation based on environment geometry and alignment with map references.

The drift of the IMU-based heading is analyzed and compared with the geometric estimation from Lidar.

---

### 3. Bicycle Kinematic Model

The following model was implemented:

$$
\dot{x} = v \cos(\psi)
$$

$$
\dot{y} = v \sin(\psi)
$$

$$
\dot{\psi} = \frac{v}{L} \tan(\delta)
$$

Where:

- $v$ is the longitudinal velocity obtained from the encoder  
- $L$ is the wheelbase length  
- $\delta$ is the steering angle  
- $\psi$ is the heading angle  

This model allows the estimation of the vehicle pose $(x, y, \psi)$.

---

## Preliminary Results

- The IMU shows cumulative drift in heading estimation.  
- The Lidar-based estimation is more stable but depends on the environment structure.  
- Future sensor fusion will be necessary to improve robustness.  
- The bicycle model odometry can reconstruct consistent trajectories in controlled scenarios.

---

## Next Steps

- Implement sensor fusion (EKF or similar method)  
- Integrate map-based localization  
- Implement trajectory planning  
- Design a controller for autonomous taxi navigation  

---

## Current Status

- Sensor validation completed  
- Yaw estimation comparison completed  
- Bicycle kinematic model implemented  
- Pending: sensor fusion and control design  

---

## Tools Used

- MATLAB  
- Simulink  
- QLabs  
- Quanser QCar 2 platform  

---

## Competition

We participate in the CPS IoT Self-Driving Car Competition, where the final goal is to implement an autonomous taxi system capable of maximizing profit in both simulated and physical urban environments.



