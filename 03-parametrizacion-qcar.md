---
layout: default
title: Parameterization of the QCar 2 Virtual
nav_order: 1
parent: CPS IoT Competition 2026
permalink: /CPS/parametrizacion-qcar/
---

# Virtual QCar 2 Parametrization

## 1. Virtual QCar 2 Parametrization and Environment Definition

The first stage of the development consisted of configuring the virtual vehicle and all the base parameters of the stack. For this purpose, an initialization script in MATLAB was used, where the map type, the QCar type, the sampling times of each subsystem, the steering controller gains, the estimation parameters, and the calibration files are defined.

This stage is fundamental because, before the vehicle can plan, perceive, or make decisions, there must be a consistent foundation on which the entire system operates. In a simulation environment such as QLabs, an incorrect definition of sampling times, gains, or geometric references can lead to unstable behavior, synchronization errors, or inconsistent controller responses. For this reason, QCar parametrization constitutes the starting point of the entire self-driving architecture.

### 1.1 Definition of the map type and vehicle type

```matlab
clear all;

%% User configurable parameters
map_type = 1;
qcar_types = 1;
````

In this block, two fundamental parameters are defined. The first one, `map_type = 1`, indicates that the large SDCS map is being used. The second one, `qcar_types = 1`, selects the configuration corresponding to the **virtual QCar**. This detail is important because the same file distinguishes between virtual and physical platforms, which leaves the architecture prepared for a possible future migration to real hardware.

From a design perspective, this distinction makes it possible to decouple simulation parameters from physical parameters. In other words, the stack was conceived from the beginning with a structure flexible enough to reuse the same general workflow in different scenarios, adjusting only the constants specific to each platform.

### 1.2 Definition of sampling times

```matlab
%% Setting Qcar Variables
Controller_Sample_Time = 1/500;
CSI_Sample_Time = Controller_Sample_Time * ceil(0.033 / Controller_Sample_Time);
RealSense_Sample_Time = Controller_Sample_Time * ceil(0.033 / Controller_Sample_Time);
ImageDisplay_Sample_Time = Controller_Sample_Time * 50;
LiDAR_Sample_Time = Controller_Sample_Time * ceil(1/15 / Controller_Sample_Time);
Audio_Sample_Time = Controller_Sample_Time * 100;
Initialization_Time = 23;
cameraStepSize = 3e-2;

NN_Sample_Time = RealSense_Sample_Time*1;
```

This block defines the temporal foundation of the system. The main controller operates with a sampling time of

$$
T_c = \frac{1}{500}\ \text{s}
$$

which is equivalent to a frequency of 500 Hz. From this base period, the sampling times of the other subsystems are derived, including cameras, LiDAR, visualization, and the neural network.

From the perspective of discrete-time systems, this means that the controller time is taken as the common reference, and all other modules operate as integer multiples or aligned approximations of that period. This decision prevents temporal inconsistencies among sensors, controllers, and processing modules.

For example, if a visual sensor operates at approximately 30 Hz, then its ideal sampling time would be close to:

$$
T_v \approx 0.033\ \text{s}
$$

In the code, that time is adjusted to the nearest multiple of the controller period through:

$$
T_v = T_c \cdot \left\lceil \frac{0.033}{T_c} \right\rceil
$$

This guarantees that the system preserves internal temporal consistency within Simulink.

The variable `NN_Sample_Time` is set equal to the RealSense camera sampling time, which makes sense because visual inference should not run at an arbitrary independent frequency, but rather in synchronization with the acquisition of the images on which it operates.

### 1.3 Selection of the calibration point

```matlab
if map_type == 1
    cal_pos = [0, 2, 0]
    disp('Large SDCS Map Being Used ...')
else
    cal_pos = [0, 0, 0]
    disp('Small map Being Used ...')
end
```

The variable `cal_pos` defines the calibration position used as the reference for the environment. In this case, when working with the large map, the selected vector is:

$$
\mathbf{p}_{cal} = [0,\ 2,\ 0]
$$

This point functions as a spatial reference to align the map representation, the computed trajectory, and the data derived from sensors. In other words, it is not enough to know the absolute coordinates of the vehicle or the nodes; it is also necessary to establish a common operational origin from which the environment geometry is interpreted.

Later, this reference reappears in the trajectory visualization, when the smoothed coordinates are adjusted by subtracting the calibration position. This ensures that the route is represented correctly within the reference frame of the scenario.

### 1.4 Steering controller gains

```matlab
if qcar_types == 1 % IF VIRTUAL
    steering_Kp = 1.2;
    steering_Kd = 0.6;
elseif qcar_types == 2 % IF PHYSICAL
    steering_Kp = 1;
    steering_Kd = 0.1;
