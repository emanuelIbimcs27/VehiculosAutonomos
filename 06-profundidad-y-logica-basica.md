---
layout: default
title: Depth Estimation, Turn Signal Activation, and Obstacle Avoidance
nav_order: 4
parent: CPS IoT Competition 2026
permalink: /CPS/profundidad-y-logica-basica/
---

# Depth Estimation, Turn Signal Activation, and Obstacle Avoidance

## 5. Depth estimation over detections: `addDepth` function

The object detector provides two-dimensional information from RGB images, but in order to make driving decisions it is not enough to know only the class of the object and its location on the image plane. In an autonomous system, it is also necessary to estimate the actual distance at which each element of the environment is located. For this reason, the `addDepth` function was implemented, whose objective is to enrich each visual detection with a robust depth estimate obtained from the depth map associated with the virtual camera.

This function constitutes the bridge between purely visual perception and spatial perception. Thanks to it, a detection is no longer just a bounding box with class and confidence, but becomes an object with geometric meaning within the vehicle’s environment.

### 5.1 Objective of the function

If the detector outputs, for each object, a structure of the form:

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

where:

- $c_i$ is the detected class,
- $\rho_i$ is the confidence,
- $(x_{1,i}, y_{1,i})$ and $(x_{2,i}, y_{2,i})$ are the bounding box coordinates,

then the `addDepth` function transforms that detection into an enriched structure:

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

where $\hat{z}_i$ represents the estimated depth of the object.

### 5.2 Function definition

```matlab
function out = addDepth(detections, depth)

% detections: [6 x 10]
% depth: [480 x 640]

out = zeros(7,10,'single');
````

The `detections` matrix contains up to ten detected objects, each one with six attributes. The `depth` matrix stores the per-pixel depth information. The output `out` adds a seventh row to store the estimated distance of each valid detection.

Initializing the output with zeros and type `single` is also important, since it maintains numerical consistency with the rest of the Simulink flow and avoids unnecessary memory usage.

### 5.3 Full code

```matlab
function out = addDepth(detections, depth)

out = zeros(7,10,'single');

for i = 1:10

    prob = detections(2,i);

    if prob > 0

        x1 = detections(3,i);
        y1 = detections(4,i);
        x2 = detections(5,i);
        y2 = detections(6,i);

        x1 = int32(x1);
        y1 = int32(y1);
        x2 = int32(x2);
        y2 = int32(y2);

        x1 = min(max(x1,1),640);
        x2 = min(max(x2,1),640);
        y1 = min(max(y1,1),480);
        y2 = min(max(y2,1),480);

        if x2 < x1
            temp = x1; x1 = x2; x2 = temp;
        end
        if y2 < y1
            temp = y1; y1 = y2; y2 = temp;
        end

        roi = depth(y1:y2, x1:x2);

        roi = roi(~isnan(roi));
        roi = roi(roi > 0);

        if isempty(roi)
            dist = single(999);
        else
            dist = median(roi); 
        end

        out(1:6,i) = detections(:,i);
        out(7,i) = dist;

    end
end

end
```

### 5.4 Selection of the region of interest

For each valid detection, the function takes the bounding box and extracts the corresponding region from the depth map. Mathematically, if the bounding box of object $i$ is defined as:

$$
B_i = {(u,v);|; x_{1,i} \le u \le x_{2,i},\ y_{1,i} \le v \le y_{2,i}}
$$

then the region of interest associated with depth is given by:

$$
\mathcal{R}_i = {D(u,v);|;(u,v)\in B_i}
$$

where $D(u,v)$ is the depth at pixel $(u,v)$.

Unlike simpler strategies that take only the center pixel of the box, here the entire region is analyzed. This makes the estimate more robust, since a single central sample could correspond to a sensor hole, the background, or an outlier not representative of the object.

### 5.5 Geometric sanitization of the bounding box

Before extracting the depth-map region, the function performs several sanitization operations:

```matlab
x1 = int32(x1);
y1 = int32(y1);
x2 = int32(x2);
y2 = int32(y2);

