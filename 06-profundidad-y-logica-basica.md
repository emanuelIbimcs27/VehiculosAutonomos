---
layout: default
title: Depth, Basic Traffic Signs, and Avoidance
nav_order: 4
parent: CPS IoT Competition 2026
permalink: /CPS/profundidad-y-logica-basica/
---

# Depth, Basic Traffic Signs, and Avoidance

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

With this, the output ceases to be a purely visual detection and becomes a detection with geometric content. This transformation is essential for the rest of the system, since the STOP, YIELD, traffic light, pickup, and avoidance functions make decisions based on the estimated distance and not only on the visual presence of the object.

---

## 6. Rule-based logic for traffic signs: `stopLogic`

Once the detections were enriched with distance, a basic traffic-rule logic was implemented so that the vehicle could respond to signs in the environment. The `stopLogic` function constitutes the first rule-based decision layer and was designed to handle three main road elements:

* **STOP** signs
* **YIELD** signs
* **ROUNDABOUT** signs

Its function is to modify the vehicle speed according to the type of detected sign, its confidence, its distance, and its relative position within the visual field.

### 6.1 Objective of the function

The function receives:

* an input speed `speed_in`
* the matrix of enriched detections
* the current time `t`

and returns an adjusted speed:

$$
speed_out = f(speed_in,\ detections,\ t)
$$

The objective is for the vehicle to reduce or temporarily nullify its speed when facing specific traffic signs, following a priority hierarchy consistent with basic driving rules.

### 6.2 Full code

```matlab
function speed_out = stopLogic(speed_in, detections, t)

persistent stop_active t_start stop_done
persistent yield_active t_yield_start yield_done

if isempty(stop_active)
    stop_active = false;
    t_start = 0;
    stop_done = false;

    yield_active = false;
    t_yield_start = 0;
    yield_done = false;
end

speed_out = speed_in;

stop_detected = false;
yield_detected = false;
round_detected = false;

for i = 1:10

    class_id = detections(1,i);
    prob     = detections(2,i);
    dist     = detections(7,i);

    x1 = detections(3,i);
    x2 = detections(5,i);
    cx = (x1 + x2)/2;

    frontal = abs(cx - 320) < 100;

    if class_id == 5 && prob > 0.9 && dist < 1.3 && frontal
        stop_detected = true;
    end

    if class_id == 7 && prob > 0.9 && dist < 1.5 && frontal
        yield_detected = true;
    end

    if class_id == 4 && prob > 0.8 && dist < 2.0 && frontal
        round_detected = true;
    end

end

if stop_detected && ~stop_active && ~stop_done
    stop_active = true;
    t_start = t;
end

if stop_active
    if (t - t_start) < 5
        speed_out = 0;
        return;
    else
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
        return;
    else
        yield_active = false;
        yield_done = true;
    end
end

if ~yield_detected
    yield_done = false;
end

if round_detected
    speed_out = 0.5 * speed_in;
end

end
```

### 6.3 Computation of sign frontalness

The function does not only analyze the class, confidence, and distance of the detection, but also its horizontal position in the image. To do so, it computes the horizontal center of the bounding box:

$$
c_{x,i} = \frac{x_{1,i} + x_{2,i}}{2}
$$

and defines a frontalness condition:

$$
|c_{x,i} - 320| < 100
$$

Here, 320 represents the horizontal center of an image with width 640 pixels. This condition means that only signs appearing approximately in front of the vehicle are considered relevant, discarding those that are too far to the left or right of the visual field.

This decision is very important because it avoids false triggers of the logic caused by objects that were indeed detected, but do not belong to the lane or to the scene directly relevant to the immediate movement of the vehicle.

### 6.4 STOP detection

The condition used to consider a STOP sign valid was:

$$
c_i = 5,\qquad \rho_i > 0.9,\qquad \hat{z}*i < 1.3,\qquad |c*{x,i} - 320| < 100
$$

That is, the detected object must belong to the STOP class, have high confidence, be located at less than 1.3 meters, and appear frontally.

In the code:

```matlab
if class_id == 5 && prob > 0.9 && dist < 1.3 && frontal
    stop_detected = true;
end
```

When this condition is activated and the routine had not yet been executed previously, the function enters a stop state:

```matlab
if stop_detected && ~stop_active && ~stop_done
    stop_active = true;
    t_start = t;
end
```

The vehicle output then becomes:

$$
v_{out}(t) =
\begin{cases}
0, & 0 \le t-t_0 < 5 \
v_{in}(t), & t-t_0 \ge 5
\end{cases}
$$

where $t_0$ is the activation instant.

This means that the vehicle remains completely stopped for 5 seconds, reproducing a clear and verifiable traffic-rule behavior.

### 6.5 YIELD detection

The condition for a yield sign was:

$$
c_i = 7,\qquad \rho_i > 0.9,\qquad \hat{z}*i < 1.5,\qquad |c*{x,i} - 320| < 100
$$

Implemented as:

```matlab
if class_id == 7 && prob > 0.9 && dist < 1.5 && frontal
    yield_detected = true;
end
```

When it is activated, the function enters a 2-second waiting routine:

$$
v_{out}(t) =
\begin{cases}
0, & 0 \le t-t_y < 2 \
v_{in}(t), & t-t_y \ge 2
\end{cases}
$$

where $t_y$ is the YIELD activation instant.

This behavior reflects a less severe logic than STOP, but still sufficient to force the vehicle to yield momentarily before continuing.

### 6.6 Roundabout detection

The roundabout sign was defined with the condition:

$$
c_i = 4,\qquad \rho_i > 0.8,\qquad \hat{z}*i < 2.0,\qquad |c*{x,i} - 320| < 100
$$

In code:

```matlab
if class_id == 4 && prob > 0.8 && dist < 2.0 && frontal
    round_detected = true;
end
```

Unlike STOP and YIELD, this sign does not require the vehicle to stop. Instead, it reduces the nominal speed to 50%:

$$
v_{out}(t) = 0.5,v_{in}(t)
$$

This models a more cautious driving behavior in circular-turn zones without fully interrupting motion.

### 6.7 Use of persistent variables and event memory

The function uses persistent variables to remember whether a maneuver has already been activated:

```matlab
persistent stop_active t_start stop_done
persistent yield_active t_yield_start yield_done
```

This turns the logic into a simple state machine, where the system does not depend only on the current frame, but also on its recent history. Thanks to this:

* a STOP sign does not constantly retrigger the stop while it remains visible
* a YIELD sign does not restart its timer at every iteration
* the system can distinguish between an already executed maneuver and a new sign

In other words, the logic is not purely instantaneous, but temporally coherent.

### 6.8 Priority hierarchy

The function was designed with a clear priority hierarchy:

$$
\text{STOP} > \text{YIELD} > \text{ROUNDABOUT}
$$

This is reflected in the use of `return` inside the STOP and YIELD blocks. If the vehicle is executing a stop due to STOP, the function exits immediately and does not evaluate any other logic. The same happens with YIELD before reaching the roundabout speed reduction.

This decision is important because it imposes a coherent rule-based order: a full stop sign must dominate over any continuous driving behavior.

### 6.9 Role of this section within the complete system

The `stopLogic` function represents the first rule-based decision layer of the vehicle. Its importance lies in the fact that it transforms visually detected objects enriched with depth into concrete speed commands. While the perception module says **what is present in the scene**, this logic says **what the vehicle should do about it**.

Together with `addDepth`, this section marks the transition between perception and interpretation. The system stops being limited to observing objects in an image and begins to act consistently according to basic driving rules.