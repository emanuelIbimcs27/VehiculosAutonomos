---
layout: default
title: Advanced Traffic and Safety Logic
nav_order: 8
parent: CPS IoT Competition 2026
permalink: /CPS/logica-avanzada-trafico/
---
# Advanced Traffic and Safety Logic

## 11. Unified logic for traffic signs, traffic lights, pickup pedestrian, and rule-based braking: `trafficSignsLogic`

As the project evolved, the vehicle logic stopped being limited to reacting only to simple signs such as STOP, YIELD, or roundabouts. It became necessary to develop a more advanced decision layer, capable of integrating several environmental events within a single function: regulatory signs, traffic lights, detection of a passenger for pickup, and an external pedestrian braking flag.

The `trafficSignsLogic` function represents precisely that evolution. It is a hybrid decision block that combines visual perception, timing, internal memory, and a hierarchy of priorities in order to determine the final vehicle speed according to the observed context.

### 11.1 Objective of the function

The function receives:

- a nominal speed `speed_in`
- the matrix of detections enriched with depth
- the current time `t`
- an external flag `pedestrian_flag`

and returns:

- a final speed `speed_out`
- a flag `stop_ligth` representing the stopping state or brake light

Formally, the output can be interpreted as:

$$
(speed\_out,\ stop\_ligth) = f(speed\_in,\ detections,\ t,\ pedestrian\_flag)
$$

The objective is for the vehicle to be able to:

- stop at STOP signs,
- momentarily yield at YIELD signs,
- reduce speed in roundabouts,
- stop if it detects a pedestrian or an immediate frontal safety event,
- approach and stop to simulate passenger pickup,
- respond properly to traffic light states and decide when to commit to crossing an intersection.

### 11.2 Full code

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

    % person
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

    % STOP
    if class_id == 5 && prob > 0.9 && dist < 1.3 && frontal
        stop_detected = true;
    end

    % YIELD
    if class_id == 7 && prob > 0.9 && dist < 1.5 && frontal
        yield_detected = true;
    end

    % ROUND
    if class_id == 4 && prob > 0.8 && dist < 2.0 && frontal
        round_detected = true;
    end

    % PERSON (right side)
    if class_id == 2 && prob > 0.8 && dist < 7.3 && right_side
        person_detected = true;
    end

    % TRAFFIC LIGHT (frontal only)
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

% PEDESTRIAN STOP (HIGH PRIORITY)
if pedestrian_flag == 1
    speed_out = 0;
    stop_ligth = 1;
    return;
end

% STOP
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

% YIELD
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

% PERSON (pickup)
if person_detected && ~person_active && ~person_done
    person_active = true;
    t_person_start = t;
    person_phase = 1;
end

if person_active

    dt = t - t_person_start;

    % Phase 1: move forward
    if dt < 5
        speed_out = speed_in; 

    % Phase 2: stop
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

% TRAFFIC LIGHT
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

% ROUND
if round_detected
    speed_out = 0.5 * speed_in;
end

end
````

### 11.3 Use of persistent variables and temporal memory

The function relies on several persistent variables:

```matlab
persistent stop_active t_start stop_done
persistent yield_active t_yield_start yield_done
persistent person_active t_person_start person_phase person_done
persistent traffic_state
persistent green_counter
```

These variables turn the function into a hybrid state machine. It does not react only instantaneously to the content of a frame, but instead remembers temporal information about events that have already been activated. This is essential because many vehicle maneuvers have an extended duration in time. For example, a STOP must remain active for several seconds even if the sign momentarily disappears from view, and a pickup logic requires several consecutive phases of motion and stopping.

Conceptually, the function no longer behaves like a simple algebraic rule, but rather as a system with internal memory:

$$
\mathbf{x}_{k+1} = g(\mathbf{x}_k,\ \mathbf{u}_k,\ \mathbf{y}_k)
$$