x1 = min(max(x1,1),640);
x2 = min(max(x2,1),640);
y1 = min(max(y1,1),480);
y2 = min(max(y2,1),480);
```

These operations have a clear purpose. First, they convert the coordinates to integers, since matrix indices must be discrete. Then, each coordinate is saturated to the valid image limits:

$$
x \in [1,640], \qquad y \in [1,480]
$$

This prevents indexing errors if the detection lies partially outside the image border.

In addition, the code verifies that the coordinate order is consistent:

```matlab
if x2 < x1
    temp = x1; x1 = x2; x2 = temp;
end
if y2 < y1
    temp = y1; y1 = y2; y2 = temp;
end
```

This ensures that the following always holds:

$$
x_{1,i} \le x_{2,i}, \qquad y_{1,i} \le y_{2,i}
$$

which is indispensable for constructing a valid rectangular region.

### 5.6 Filtering invalid depth values

Once the region of interest has been obtained, the function removes invalid values:

```matlab
roi = roi(~isnan(roi));
roi = roi(roi > 0);
```

This means that the depth estimate is based only on the set:

$$
\mathcal{Z}_i =
\left{
D(u,v);|;(u,v)\in B_i,\ D(u,v)>0,\ D(u,v)\neq \text{NaN}
\right}
$$

This filtering is necessary because depth maps may contain null pixels, holes, or undefined readings. If those values were used directly, the estimated distance would be unreliable and could trigger incorrect decisions in the vehicle logic.

### 5.7 Use of the median as a robust estimator

The final distance of the object is computed as:

```matlab
if isempty(roi)
    dist = single(999);
else
    dist = median(roi); 
end
```

In mathematical terms:

$$
\hat{z}_i =
\begin{cases}
\operatorname{median}(\mathcal{Z}_i), & \mathcal{Z}_i \neq \varnothing \
999, & \mathcal{Z}_i = \varnothing
\end{cases}
$$

The median was chosen as a robust estimator because it reduces the influence of extreme values. If the box contains spurious pixels, partial holes, or background zones, the median still provides a representative measure of the object’s distance. This is especially useful in simulated urban scenes where the boxes may cover edges or mixed regions.

The value `999` is used as a sentinel to indicate that it was not possible to obtain a valid measurement. In this way, the decision logic can distinguish between an object detected with reliable depth and one whose distance could not be estimated correctly.

### 5.8 Enriched output

Finally, the function preserves the six original detection attributes and adds the computed depth:

```matlab
out(1:6,i) = detections(:,i);
out(7,i) = dist;
```

With this, the output ceases to be a purely visual detection and becomes a detection with geometric content. This transformation is essential for the rest of the system, since the traffic light logic, pickup logic, safety braking, and avoidance functions make decisions based on the estimated distance and not only on the visual presence of the object.

---

## 6. Unified traffic and context logic through `trafficSignsLogic`

Once detections have been enriched with depth, the system applies a higher-level interpretation layer through the function `trafficSignsLogic`. Unlike the earlier basic sign logic, this function no longer handles only isolated signs such as STOP or YIELD, but instead integrates several contextual events into a single decision block. In its current form, the function combines:

* STOP sign logic,
* YIELD sign logic,
* roundabout speed reduction,
* pickup-person behavior,
* traffic light interpretation,
* and an external pedestrian safety flag.

For that reason, `trafficSignsLogic` acts as the main rule-based speed decision layer of the vehicle.

### 6.1 Objective of the function

The function receives:

* a nominal speed `speed_in`,
* the matrix of detections enriched with depth,
* the current time `t`,
* and an external safety flag `pedestrian_flag`.

It returns:

* an adjusted speed `speed_out`,
* and a brake-related flag `stop_ligth`.

Formally:

$$
(speed_out,\ stop_ligth) = f(speed_in,\ detections,\ t,\ pedestrian_flag)
$$

Its objective is for the vehicle to stop, slow down, or continue according to the observed traffic context and safety state.

### 6.2 Full code

```matlab
function [speed_out, stop_ligth]= trafficSignsLogic(speed_in, detections, t, pedestrian_flag)

