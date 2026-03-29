---
layout: default
title: Simulink Explanation
nav_order: 9
parent: CPS IoT Competition 2026
permalink: /CPS/Simulink/
---
## General System Architecture in Simulink

The architecture implemented in Simulink was organized into clearly differentiated functional modules, so that each block was responsible for a specific task within the autonomous driving pipeline of the virtual QCar 2. This modular organization makes it possible to separate sensor acquisition, state estimation, trajectory planning, longitudinal and lateral control, visual perception with external inference in Python, traffic logic, and the final writing of commands to the vehicle. From an engineering perspective, this structure is important because it facilitates the individual validation of each subsystem and allows new functions to be integrated without completely altering the global behavior of the model.

In general terms, the system flow can be interpreted as a processing chain in which data from the vehicle and the environment are first acquired, then the current pose is estimated, afterward a trajectory reference is selected and the speed and steering commands are calculated, then visual events in the environment are analyzed through the neural network, and finally traffic decisions and light signals are applied before sending the actuation commands to the QCar.

---

## 1. Sensor reading block

![Read Sensors Block](/assets/img/BloqueReadSensor.png)

**Figure.** `Read Sensors` subsystem where the internal QCar signals, such as speed, acceleration, and gyroscope data, are read.

The `readQCarDAC` block concentrates the acquisition of internal vehicle variables. Among its most important outputs are the measured speed (`measuredSpeed`), the accelerometer (`accel`), and the gyroscope (`gyro`), which are essential for control and state estimation. In addition, this block also provides other monitoring signals, such as odometer, battery voltage, motor current, battery level, motor power, and the `gyro_z` component. Although not all of these variables are used directly in the main navigation logic, they are part of the system instrumentation and make it possible to monitor the general behavior of the vehicle within the simulation.

From an architectural standpoint, this block represents the interface between the simulated plant and the rest of the controller. In other words, this is where the basic dynamic information of the QCar is obtained, which will later be used by the state estimation block and by longitudinal control.

---

![Read Sensors Block - LiDAR and RealSense](/assets/img/BloqueReadSensor1.png)

**Figure.** Complementary sensor reading subsystem, where data from the LiDAR and the RealSense camera are captured.

In this part of the subsystem, two fundamental blocks appear: `lidarCapture` and `realsenseCapture`. The `lidarCapture` block provides the distances measured by the LiDAR, the angles associated with each measurement, and a flag called `newLidarReading`, which indicates when a new reading is available. This flag is important because it allows the estimated pose to be updated only when new sensor information arrives.

For its part, the `realsenseCapture` block provides two critical outputs for the perception module: the depth image (`realsenseDepthImage`) and the RGB image (`realsenseRGBImage`), together with the flags `newDepthImage` and `newRGBImage`. These signals are essential because the RGB image is used for object detection through the neural network, while the depth image is later used to compute the distance associated with each detection.

---

## 2. State estimation block

![stateEstimation Block](/assets/img/BloqueProcessing2.png)

**Figure.** `stateEstimation` block, responsible for computing the current pose of the QCar from sensors and vehicle commands.

The `stateEstimation` block receives as inputs the pose coming from the LiDAR (`lidarPose`), the gyroscope, the `newLidarReading` flag, the vehicle speed, and the steering command. With these signals, the block estimates the current pose of the car, expressed as position in \(x\), position in \(y\), and orientation \(\theta\). This output appears labeled as `currentPose [x,y,heading] (m,m,rad)`.

The importance of this block is very high within the system, since the estimated pose is the variable that allows the algorithm to know where the vehicle is located inside the map. Based on this pose, the trajectory planner, the lateral controller, and also the lighting logic operate. In other words, this block acts as the bridge between the sensory measurements and the geometric representation of the vehicle within the environment.

---

## 3. Planning and lateral control blocks

![pathPlanner and steeringCommander Blocks](/assets/img/BloqueProcessing1.png)

**Figure.** Lateral processing subsystem composed of the `pathPlanner` and `steeringCommander` blocks.

The `pathPlanner` block, which appears in orange, receives the current vehicle pose and the desired or adjusted speed, as well as a look-ahead distance called `lookAheadDistance`. From these inputs, it produces as outputs the desired trajectory (`desiredPath`), the current point on the route (`currentPathXY`), the target point or next reference (`desiredPathXY`), and the distance between the vehicle and the trajectory (`distanceToPath`). This block functions as the local navigation layer over the global trajectory, since it decides which part of the path the car should follow at the current instant.