where $\mathbf{x}_k$ represents the internal state of the logic at instant $k$.

### 11.4 Base object detection and environment semantics

During each iteration, the function loops through the ten available detections:

```matlab
for i = 1:10
    class_id = detections(1,i);
    prob     = detections(2,i);
    dist     = detections(7,i);

    x1 = detections(3,i);
    x2 = detections(5,i);
    cx = (x1 + x2)/2;

    frontal = abs(cx - 320) < 100;
    right_side = cx > 360;
```

Two fundamental geometric criteria appear here:

* **frontal**: the object is approximately centered in the visual field
* **right_side**: the object appears on the right side of the image

Mathematically:

$$
frontal \iff |c_x - 320| < 100
$$

$$
right_side \iff c_x > 360
$$

where:

$$
c_x = \frac{x_1 + x_2}{2}
$$

These criteria allow the same visual detection to be interpreted differently according to its relative position. For example, a person on the right side may represent a passenger waiting for pickup, while a frontal detection may represent an immediate threat along the vehicle trajectory.

### 11.5 STOP logic

The STOP activation condition was:

$$
c_i = 5,\qquad \rho_i > 0.9,\qquad \hat{z}_i < 1.3,\qquad frontal
$$

In code:

```matlab
if class_id == 5 && prob > 0.9 && dist < 1.3 && frontal
    stop_detected = true;
end
```

When the sign is detected and had not been processed previously, the routine enters a stop state. If the activation instant is denoted by $t_0$, then the output behaves as:

$$
v_{out}(t) =
\begin{cases}
0, & 0 \le t-t_0 < 5 \
v_{in}(t), & t-t_0 \ge 5
\end{cases}
$$

In addition, during this phase the following flag is activated:

$$
stop_ligth = 1
$$

representing the stopping state or brake light.

### 11.6 YIELD logic

The condition for a YIELD sign is:

$$
c_i = 7,\qquad \rho_i > 0.9,\qquad \hat{z}_i < 1.5,\qquad frontal
$$

When this condition is met, the vehicle stops for 2 seconds:

$$
v_{out}(t) =
\begin{cases}
0, & 0 \le t-t_y < 2 \
v_{in}(t), & t-t_y \ge 2
\end{cases}
$$

where $t_y$ is the YIELD activation instant.

This reproduces a logic that is less strict than STOP, but still sufficient to force a brief pause before continuing.

### 11.7 Roundabout logic

The roundabout sign is detected with:

$$
c_i = 4,\qquad \rho_i > 0.8,\qquad \hat{z}_i < 2.0,\qquad frontal
$$

and in that case the speed is reduced to:

$$
v_{out}(t) = 0.5,v_{in}(t)
$$

This reduction models more cautious driving in circular zones, where the vehicle must navigate at lower speed in order to maintain stability and control.

### 11.8 Person logic for pickup

The detection of a candidate person for pickup is based on:

$$
c_i = 2,\qquad \rho_i > 0.8,\qquad \hat{z}_i < 7.3,\qquad right_side
$$

This condition is important because not every person should be interpreted as a passenger. The restriction that the person must appear on the right side of the image reflects the fact that the passenger is standing on the sidewalk, in a position where the autonomous taxi could approach for pickup.

When this condition is activated, the function enters a temporal routine with two phases:

1. **Approach phase**
   During the first 5 seconds:

   $$
   0 \le dt < 5 \Rightarrow v_{out}(t) = v_{in}(t)
   $$

2. **Stopping phase for pickup**
   During the following 4 seconds:

   $$
   5 \le dt < 9 \Rightarrow v_{out}(t) = 0
   $$

and the brake light is activated:

$$
stop_ligth = 1
$$

Finally, the maneuver ends and is marked as completed. This implements a credible service approach-and-stop sequence.

### 11.9 Traffic light logic and WAIT/GO state machine

Traffic light control was structured as a state machine with two modes:

* `traffic_state = 0`: **WAIT**
* `traffic_state = 1`: **GO**

In addition, a commitment distance was defined:

```matlab
commit_dist = 1.2;
```

#### WAIT state

While the system is in the waiting state, consecutive green frames are accumulated:

```matlab
if traffic_green
    green_counter = green_counter + 1;
else
    green_counter = 0;
end
```

This means that the vehicle does not react to a single green frame, but instead requires temporal stability. If the green signal persists for more than three frames and the traffic light is sufficiently close, the vehicle commits to crossing:

$$
green_counter > 3 \quad \text{and} \quad traffic_dist < 1.2
$$

On the other hand, if red or yellow is detected, the vehicle stops:

$$
traffic_red \lor traffic_yellow \Rightarrow v_{out}(t)=0
$$

#### GO state

Once the crossing has been committed, the logic enters the `GO` state and stops reacting to the traffic light:

```matlab
if traffic_state == 1
    speed_out = speed_in;
```

The system returns to the WAIT state only when the distance to the traffic light exceeds a certain value:

$$
traffic_dist > 3.5
$$

This logic avoids unrealistic behavior such as stopping in the middle of the intersection if the signal changes color while the vehicle is already crossing.

### 11.10 Maximum priority of the external pedestrian flag

The first condition checked inside the function is:

```matlab
if pedestrian_flag == 1
    speed_out = 0;
    stop_ligth = 1;
    return;
end
```

This means that any external pedestrian braking instruction has absolute priority over all the other logic layers. In terms of safety, this hierarchy is correct: if there is evidence of immediate frontal risk, the regulatory logic must completely yield and stop the vehicle.

---

## 12. Robust safety braking layer based on detection and depth: `pedestrianStopLogic`

To reinforce system safety, a specific function called `pedestrianStopLogic` was implemented. Although it was originally intended for the case of a person crossing, in its current form it functions as a general frontal safety layer, combining visual detection with depth in order to decide whether there is a nearby obstacle in front of the vehicle.

This function is especially important because it introduces an additional verification layer independent of the traffic sign logic. Its role is not to interpret traffic rules, but to protect the vehicle against an immediate risk.

### 12.1 Full code

```matlab
function stop_flag = pedestrianStopLogic(detections, depth_frame)

persistent stop_state counter_on counter_off

if isempty(stop_state)
    stop_state = false;
    counter_on = 0;
    counter_off = 0;
end

% 1. DETECTION (gating)
valid_object = false;

for i = 1:10

    class_id = detections(1,i);
    prob     = detections(2,i);
    dist     = detections(7,i);

    if prob < 0.8 || dist == 0
        continue;
    end

    x1 = detections(3,i);
    x2 = detections(5,i);
    cx = (x1 + x2)/2;

    if abs(cx - 320) < 80 && dist < 3.0

        if class_id ~= 0
            valid_object = true;
        end

    end
end

% 2. ROI IN DEPTH
roi = depth_frame(200:350, 260:380);

% 3. ROBUST PROCESSING
valid_pixels = roi(roi > 0);

if isempty(valid_pixels)
    obstacle_close = false;
else
    d_sorted = sort(valid_pixels(:));
    idx = max(1, round(0.1 * length(d_sorted)));
    d_min = d_sorted(idx);

    obstacle_close = d_min < 0.5;
end

% 4. HYSTERESIS
if valid_object && obstacle_close
    counter_on = counter_on + 1;
    counter_off = 0;
else
    counter_off = counter_off + 1;
    counter_on = 0;
end

% Activate STOP (3 consistent frames)
if counter_on > 2
    stop_state = true;
end

% Release STOP (5 safe frames)
if counter_off > 4
    stop_state = false;
end

% OUTPUT
stop_flag = stop_state;

end
```

### 12.2 Phase 1: gating through visual detection

The first stage verifies whether there is a visually valid object in the frontal region. The conditions used were:

* confidence $\rho_i \ge 0.8$
* estimated distance $\hat{z}_i > 0$
* centered horizontal position:

$$
|c_{x,i} - 320| < 80
$$

* distance less than 3.0 m
* class different from cone:

$$
c_i \neq 0
$$

Together:

$$
\rho_i \ge 0.8,\qquad \hat{z}*i > 0,\qquad |c*{x,i}-320|<80,\qquad \hat{z}_i<3.0,\qquad c_i \neq 0
$$

If at least one detection satisfies these conditions, the variable `valid_object` is activated. This filters the problem down to objects that are plausibly relevant in front of the vehicle.

### 12.3 Phase 2: spatial validation through a depth ROI

Once visual evidence exists, the function analyzes a fixed region of the depth map:

```matlab
roi = depth_frame(200:350, 260:380);
```

This region corresponds approximately to a lower-central window of the image, that is, the zone of space directly in front of the vehicle where an imminent obstacle would be most dangerous.

If we define:

$$
\mathcal{R} = {D(u,v);|; 200 \le u \le 350,\ 260 \le v \le 380,\ D(u,v) > 0}
$$

then the spatial decision is made only from that subset of valid pixels of the depth map.

### 12.4 Use of the 10th percentile as a robust estimator

Instead of using the absolute minimum depth, the function sorts the values and takes the 10th percentile:

```matlab
d_sorted = sort(valid_pixels(:));
idx = max(1, round(0.1 * length(d_sorted)));
d_min = d_sorted(idx);
```

This is equivalent to estimating:

$$
d_{10%} = Q_{0.10}(\mathcal{R})
$$

where $Q_{0.10}$ is the 10th quantile. This decision is very appropriate because it avoids a single spurious pixel, unrealistically close, from triggering a false braking event. The 10th percentile remains sensitive to nearby obstacles, but is much more robust than taking the raw minimum.

An obstacle is then considered close if:

$$
d_{10%} < 0.5
$$

### 12.5 Temporal hysteresis

Braking activation does not depend on a single instantaneous observation, but on a logic with temporal hysteresis. Two counters are used:

* `counter_on`: number of consecutive frames with obstacle evidence
* `counter_off`: number of consecutive frames without obstacle evidence

The logic is:

```matlab
if valid_object && obstacle_close
    counter_on = counter_on + 1;
    counter_off = 0;
else
    counter_off = counter_off + 1;
    counter_on = 0;
end
```

The system activates the STOP state when:

$$
counter_on > 2
$$

that is, after three consistent risk frames. And it releases the STOP state when:

$$
counter_off > 4
$$

that is, after five consecutive safe frames.

This hysteresis reduces the effect of noise and avoids rapid oscillations between braking and moving forward.

### 12.6 Module output and coupling with the main logic

The final result is:

```matlab
stop_flag = stop_state;
```

This flag is connected as an input to `trafficSignsLogic`, where it has the highest priority. As a consequence, the decision architecture is hierarchically organized as follows:

1. `pedestrianStopLogic` evaluates immediate frontal risk
2. if risk is detected, it emits `stop_flag = 1`
3. `trafficSignsLogic` receives that flag and commands the vehicle to stop before considering any other rule

This design is correct from the safety standpoint, because it clearly separates two levels of decision-making:

* a layer of **immediate reactive safety**
* a layer of **regulatory and contextual behavior**

## Role of this section within the complete system

This section represents the most advanced decision layer of the vehicle. While the basic functions reacted to individual signs, here the system begins to integrate multiple simultaneous environmental events: traffic lights, pedestrians, pickups, regulatory signs, and immediate safety criteria.

In other words, this part of the project is the one that comes closest to the behavior of a real autonomous vehicle within a simplified urban scene. It is not limited to following a trajectory or recognizing objects, but rather organizes priorities, manages temporal states, and decides how the vehicle should behave according to the complete context of the environment.
---