end
```

This block defines the gains of the PD steering controller. For the virtual case, the selected values were:

$$
K_p = 1.2,\qquad K_d = 0.6
$$

Therefore, the steering control law can be interpreted in a general form as:

$$
u_{\delta}(t) = K_p,e(t) + K_d,\dot{e}(t)
$$

where $e(t)$ represents the trajectory error or the orientation error with respect to the reference.

The proportional action corrects the main error, while the derivative action damps rapid changes and reduces oscillations. This is particularly important in an autonomous vehicle following a curved trajectory, since a purely proportional controller may produce overshoot or excessively aggressive corrections in curves and intersections.

The fact that a different configuration exists for `qcar_types == 2` is also important. It suggests that the physical platform presents dynamics different from those of the simulator, so the gains must be adapted to the actual behavior of the system.

### 1.5 Filtering and estimation parameters

```matlab
%% QCar KF + EKF
GyroKF_sampleTime = 0.001;

if qcar_types == 1 % IF VIRTUAL
    GyroKF_X0 = [0;0];
    GyroKF_P0 = eye(2);

    GyroKF_Q = diag([0.001, 0.001]); 
    GyroKF_R = 0.05;

    QCarEKF_sampleTime = GyroKF_sampleTime;

    QCarEKF_L = 0.256;

    QcarKF_X0 = [0; 0; 0];
    QCarEKF_P0 = eye(3);

    QCarEKF_Q = diag([0.001, 0.001, 0.001]);

    QCarEKF_R_heading = diag(0.1);
    QCarEKF_R_combined = diag([0.005, 0.005, 0.001]);
end
```

This fragment defines parameters for Kalman filters and an extended Kalman filter for the vehicle. Although the core of the project focuses mainly on planning, perception, and decision-making, the inclusion of these parameters strengthens the estimation foundation of the stack and shows that the vehicle is built on a broader architecture of modeling and information fusion.

In particular, the effective vehicle length was defined as:

$$
L = 0.256\ \text{m}
$$

This parameter is important for bicycle-type kinematic models and for state propagation in an EKF.

The covariance matrices also reflect an important design decision. If $\mathbf{Q}$ denotes the process noise covariance and $\mathbf{R}$ the measurement noise covariance, then the filter operates according to the classical estimation logic:

$$
\hat{\mathbf{x}}*{k|k-1} = f(\hat{\mathbf{x}}*{k-1|k-1}, \mathbf{u}_{k-1})
$$

$$
\mathbf{P}_{k|k-1} = \mathbf{A}*k \mathbf{P}*{k-1|k-1}\mathbf{A}_k^\top + \mathbf{Q}
$$

and subsequently updates with the measurement:

$$
\mathbf{K}*k = \mathbf{P}*{k|k-1}\mathbf{H}_k^\top \left(\mathbf{H}*k \mathbf{P}*{k|k-1} \mathbf{H}_k^\top + \mathbf{R}\right)^{-1}
$$

$$
\hat{\mathbf{x}}*{k|k} = \hat{\mathbf{x}}*{k|k-1} + \mathbf{K}_k \left(\mathbf{z}*k - h(\hat{\mathbf{x}}*{k|k-1})\right)
$$

Although this part of the methodology does not develop the full EKF implementation, the fact that its parameters are defined makes it clear that the system was prepared to operate on a formal state estimation basis.

### 1.6 Loading calibration files and angular reference

```matlab
if qcar_types == 1 % FOR VIRTUAL
    qcar2_virtual_to_physical_lidar_rotation = -7*pi/180;
    qcar2_lidar_to_map_rotation = -1.5 * pi/180;
    qcar2_lidar_to_body_rotation = 0;
end

load distance_new_qcar2.mat;
load angles_new_qcar2.mat;
range_qcar2 = distance_new_qcar2(2: length(distance_new_qcar2), width(distance_new_qcar2)-5);
angles_qcar2 = angles_new_qcar2(2: length(angles_new_qcar2), width(angles_new_qcar2)-5);
```

Here, the LiDAR orientation is corrected with respect to the map. For example, the LiDAR-to-map rotation for the virtual case was set as:

$$
\theta_{L\to M} = -1.5^\circ
$$

Likewise, an additional correction between the virtual and physical LiDAR representation was defined as:

$$
\theta_{virt\to phys} = -7^\circ
$$

These angular corrections are indispensable to properly align the spatial references of the environment with the computed trajectory and with subsequent visualizations. In an autonomous system, an angular misalignment between the sensor and the map may cause obstacles or geometric references to be interpreted at incorrect positions, affecting both planning and decision-making.

The files `distance_new_qcar2.mat` and `angles_new_qcar2.mat` store distance and angle information used as the geometric reference of the environment. Once loaded, the system has a consistent representation of the workspace on which the planned trajectory can be superimposed.

## Role of this section within the complete system

The parametrization of the virtual QCar 2 constitutes the technical foundation of the complete system. Thanks to this stage, a coherent temporal structure, a clear spatial reference, an adequate set of controller gains, and an initial preparation for state estimation and sensor alignment are defined. All of this allows the subsequent modules — planning, perception, depth estimation, and decision logic — to operate on a stable basis.

In other words, this section does not describe an isolated set of parameters, but rather the operational framework that makes it possible for the rest of the self-driving algorithm to function correctly within the virtual competition environment.