persistent stop_active t_start stop_done
persistent yield_active t_yield_start yield_done
persistent person_active t_person_start person_phase person_done

persistent traffic_state % 0 = WAIT, 1 = GO
persistent green_counter

if isempty(stop_active)
    stop_active = false;
    t_start = 0;
    stop_done = false;
    
    yield_active = false;
    t_yield_start = 0;
    yield_done = false;
    
    person_active = false;
    t_person_start = 0;
    person_phase = 0;
    person_done = false;
end

if isempty(traffic_state)
    traffic_state = 0;
    green_counter = 0;
end

speed_out = speed_in;

stop_detected = false;
yield_detected = false;
round_detected = false;
person_detected = false;
stop_ligth = 0;

traffic_red = false;
traffic_green = false;
traffic_yellow = false;
traffic_dist = single(999);

for i = 1:10
    
    class_id = detections(1,i);
    prob     = detections(2,i);
    dist     = detections(7,i);
    
    x1 = detections(3,i);
    x2 = detections(5,i);
    cx = (x1 + x2)/2;
    
    frontal = abs(cx - 320) < 100;
    right_side = cx > 360;
    
    if class_id == 5 && prob > 0.9 && dist < 1.3 && frontal
        stop_detected = true;
    end
    
    if class_id == 7 && prob > 0.9 && dist < 1.5 && frontal
        yield_detected = true;
    end
    
    if class_id == 4 && prob > 0.8 && dist < 2.0 && frontal
        round_detected = true;
    end
    
    if class_id == 2 && prob > 0.8 && dist < 7.3 && right_side
        person_detected = true;
    end

    if prob > 0.85 && dist < 3.6 && frontal
        
        traffic_dist = dist;
        
        if class_id == 3
            traffic_red = true;
        elseif class_id == 1
            traffic_green = true;
        elseif class_id == 6
            traffic_yellow = true;
        end
    end
    
end

if pedestrian_flag == 1
    speed_out = 0;
    stop_ligth = 1;
    return;
end

if stop_detected && ~stop_active && ~stop_done
    stop_active = true;
    stop_ligth = 1;
    t_start = t;
end

if stop_active
    if (t - t_start) < 5
        speed_out = 0;
        return;
    else
        stop_ligth = 0;
        stop_active = false;
        stop_done = true;
    end
end

if ~stop_detected
    stop_done = false;
end

if yield_detected && ~yield_active && ~yield_done
    yield_active = true;
    t_yield_start = t;
end

if yield_active
    if (t - t_yield_start) < 2
        speed_out = 0;
        stop_ligth = 1;
        return;
    else
        yield_active = false;
        stop_ligth = 0;
        yield_done = true;
    end
end

if ~yield_detected
    yield_done = false;
end

if person_detected && ~person_active && ~person_done
    person_active = true;
    t_person_start = t;
    person_phase = 1;
end

if person_active
    
    dt = t - t_person_start;
    
    if dt < 5
        speed_out = speed_in; 
        
    elseif dt < 9
        speed_out = 0;
        stop_ligth = 1;
    else
        person_active = false;
        person_done = true;
        stop_ligth = 0;
    end
    
    return;
end

commit_dist = 1.2;

if traffic_state == 0
    
    if traffic_green
        green_counter = green_counter + 1;
    else
        green_counter = 0;
    end
    
    if traffic_red || traffic_yellow
        speed_out = 0;
        stop_ligth = 1;
        return;
    end
    
    if green_counter > 3
        if traffic_dist < commit_dist
            traffic_state = 1;
        end
    end
end