Above it is the `steeringCommander` block, responsible for lateral control. This block uses as inputs the yaw rate (`yawRate`), the identifier of the desired trajectory, the adjusted speed, the current pose, the distance to the path, and the current and desired coordinates on the route. From that information, it computes the final steering command (`steeringCmd`). Functionally, this block transforms the geometric information of the lateral error and the vehicle state into a steering signal that allows the trajectory to be followed in a stable way.

From a control perspective, both blocks work together: `pathPlanner` decides **which point of the route must be followed**, while `steeringCommander` decides **how to orient the vehicle in order to reach it**.

---

## 4. Longitudinal control block

![speedController Block](/assets/img/BloqueProcessing.png)

**Figure.** `speedController` block, responsible for controlling the speed of the QCar.

The `speedController` block receives the target speed, the steering command, the currently measured speed, the distance to an obstacle, and a QCar enable flag. From these inputs it generates two main outputs: the PWM command to be applied to the motor (`pwmCmd`) and an adjusted speed called `tunedSpeedCmd`.

The logic of this block consists of transforming a desired speed into a longitudinal command that can be physically applied to the vehicle. However, its role is not limited to being a simple speed-to-PWM converter. It also incorporates the context of the environment through the distance to the obstacle and produces an adjusted speed that will later be used by the planner and by the traffic logic. This means that this block not only controls speed, but also adapts it to the current situation of the vehicle within the scenario.

---

## 5. Visual inference and communication block with Python

![Inference block in Simulink](/assets/img/BloqueSimulink3.png)

**Figure.** Communication subsystem between Simulink and Python to execute inference with the detection model and construct the final object matrix with depth.

On the left side of this subsystem, the `realsenseRGBImage` signal is received, which corresponds to the RGB frame captured by the camera. According to your explanation, this image first passes through a data type conversion block to ensure that it is in `uint8` format, and afterward through a `reshape` block that transforms it into a row vector. This is done with the objective of packaging the frame and sending it through TCP/IP to the Python script that executes the neural network. The `Model_Input_Stream` block functions as a TCP/IP client in sender mode and, according to your transcriptions, it was configured at the address `tcpip://localhost:18002`, with a large buffer size so that the frames would not arrive truncated, and with a sampling time equal to that of the camera. :contentReference[oaicite:4]{index=4}

The second communication block is `InferenceDecoder`, which operates in receiver mode and connects to port `18001`. Its function is to receive from Python the output of the inference model, that is, the list of detected objects with their six attributes: class identifier, probability, \(x_1\), \(y_1\), \(x_2\), and \(y_2\). This information arrives as a fixed vector of 60 elements and is later reorganized with a `reshape` into a 6×10 matrix, where each column represents a detected object. Choosing a fixed size of 6×10 was a very important decision because it simplifies handling in Simulink and avoids the use of dynamic matrices. If there are fewer than ten objects, the remaining columns are filled with zeros. :contentReference[oaicite:5]{index=5}

On the right side appears the `BuildDetectionMatrix` block, which internally uses the `addDepth` function. The purpose of this block is to take the 6×10 detection matrix and add a seventh row representing the estimated distance of the object. To do this, it uses the bounding box coordinates \((x_1,y_1,x_2,y_2)\) and computes a region of interest within the depth frame (`realsenseDepthImage`). From that region it obtains the distance associated with the detected object. The final result is a 7×10 matrix, which no longer contains only visual information but also geometric content. This enriched matrix is the one that later feeds the traffic logic, obstacle avoidance, and pedestrian braking blocks. :contentReference[oaicite:6]{index=6} :contentReference[oaicite:7]{index=7}

At the bottom of this same subsystem is the pedestrian braking logic, which you refer to as `AEB Pedestrian Logic`. According to your explanation, this block receives the 7×10 matrix and the depth image, and its function is to distinguish whether the object appearing in front of the car corresponds to a person or to a cone. If it is a cone, then the system does not brake but instead activates the avoidance logic; if it is a person, the block must issue a stop flag that will later be used by the traffic logic. You also explain that at that moment this part was still under fine adjustment, because the objective was to prevent the vehicle from running over the pedestrian within the simulation. :contentReference[oaicite:8]{index=8}

---

## 6. Traffic logic and decision-making

