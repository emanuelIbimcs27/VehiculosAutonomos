---
layout: default
title: Advanced Traffic Decision Logic
nav_order: 8
parent: CPS IoT Competition 2026
permalink: /Methodology/Advanced-Traffic/
---

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


## 12. Robust safety braking layer based on detection and depth: `crosswalk_stop`

To reinforce system safety, a specific function called `crosswalk_stop` was implemented. Although it was originally intended for the case of a person crossing, in its current form it functions as a general frontal safety layer, combining visual detection with depth in order to decide whether there is a nearby obstacle in front of the vehicle.

This function is especially important because it introduces an additional verification layer independent of the traffic sign logic. Its role is not to interpret traffic rules, but to protect the vehicle against an immediate risk.

### 12.1 Full code

```matlab
function stop_flag = crosswalk_stop(detections)

% ========================
% Memoria persistente
% ========================
persistent stop_memory

if isempty(stop_memory)
    stop_memory = 0;
end

% ========================
% Parámetros
% ========================
PROB_TH = 0.8;
DIST_TH = 2.0;

ZONA_SEGURA_X_MIN = 350;
ZONA_SEGURA_X_MAX = 650;

ZONA_RIESGO_X_MAX = 300;

% ========================
% Iterar objetos
% ========================
for i = 1:10

    clase = detections(1,i);
    prob  = detections(2,i);
    x1    = detections(3,i);
    x2    = detections(5,i);
    dist  = detections(7,i);

    if prob == 0
        continue;
    end

    if clase ~= 2
        continue;
    end

    if prob < PROB_TH
        continue;
    end

    % Centro de la caja
    x_center = (x1 + x2)/2;

    % Zonas
    en_zona_segura = (x_center >= ZONA_SEGURA_X_MIN) && (x_center <= ZONA_SEGURA_X_MAX);
    en_zona_riesgo = (x_center <= ZONA_RIESGO_X_MAX);

    % ========================
    % Memoria
    % ========================

    if en_zona_riesgo && dist <= DIST_TH
        stop_memory = 1;
    end

    if en_zona_segura
        stop_memory = 0;
    end

end

% ========================
% Salida final
% ========================
stop_flag = stop_memory;

end


```

## 12.2 Phase 1: Detection filtering

The function processes the set of detections to identify valid pedestrian candidates. For each detected object, the following conditions are evaluated:

$$
c_i = 2,\qquad \rho_i > 0.8,\qquad \hat{z}_i \leq 2.0
$$

where:

* $c_i$ is the class (pedestrian),
* $\rho_i$ is the detection confidence,
* $\hat{z}_i$ is the estimated depth.

Only detections satisfying these constraints are considered for further analysis.

---

## 12.3 Phase 2: Spatial classification

For each valid pedestrian detection, the horizontal position is computed as:

$$
x_c = \frac{x_1 + x_2}{2}
$$

Based on this value, the pedestrian is classified into two spatial regions:

* **Risk zone:**

$$
x_c \leq 300
$$

* **Safe zone:**

$$
350 \leq x_c \leq 650
$$

The risk zone corresponds to pedestrians entering or crossing the vehicle’s path, while the safe zone represents pedestrians that have already cleared the lane.

---

## 12.4 Phase 3: Temporal memory activation

A persistent memory variable `stop_memory` is used to retain the stop condition across frames.

The stop condition is activated when a pedestrian is detected within the risk zone and within a critical distance:

$$
x_c \leq 300 \quad \text{and} \quad \hat{z}_i \leq 2.0
$$

Under this condition:

$$
stop\_memory = 1
$$

This ensures that the vehicle reacts immediately to pedestrians entering its path.

---

## 12.5 Phase 4: Release condition

The stop condition is cleared only when the pedestrian reaches the safe zone:

$$
350 \leq x_c \leq 650
$$

Under this condition:

$$
stop\_memory = 0
$$

This guarantees that the vehicle remains stopped until the pedestrian has fully cleared the crossing area.

---

## 12.6 Phase 5: Output decision

The final output of the function is defined as:

$$
stop\_flag = stop\_memory
$$

This design introduces temporal consistency into the system, preventing oscillations due to noisy detections and ensuring a robust and realistic stopping behavior in crosswalk scenarios.

## Role of this section within the complete system

This section represents the most advanced decision layer of the vehicle. While the basic functions reacted to individual signs, here the system begins to integrate multiple simultaneous environmental events: traffic lights, pedestrians, pickups, regulatory signs, and immediate safety criteria.

In other words, this part of the project is the one that comes closest to the behavior of a real autonomous vehicle within a simplified urban scene. It is not limited to following a trajectory or recognizing objects, but rather organizes priorities, manages temporal states, and decides how the vehicle should behave according to the complete context of the environment.
---