if traffic_state == 1
    
    speed_out = speed_in;
    
    if traffic_dist > 3.5
        traffic_state = 0;
        green_counter = 0;
    end
    
end

if round_detected
    speed_out = 0.5 * speed_in;
end

end
```

### 6.3 Use of persistent variables

The function uses persistent variables in order to keep temporal memory of previously activated events:

```matlab
persistent stop_active t_start stop_done
persistent yield_active t_yield_start yield_done
persistent person_active t_person_start person_phase person_done
persistent traffic_state
persistent green_counter
```

This converts the function into a hybrid state machine. It does not react only to the current frame, but also remembers whether a STOP has already been activated, whether a YIELD wait is in progress, whether a pickup maneuver is underway, and whether the traffic light logic is currently in a WAIT or GO state.

This temporal memory is essential, because several of the implemented behaviors extend over multiple seconds and cannot be correctly represented with purely instantaneous logic.

### 6.4 Base semantic interpretation of detections

For each detected object, the function extracts:

* the class,
* the confidence,
* the estimated depth,
* and the horizontal box position.

From the horizontal coordinates, it computes:

$$
c_x = \frac{x_1 + x_2}{2}
$$

and defines two geometric conditions:

$$
frontal \iff |c_x - 320| < 100
$$

$$
right_side \iff c_x > 360
$$

The `frontal` condition is used for STOP, YIELD, roundabout, and traffic light interpretation, while the `right_side` condition is used to identify a pickup person standing on the sidewalk. In this way, the same object class may be interpreted differently depending on where it appears in the image.

### 6.5 STOP logic

A STOP sign is considered valid when:

$$
c_i = 5,\qquad \rho_i > 0.9,\qquad \hat{z}_i < 1.3,\qquad frontal
$$

Once activated, the vehicle remains stopped for 5 seconds:

$$
v_{out}(t) =
\begin{cases}
0, & 0 \le t-t_0 < 5 \
v_{in}(t), & t-t_0 \ge 5
\end{cases}
$$

and during that phase:

$$
stop_ligth = 1
$$

This reproduces a complete STOP maneuver with explicit temporal persistence.

### 6.6 YIELD logic

A YIELD sign is considered valid when:

$$
c_i = 7,\qquad \rho_i > 0.9,\qquad \hat{z}_i < 1.5,\qquad frontal
$$

Once activated, the vehicle stops for 2 seconds:

$$
v_{out}(t) =
\begin{cases}
0, & 0 \le t-t_y < 2 \
v_{in}(t), & t-t_y \ge 2
\end{cases}
$$

This produces a shorter stop than STOP, but still enforces the expected yielding behavior.

### 6.7 Roundabout logic

The roundabout condition is:

$$
c_i = 4,\qquad \rho_i > 0.8,\qquad \hat{z}_i < 2.0,\qquad frontal
$$

In this case the vehicle does not stop, but reduces speed according to:

$$
v_{out}(t) = 0.5,v_{in}(t)
$$

This models a more cautious entry into circular or curved road areas.

### 6.8 Pickup-person logic

A person is considered a pickup candidate when:

$$
c_i = 2,\qquad \rho_i > 0.8,\qquad \hat{z}_i < 7.3,\qquad right_side
$$

This restriction is important because not every detected person should be treated as a passenger. The right-side condition reflects that the passenger is expected to be on the sidewalk.

Once activated, the pickup logic is divided into two phases:

1. **Approach phase**
   During the first 5 seconds:

   $$
   0 \le dt < 5 \Rightarrow v_{out}(t) = v_{in}(t)
   $$

2. **Pickup stop phase**
   During the next 4 seconds:

   $$
   5 \le dt < 9 \Rightarrow v_{out}(t) = 0
   $$

and the brake-light flag is activated during the stop.

This creates a realistic sequence in which the vehicle first approaches the passenger and then stops for service.

### 6.9 Traffic light logic and WAIT/GO state machine

Traffic light control is implemented as a two-state machine:

* `traffic_state = 0`: **WAIT**
* `traffic_state = 1`: **GO**

The function first checks whether the detected traffic light is red, green, or yellow, and stores the approximate traffic-light distance in `traffic_dist`.

A commitment distance is defined as:

```matlab
commit_dist = 1.2;
```

#### WAIT state

In the WAIT state, the system requires several stable green frames before crossing:

```matlab
if traffic_green
    green_counter = green_counter + 1;