The `traffic signal logic` function is the main rule-based decision layer of the system. According to your transcriptions, this function receives the 7×10 detection matrix, the speed calculated by the controller, and a simulation clock, in addition to the `pedestrian_flag`. The clock is used to measure how much time has passed since an event such as a STOP or a YIELD was detected, thereby making it possible to implement realistic temporal stops within the simulation. :contentReference[oaicite:9]{index=9}

Internally, the function declares persistent variables to handle states associated with STOP, YIELD, and roundabout logic. It then traverses the detection matrix and validates, for each object, its class, probability, distance, and whether it is being observed frontally. For example, when the detected class corresponds to a STOP sign, the probability is sufficiently high, the distance is small, and the object is in front of the vehicle, then the stopping logic is activated. The same occurs with YIELD, while for roundabout what you do is reduce the speed by multiplying it by a smaller factor so that the vehicle enters more slowly. You also mention that for traffic lights you implemented a kind of persistence or commitment distance: if the car has already seen green and has already committed to crossing, then it continues moving even if yellow or red appears afterward, avoiding stopping in the middle of the intersection. :contentReference[oaicite:10]{index=10}

Another important aspect you explain is that this function operates as a speed *switching* block. That is, under normal conditions it lets the speed coming from the longitudinal controller pass through, but if it detects a condition that requires stopping, it switches that signal to zero. Once the waiting time has elapsed or the condition disappears, it switches back to the controller speed. You also mention that, since side cameras are not available, to simulate passenger pickup you perform a temporal approximation: when the passenger is detected at a certain distance, the system starts counting time and later commands a stop, so that the car stops approximately next to the passenger and not exactly in front of them. :contentReference[oaicite:11]{index=11}

In addition to this logic, you also have the `avoid cone` block, to which you send the same detection matrix, the simulation clock, and the `steering` computed by the controller. When a cone is detected, the steering calculated by the lateral control is switched to a smooth avoidance trajectory, which you describe as a sigmoidal signal so that the avoidance maneuver is not abrupt. If there is no cone, the input steering is simply preserved. You also point out that cone avoidance is always performed to the left, following the overtaking logic on that side, and that this block outputs a `direction` flag that is later used by the lighting system. :contentReference[oaicite:12]{index=12}

---

## 7. QCar writing block and final actuation

![writeToQCarDAC Block](/assets/img/BloqueWriteToCar.png)

**Figure.** `writeToQCarDAC` block, responsible for applying the motor, steering, and lighting commands to the vehicle.

The `writeToQCarDAC` block is the final link in the control chain. It receives as inputs the motor command (`motor_cmd`), the steering command (`steering_cmd`), the LED vector (`leds`), and the RGB strip (`ledStrip`). This means that both the purely dynamic decisions of the vehicle and the light logic associated with braking and turn signals converge here.

According to your transcription, the RGB strip and the light signals are generated by a `light controller` block, to which you pass the current vehicle pose, the PWM, a pulse generator to make the turn signals blink, the smoothed trajectory, the segments where the left and right lights should be turned on, the `avoid` cone-avoidance flag, and the `stop_light` coming from the traffic logic. The central idea of that block is that the lights are activated either by **events** —such as a STOP, picking up a person, or avoiding a cone— or by **specific trajectory segments**, that is, zones where the car already knows it must indicate a maneuver to the left or to the right. You also explain that the pulse generator is multiplied by the left or right signal flags to create the real blinking effect, and that when the car is braking or the PWM is zero, the braking logic is activated on the light strip. :contentReference[oaicite:13]{index=13}

From a functional standpoint, this block represents the final interface between the controller and the plant. This is where all the decisions made throughout the pipeline become real actions on the QCar: moving forward, turning, braking, or turning on the corresponding light signals.

---

## Global interpretation of the architecture

Taken together, the architecture built in Simulink can be interpreted as a hierarchical system in which each block fulfills a well-defined function. The sensors deliver information about the vehicle and the environment; the state estimation computes the current pose; the planner and the lateral controller determine how to follow the trajectory; the speed controller adjusts the longitudinal motion; the perception module detects objects through the neural network and adds depth to them; the traffic logic decides whether the vehicle must stop, reduce speed, or continue; the avoidance function modifies steering if a cone appears; the light controller visually expresses the vehicle’s maneuvers and events; and finally, the writing block applies all of this to the QCar. This modular organization makes it possible for the system not to be a simple trajectory follower, but rather a complete self-driving architecture capable of perceiving, deciding, and acting in an integrated way.