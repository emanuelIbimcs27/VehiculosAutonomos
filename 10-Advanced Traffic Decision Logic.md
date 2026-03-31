

## 11. Unified logic for trafficLightOnly Function`

The function `trafficLightOnly` implements a dedicated decision layer for traffic light handling, separated from the main traffic logic to improve modularity.

It processes perception detections to identify traffic light states (red, yellow, green) based on class, confidence, distance, and frontal position. A two-state machine is used:

* **WAIT state:** the vehicle stops if red or yellow is detected, and only commits to crossing after several consistent green detections within a defined distance.
* **GO state:** once committed, the vehicle proceeds and ignores further light changes until the intersection is cleared.

The function outputs a binary flag `traffic_light_flag`, where:

* `1` indicates stop,
* `0` indicates go.

This design ensures stable and realistic intersection behavior while preventing unsafe mid-crossing stops.

### 11.1 Objective of the function

The function receives:

* the matrix of detections enriched with depth.

It returns:

* a binary flag `traffic_light_flag`, where `1` indicates stop and `0` indicates go.

The function uses persistent variables (`traffic_state` and `green_counter`) to maintain temporal memory of the traffic light state. This allows the implementation of a two-state machine (WAIT/GO), ensuring stable decision-making by requiring consistent green detections before committing to cross and preventing abrupt stops while traversing the intersection.

### 11.2 Full code

```matlab
function traffic_light_flag = trafficLightOnly(detections)

% 1 = PARO
% 0 = AVANZA

persistent traffic_state
persistent green_counter

if isempty(traffic_state)
    traffic_state = 0; % 0 = WAIT, 1 = GO
    green_counter = 0;
end

traffic_light_flag = 0;

traffic_red = false;
traffic_green = false;
traffic_yellow = false;
traffic_dist = single(999);

% =========================
% DETECCIÓN
% =========================
for i = 1:10

    class_id = detections(1,i);
    prob     = detections(2,i);
    dist     = detections(7,i);

    x1 = detections(3,i);
    x2 = detections(5,i);
    cx = (x1 + x2)/2;

    frontal = abs(cx - 320) < 100;

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

% =========================
% LÓGICA DE DECISIÓN
% =========================
commit_dist = 1.2;

% WAIT
if traffic_state == 0

    if traffic_green
        green_counter = green_counter + 1;
    else
        green_counter = 0;
    end

    if traffic_red || traffic_yellow
        traffic_light_flag = 1; % PARO
        return;
    end

    if green_counter > 3
        if traffic_dist < commit_dist
            traffic_state = 1; % GO
        end
    end
end

% GO
if traffic_state == 1

    traffic_light_flag = 0; % AVANZA

    if traffic_dist > 3.5
        traffic_state = 0;
        green_counter = 0;
    end
end

end
````

### 11.3 Use of persistent variables and temporal memory

The function relies on persistent variables (`traffic_state` and `green_counter`) to retain temporal context across frames. This enables the implementation of a stable WAIT/GO state machine, ensuring consistent traffic light interpretation and preventing oscillatory or unsafe decisions near intersections.


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