else
    green_counter = 0;
end
```

Thus, the crossing is committed only if:

$$
green_counter > 3 \quad \text{and} \quad traffic_dist < 1.2
$$

If red or yellow is detected in this state, then:

$$
v_{out}(t) = 0
$$

and the brake flag is activated.

#### GO state

Once committed, the vehicle ignores subsequent traffic light changes while crossing:

$$
v_{out}(t) = v_{in}(t)
$$

The system only returns to WAIT when the vehicle has already passed the intersection and:

$$
traffic_dist > 3.5
$$

This avoids unrealistic behavior such as stopping in the middle of the crossing.

### 6.10 External pedestrian safety flag

The first condition checked by the function is the external safety flag:

```matlab
if pedestrian_flag == 1
    speed_out = 0;
    stop_ligth = 1;
    return;
end
```

This means that any frontal safety warning generated by the pedestrian safety layer has absolute priority over all the other behaviors. From the architectural standpoint, this is correct: immediate safety must dominate over traffic-rule interpretation.

### 6.11 Functional role of `trafficSignsLogic`

This function is the main context-aware speed decision module of the vehicle. It receives geometric detections enriched with depth and turns them into concrete longitudinal behavior. Unlike the earlier simpler sign logic, `trafficSignsLogic` integrates multiple simultaneous road events into one coherent decision layer.

In practical terms, this function is the one that determines whether the vehicle must:

* keep moving,
* reduce speed,
* stop for a fixed time,
* stop for a pickup maneuver,
* or stop due to a traffic light or external safety condition.

---

## 7. Turn signal activation through `LightingControl`

Once the vehicle trajectory has been segmented into left-turn and right-turn regions, it becomes necessary to convert that information into an actual lighting command that can be sent to the QCar. This task is performed by the `LightingControl` function, whose purpose is to build the `ledStrip` array that activates turn signals or brake lights according to two complementary mechanisms:

1. **segment-based activation**, using the current vehicle pose and the precomputed left/right trajectory segments,
2. **event-based activation**, using logic flags such as `avoid` and `stop_ligth`.

In this sense, `LightingControl` acts as the bridge between the trajectory semantics and the physical signaling output of the vehicle.

### 7.1 Full code

```matlab
function ledStrip  = LightingControl(pose, pwm, blink, ...
                                path_x, path_y, ...
                                segmentos_izq, segmentos_der, ...
                                avoid, stop_ligth)

x = pose(1);
y = pose(2);

% =============================
% 1. FIND idx_pose (progress)
% =============================
min_dist = inf;
idx_pose = 1;

for i = 1:length(path_x)
    dx = x - path_x(i);
    dy = y - path_y(i);
    d = dx*dx + dy*dy;
    
    if d < min_dist
        min_dist = d;
        idx_pose = i;
    end
end

% =============================
% 2. SEGMENT DETECTION
% =============================
margen = 50; % anticipation

left_signal = any( idx_pose >= (segmentos_izq(:,1)-margen) & ...
                   idx_pose <= segmentos_izq(:,2) );

right_signal = any( idx_pose >= (segmentos_der(:,1)-margen) & ...
                    idx_pose <= segmentos_der(:,2) );

% apply blink
left_signal = left_signal * blink;
right_signal = right_signal * blink;

% =============================
% 3. BRAKE
% =============================
brake = (stop_ligth == 1) || (pwm == 0);

% =============================
% 4. LED OUTPUTS (PRIORITIES)
% =============================
ledStrip = zeros(3,25);

% Brake (highest priority)
if brake
    ledStrip(:,11) = [255;0;0];
    ledStrip(:,13) = [255;0;0];
    ledStrip(:,14) = [255;0;0];
    ledStrip(:,16) = [255;0;0];

else
    % Avoid (second priority)
    if avoid == 1
        ledStrip(:,16) = [255;255;0] * blink;
        
    else
        % Normal turn signals
        if left_signal
            ledStrip(:,16) = [255;255;0];
        end

        if right_signal
            ledStrip(:,11) = [255;255;0];
        end
    end
end

end
```

### 7.2 Objective of the function

The function receives:

* the current vehicle pose `pose`,
* the motor command `pwm`,
* a blinking signal `blink`,
* the smoothed reference trajectory `path_x`, `path_y`,
* the previously computed left and right turn signal segments,
* an avoidance flag `avoid`,
* and a brake-related flag `stop_ligth`.

Its output is the matrix:

$$
ledStrip \in \mathbb{R}^{3 \times 25}
$$

which represents the RGB intensities sent to the lighting strip of the vehicle.

The main objective is to determine **which light pattern must be active at each instant**, depending on whether the car is close to a turn-signal segment, currently avoiding an obstacle, or braking due to a traffic event.

### 7.3 Pose-based progress estimation on the trajectory

The first operation of the function is to estimate where the vehicle currently is along the smoothed path. This is done by taking the current pose:

$$
(x,y) = (pose(1), pose(2))
$$

and finding the closest point on the reference trajectory. In code, this is implemented by minimizing the squared Euclidean distance:

$$
idx_{pose} = \arg\min_i \left[(x - path_x(i))^2 + (y - path_y(i))^2\right]
$$

This step is fundamental because the lighting logic is not based directly on graph nodes, but on the vehicle’s progress along the continuous trajectory. The variable `idx_pose` acts as a trajectory progress indicator and makes it possible to determine whether the vehicle is near a region where turn signaling should be active.

### 7.4 Detection of left and right signal segments

Once the current trajectory index has been identified, the function checks whether that index belongs to one of the left-turn or right-turn intervals. In order to provide anticipation before the actual turning maneuver begins, the logic introduces a margin:

```matlab
margen = 50;
```

This means that the turn signal is not activated only when the vehicle is exactly inside the segment, but also when it is sufficiently close to its beginning. Formally, the left-turn condition is:

$$
left_signal = \exists [a_k,b_k] \in \mathcal{S}*{izq}
\text{ such that }
idx*{pose} \in [a_k - margen,\ b_k]
$$

and similarly for the right-turn condition:

$$
right_signal = \exists [c_k,d_k] \in \mathcal{S}*{der}
\text{ such that }
idx*{pose} \in [c_k - margen,\ d_k]
$$

This anticipation mechanism is very important because real turn signals should turn on slightly before the actual turning point, not only when the vehicle is already in the middle of the maneuver.

### 7.5 Blinking mechanism

After detecting whether the current trajectory position lies in a relevant segment, the function multiplies both logical values by the external blinking input:

```matlab
left_signal = left_signal * blink;
right_signal = right_signal * blink;
```

This means that even if the segment is active, the light will not remain continuously on, but instead will blink according to the periodic signal `blink`. Functionally, this reproduces the actual visual behavior of automotive turn indicators.

If `blink` is a binary periodic signal, then the emitted turn signal becomes:

$$
signal_{left}(t) = left_signal_{base}(t)\cdot blink(t)
$$

$$
signal_{right}(t) = right_signal_{base}(t)\cdot blink(t)
$$

Thus, the trajectory logic determines **when** a turn signal should exist, while the blinking signal determines **how** it should be visually emitted.

### 7.6 Brake detection

The braking condition is defined as:

```matlab
brake = (stop_ligth == 1) || (pwm == 0);
```

This means that the brake light can be activated in two ways:

1. when the higher-level logic explicitly indicates braking through `stop_ligth`,
2. when the motor command itself is zero.

In logical form:

$$
brake = (stop_ligth = 1) \lor (pwm = 0)
$$

This is a robust design choice because it allows braking lights to reflect both explicit traffic decisions and actual command-level stopping conditions.

### 7.7 Priority hierarchy of lighting outputs

The output lighting logic is not flat, but hierarchical. The priority order implemented by the function is:

$$
\text{Brake} ;>; \text{Avoidance event} ;>; \text{Normal turn signals}
$$

#### Highest priority: brake

If the brake condition is active, the function sets four positions of the LED strip to red:

```matlab
ledStrip(:,11) = [255;0;0];
ledStrip(:,13) = [255;0;0];
ledStrip(:,14) = [255;0;0];
ledStrip(:,16) = [255;0;0];
```

This produces a brake-light pattern with red intensity over multiple LEDs, making the stopping state clearly visible.

#### Second priority: avoidance event

If braking is not active but `avoid == 1`, then the system activates a yellow warning signal:

```matlab
ledStrip(:,16) = [255;255;0] * blink;
```

This indicates that the vehicle is currently executing an obstacle-avoidance event. In this way, the lighting system is not limited to representing route-based turn signals, but can also express reactive events triggered by the environment.

#### Third priority: normal turn signals

Only when neither braking nor avoidance is active does the function use the precomputed segment logic:

```matlab
if left_signal
    ledStrip(:,16) = [255;255;0];
end

if right_signal
    ledStrip(:,11) = [255;255;0];
end
```

As implemented in the current code, the left signal is represented through LED position 16 and the right signal through LED position 11, both with yellow intensity.

### 7.8 Functional interpretation within the complete system

The `LightingControl` function is the block that transforms high-level behavioral semantics into a physical output that can be sent to the vehicle. It takes abstract information such as:

* “the car is approaching a left-turn segment,”
* “the vehicle is currently braking,”
* “the avoidance maneuver is active,”

and converts it into an RGB strip command.

This function is especially important because it closes the loop between path planning, traffic semantics, and the expressive behavior of the vehicle. Without it, the trajectory segmentation logic would remain only as an internal computational result. With `LightingControl`, those segment decisions become visible and operational at the vehicle level.

---

## 8. Obstacle avoidance through `avoidCone`

In addition to following the nominal route and activating turn signals according to the segmented trajectory, the vehicle must also be capable of reacting to local physical obstacles. For that reason, the function `avoidCone` was implemented, whose purpose is to temporarily modify the nominal steering command when a cone is detected near the vehicle.

Unlike global planning, this function does not recompute the route. Instead, it generates a local reactive maneuver that overrides the incoming steering reference for a short period of time. This is appropriate because a cone is treated as a local event that should be solved immediately without destroying the nominal trajectory structure.

### 8.1 Full code

```matlab
function [steering_out, direction]= avoidCone(steering_in, detections, t) 

    persistent avoid_active t_start
    if isempty(avoid_active)
        avoid_active = false;
        t_start = 0;
    end

    % Maneuver parameters
    T_total = 3.0; % total maneuver duration in seconds
    Amp = 0.4;     % maximum steering amplitude for avoidance

    cone_detected = false;
    direction = 0;

    % Current detection logic
    for i = 1:size(detections, 2)
        class_id = detections(1,i);
        prob     = detections(2,i);
        dist     = detections(7,i);
        
        % Cone detected at less than 1.5 m
        if class_id == 0 && prob > 0.85 && dist < 1.5 
            cone_detected = true;
            break;
        end
    end

    % Trigger the maneuver
    if cone_detected && ~avoid_active
        avoid_active = true;
        t_start = t;
    end

    if avoid_active
        dt = t - t_start;
        
        if dt < T_total
            direction = 1;
            % Complete sinusoidal wave for a smooth S-shaped maneuver
            steering_avoid = Amp * sin(2 * pi * dt / T_total);
            steering_out = steering_avoid; 
        else
            avoid_active = false;
            direction = 0;
            steering_out = steering_in;
        end
    else
        steering_out = steering_in;
        direction = 0;
    end
end
```

### 8.2 Objective of the function

The function receives:

* the nominal steering command `steering_in`,
* the detection matrix enriched with depth,
* the current time `t`,

and returns:

* a corrected steering command `steering_out`,
* a flag `direction` indicating whether the avoidance maneuver is active.

Its purpose is to determine whether a cone is close enough to require an evasive maneuver and, if so, to temporarily replace the nominal steering with a smooth avoidance profile.

### 8.3 Cone detection criterion

The obstacle that triggers this logic is the cone class, identified by:

$$
c_i = 0
$$

with the additional conditions:

$$
\rho_i > 0.85,\qquad \hat{z}_i < 1.5
$$

That is, the system only activates avoidance when a cone has been detected with sufficiently high confidence and is located at less than 1.5 meters. In this way, distant detections or weak cone hypotheses do not unnecessarily modify the steering behavior.

### 8.4 Use of persistent state

The function uses two persistent variables:

```matlab
persistent avoid_active t_start
```

This means that once the maneuver has been triggered, it is maintained across iterations until its temporal window finishes. The function therefore behaves as a local state machine with two states:

* `avoid_active = false`: normal steering tracking
* `avoid_active = true`: temporary avoidance maneuver

This is important because the cone may remain visible across multiple frames, and without a persistent state the maneuver could be retriggered erratically.

### 8.5 Sinusoidal steering law

Once the cone has been detected and the maneuver has been activated, the function computes:

$$
dt = t - t_0
$$

where $t_0$ is the activation instant. During the active interval:

$$
0 \le dt < T_{total}
$$

the steering is replaced by the sinusoidal law:

$$
\delta_{avoid}(t) = A \sin\left(\frac{2\pi (t-t_0)}{T_{total}}\right)
$$

with:

$$
A = 0.4,\qquad T_{total} = 3.0\ \text{s}
$$

Thus, the output becomes:

$$
\delta_{out}(t) =
\begin{cases}
\delta_{avoid}(t), & 0 \le t-t_0 < T_{total} \
\delta_{in}(t), & t-t_0 \ge T_{total}
\end{cases}
$$

This law produces a smooth S-shaped maneuver. The vehicle first deviates, then returns progressively to the original alignment, avoiding abrupt steering discontinuities.

### 8.6 Priority of the avoidance maneuver

A very important point is that while `avoid_active == true`, the nominal steering input is ignored:

```matlab
steering_out = steering_avoid;
```

This means that the local avoidance maneuver has priority over the trajectory-following steering command. Architecturally, this is correct because immediate obstacle avoidance must dominate the nominal path-tracking objective during the event window.

### 8.7 Direction flag and coupling with the lighting system

During the active maneuver, the function sets:

```matlab
direction = 1;
```

This flag is not only useful as an internal status, but also because it can be propagated to the lighting logic. In your implementation, this event is later used by `LightingControl` through the `avoid` flag in order to activate an event-based visual signal on the `ledStrip`.

Therefore, `avoidCone` does not operate in isolation: it modifies the steering behavior and simultaneously feeds an event signal that the lighting subsystem can interpret.

### 8.8 Role of this section within the complete system

This section brings together three key ideas that occur after perception but before final actuation:

1. **distance acquisition**, through `addDepth`,
2. **context-aware longitudinal decision making**, through `trafficSignsLogic`,
3. **segment-based and event-based turn signal activation**, through `LightingControl`,
4. **local reactive obstacle avoidance**, through `avoidCone`.

Together, these functions enrich the self-driving pipeline in two essential ways. First, they transform visual detections into spatially meaningful information. Second, they make the vehicle behavior more complete and realistic by allowing it not only to perceive and decide, but also to signal its maneuvers and react to local obstructions without abandoning the global navigation objective.