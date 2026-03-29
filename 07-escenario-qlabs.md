---
layout: default
title: QLabs Scenario Generation
nav_order: 5
parent: CPS IoT Competition 2026
permalink: /CPS/escenario-qlabs/
---
# QLabs Scenario Generation

## 7. Programmatic generation of the competition scenario in QLabs

In addition to the design of the autonomous driving algorithm, an essential part of the project was the construction of the simulation environment in which the algorithm would be validated. For this purpose, a script was developed to programmatically generate the competition scenario within **QLabs**, incorporating not only the geometric infrastructure of the map, but also dynamic and static elements relevant to the vehicle’s behavior: walls, traffic signs, crosswalks, traffic lights, a static person for pickup simulation, a dynamic pedestrian crossing the street, and a traffic cone as a competition obstacle.

From an engineering perspective, this script does not serve only an aesthetic or visual purpose. Its true objective is to create a controlled, reproducible, and sufficiently rich testing environment to evaluate vehicle performance under conditions close to those of a simplified urban scene. In this way, the scenario stops being a passive background and becomes an active part of system validation.

### 7.1 Objective of the scenario generator

The general objective of this routine is to build an instance of the environment in which the vehicle can be tested under different navigation situations. These situations include:

- driving over the competition map,
- interaction with traffic signs,
- response to traffic lights with changing states,
- detection and avoidance of a cone,
- simulation of picking up a passenger waiting on the sidewalk,
- detection of and response to a pedestrian crossing a crosswalk.

In functional terms, this module provides the physical and logical context within which the self-driving algorithm operates. For this reason, its role within the complete system is fundamental.

### 7.2 Selection of the vehicle spawn point

```matlab
%% Configurable Params

% Choose spawn location of QCar
% 1 => calibration location
% 2 => taxi hub area
spawn_location = 2;
````

This parameter makes it possible to select the initial position of the QCar. There are two possible configurations:

* `spawn_location = 1`: calibration location
* `spawn_location = 2`: taxi hub area

This is useful because the same scenario can be used for different purposes. A calibration position is useful for initial validations of sensors, spatial reference, or system startup, while the taxi hub position allows execution of the complete navigation and pickup logic from an operating point that is more representative of the project workflow.

### 7.3 Cleanup and resource management function

```matlab
function cleanupQLabs(qlabs)
    qlabs.close()
end
```

The cleanup function is responsible for correctly closing the connection with QLabs. This type of routine is important because it prevents open sessions or residual actors from remaining in memory after a failed execution or an abrupt termination. From the perspective of experimental robustness, properly closing the session guarantees that the next experiment begins from a clean state.

### 7.4 Dynamic traffic and pedestrian controller

One of the most relevant parts of the script is the `trafficLightController` function, which is responsible for simultaneously handling the traffic light states and the motion of the dynamic pedestrian.

```matlab
function trafficLightController(qlabs)
    disp('Starting traffic and pedestrian controller...')
    try
        % Traffic light initialization
        t1 = QLabsTrafficLight(qlabs);
        t2 = QLabsTrafficLight(qlabs);
        t3 = QLabsTrafficLight(qlabs);
        t4 = QLabsTrafficLight(qlabs);

        % intersection 1
        t1.spawn_id_degrees(1, [0.6, 1.55, 0.006], [0,0,0], [0.1, 0.1, 0.1], 0, false);
        t2.spawn_id_degrees(2, [-0.6, 1.28, 0.006], [0,0,90], [0.1, 0.1, 0.1], 0, false);
        t3.spawn_id_degrees(3, [-0.37, 0.3, 0.006], [0,0,180], [0.1, 0.1, 0.1], 0, false);
        t4.spawn_id_degrees(4, [0.75, 0.48, 0.006], [0,0,-90], [0.1, 0.1, 0.1], 0, false);
                
        % Reference to pedestrian (ID 20)
        hObstacle = QLabsPerson(qlabs);
        hObstacle.actorNumber = 20; 
        
        % Coordinates
        LOC_A = [1.441, 0.569, 0.005]; 
        LOC_B = [1.441, 0.809, 0.005]; 
        hacia_B = true; 
        
        intersection1Flag = 0;
        
        clear cleanup;
        cleanup = onCleanup(@() qlabs.close());

        while(true)
            fprintf('Traffic light cycle: %d\n', intersection1Flag);
            
            % Simplified color logic to avoid reference errors
            if intersection1Flag == 0
                t1.set_color(3); t3.set_color(3); t2.set_color(1); t4.set_color(1);
            elseif intersection1Flag == 1
                t2.set_color(2); t4.set_color(2);
            elseif intersection1Flag == 2
                t1.set_color(1); t3.set_color(1); t2.set_color(3); t4.set_color(3);
            elseif intersection1Flag == 3
                t1.set_color(2); t3.set_color(2);
            end

            % Pedestrian motion
            if hacia_B
                hObstacle.move_to(LOC_B, 0.3, 1);
                hacia_B = false;
            else
                hObstacle.move_to(LOC_A, 0.3, 1);
                hacia_B = true;
            end

            intersection1Flag = mod((intersection1Flag + 1), 4);
            pause(5);
        end
    catch ME
        fprintf('Controller error: %s\n', ME.message);
        % qlabs is not closed here in order to inspect the error in console
    end
end
```

### 7.5 Temporal logic of the traffic light system

The variable `intersection1Flag` functions as a discrete state index that evolves cyclically according to:

$$
intersection1Flag_{k+1} = (intersection1Flag_k + 1) \bmod 4
$$

This generates a periodic cycle with four phases:

$$
0 \rightarrow 1 \rightarrow 2 \rightarrow 3 \rightarrow 0 \rightarrow \dots
$$

Each phase represents a different combination of traffic light states. Although the script does not explicitly model all the complexities of a real urban traffic system, it does generate enough alternation to force the vehicle to detect colors, decide whether it should wait, and determine the appropriate moment to commit to crossing the intersection.

This structure is very useful because it introduces a dynamic yet controlled environment. By changing every five seconds:

$$
T_{cycle} = 5\ \text{s}
$$

a temporal signal is obtained that is slow enough to be captured and processed by the vehicle’s perception system, but dynamic enough to test its decision-making logic.

### 7.6 Cyclic motion of the dynamic pedestrian

The pedestrian associated with actor 20 moves between two points:

```matlab
LOC_A = [1.441, 0.569, 0.005]; 
LOC_B = [1.441, 0.809, 0.005];
```

The pedestrian trajectory can be described as a periodic oscillation between two extremes:

$$
A \rightarrow B \rightarrow A \rightarrow B \rightarrow \dots
$$

The Boolean variable `hacia_B` controls the direction of motion. This design makes it possible to simulate a pedestrian repeatedly crossing a crosswalk, which is ideal for testing the pedestrian detection module and the vehicle braking logic.

From a validation standpoint, this choice is very convenient because the pedestrian event does not depend on randomness: it always occurs in the same area of the map, in a repeatable way, and at a controlled speed.

### 7.7 MATLAB and QLabs environment configuration

Before constructing the scenario, the script verifies that the QLabs library is included in the MATLAB path and stops any previously active RT models:

```matlab
newPathEntry = fullfile(getenv('QAL_DIR'), '0_libraries', 'matlab', 'qvl');
...
qc_stop_model('tcpip://localhost:17000', 'QCar2_Workspace')
...
qc_stop_model('tcpip://localhost:17000', 'QCar2_Workspace_studio')
```

It then establishes the connection to QLabs:

```matlab
qlabs = QuanserInteractiveLabs();
connection_established = qlabs.open('localhost');
```

and clears the virtual world by removing previously spawned actors:

```matlab
num_destroyed = qlabs.destroy_all_spawned_actors();
```

These operations are important because they guarantee that each experiment execution begins from a clean and consistent environment. This avoids results contaminated by residual objects or prior simulator configurations.

### 7.8 Floor construction and geometric reference of the scenario

```matlab
x_offset = 0.13;
y_offset = 1.67;
hFloor = QLabsQCarFlooring(qlabs);
hFloor.spawn_degrees([x_offset, y_offset, 0.001],[0, 0, -90]);
```

Here, the floor of the scenario is defined with a translation $(x_{offset}, y_{offset})$ and a rotation of (-90^\circ). This stage is important because it establishes the physical reference frame on which all other scenario elements are mounted. Correct floor placement ensures that the distribution of walls, signs, and actors matches the coordinates used by the vehicle trajectory and the topological map of nodes.

### 7.9 Construction of walls and physical boundaries

The script generates multiple walls to delimit the circuit:

```matlab
hWall = QLabsWalls(qlabs);
hWall.set_enable_dynamics(false);

for y = 0:4
    hWall.spawn_degrees([-2.4 + x_offset, (-y*1.0)+2.55 + y_offset, 0.001], [0, 0, 0]);
end

for x = 0:4
    hWall.spawn_degrees([-1.9+x + x_offset, 3.05+ y_offset, 0.001], [0, 0, 90]);
end
...
```

These walls serve a dual function. On one hand, they reproduce the geometry of the competition circuit. On the other hand, they act as physical visual and spatial reference elements within QLabs. Disabling wall dynamics implies that they behave as static elements of the environment, which is appropriate because their purpose is to delimit the infrastructure and not to interact dynamically with the vehicle.

### 7.10 Vertical and horizontal traffic signaling

The scenario incorporates several types of road signaling. These include:

* STOP signs,
* roundabout signs,
* YIELD signs,
* crosswalks,
* white guide lines.

For example, STOP signs are generated by:

```matlab
myStopSign = QLabsStopSign(qlabs);

myStopSign.spawn_degrees([-1.5, 3.6, 0.006], ...
                        [0, 0, -35], ...
                        [0.1, 0.1, 0.1], ...
                        false);  

myStopSign.spawn_degrees([-1.5, 2.2, 0.006], ...
                        [0, 0, 35], ...
                        [0.1, 0.1, 0.1], ...
                        false);

%x+ side
myStopSign.spawn_degrees([2.410, 0.206, 0.006], ...
                        [0, 0, -90], ...
                        [0.1, 0.1, 0.1], ...
                        false); 

myStopSign.spawn_degrees([1.766, 1.697, 0.006], ...
                        [0, 0, 90], ...
                        [0.1, 0.1, 0.1], ...
                        false);
```

and crosswalks by:

```matlab
myCrossWalk = QLabsCrosswalk(qlabs);
myCrossWalk.spawn_degrees   ([-2 + x_offset, -1.475 + y_offset, 0.01], ...
                            [0,0,0], ...
                            [0.1,0.1,0.075], ...
                            0);

myCrossWalk.spawn_degrees   ([-0.5, 0.95, 0.006], ...
                            [0,0,90], ...
                            [0.1,0.1,0.075], ...
                            0);

myCrossWalk.spawn_degrees   ([0.15, 0.32, 0.006], ...
                            [0,0,0], ...
                            [0.1,0.1,0.075], ...
                            0);

myCrossWalk.spawn_degrees   ([0.75, 0.95, 0.006], ...
                            [0,0,90], ...
                            [0.1,0.1,0.075], ...
                            0);

myCrossWalk.spawn_degrees   ([0.13, 1.57, 0.006], ...
                            [0,0,0], ...
                            [0.1,0.1,0.075], ...
                            0);

myCrossWalk.spawn_degrees   ([1.45, 0.95, 0.006], ...
                            [0,0,90], ...
                            [0.1,0.1,0.075], ...
                            0);
```

The explicit presence of these elements is key, since the perception model and the vehicle traffic logic depend directly on them. In other words, the scenario was designed to contain exactly the objects that the self-driving pipeline needs to detect and interpret.

### 7.11 Static person for pickup simulation

```matlab
hPersonStatic = QLabsPerson(qlabs);

% Parameters according to the selected coordinates
loc_persona = [-0.424, 4.55, 0.005];
rot_persona = [0, 0, -90];
scale_persona = [0.1, 0.1, 0.1];
id_persona = 10;
config_persona = 11;

% Spawn the person
hStatus = hPersonStatic.spawn_id_degrees(id_persona, loc_persona, rot_persona, scale_persona, config_persona, true);

if hStatus == 0
    disp('Person successfully spawned on the sidewalk.');
else
    disp('Error spawning the person. Check the QLabs connection.');
end
```

This static person represents the passenger that the vehicle must simulate picking up. Its location on the sidewalk is intentional, since it forces the system to distinguish between a person waiting at a pickup point and a pedestrian actively crossing the street.

From the project standpoint, this actor introduces a higher-level logic associated with the autonomous taxi use case.

### 7.12 Dynamic person crossing the street

```matlab
hPersonObstacle = QLabsPerson(qlabs);
% Point A (right sidewalk), Point B (left sidewalk)
LOC_A_OBSTACULO = [1.441, 0.62, 0.005]; 
LOC_B_OBSTACULO = [1.441, 0.81, 0.005]; 

% Initial spawn of the obstacle (ID 20 to avoid collision with the other one)
hPersonObstacle.spawn_id_degrees(20, LOC_A_OBSTACULO, [0, 0, -180], [0.1, 0.1, 0.1], 11, true);
disp('Dynamic person ready to cross (ID 20).');
```

This pedestrian is the actor that repeatedly crosses a crosswalk. Its function is to feed the braking logic and pedestrian validation logic of the vehicle. Assigning it its own identifier (`ID 20`) makes it possible for the dynamic controller to locate it and update its position consistently.

### 7.13 Cone obstacle

```matlab
hTrafficCone = QLabsTrafficCone(qlabs);

% Configuration according to the selected coordinates
loc_cone = [2.221, 1.017, 0.25];
rot_cone = [0, 0, 0];
scale_cone = [0.2, 0.2, 0.2];
id_cone = 101;

% 1. SPAWN
hStatusCone = hTrafficCone.spawn_id_degrees(id_cone, loc_cone, rot_cone, scale_cone, 0, true);
```

The cone represents a physical competition obstacle and is precisely the object that triggers the `avoidCone` avoidance function. Its placement on the map introduces a local obstruction event that forces the vehicle to temporarily deviate from the nominal trajectory.

From the experimental standpoint, this actor is very valuable because it makes it possible to validate a local navigation reaction without having to redesign the global route.

### 7.14 Cameras in the environment

The script also generates free cameras for observation and debugging:

```matlab
camera1Loc = [0.15, 1.7, 5];
camera1Rot = [0, 90, 0];
camera1 = QLabsFreeCamera(qlabs);
camera1.spawn_degrees(camera1Loc, camera1Rot);

camera1.possess();
```

and another side camera:

```matlab
camera2Loc = [-0.36+ x_offset, -3.691+ y_offset, 2.652];
camera2Rot = [0, 47, 90];
camera2=QLabsFreeCamera(qlabs);
camera2.spawn_degrees (camera2Loc, camera2Rot);
```

These cameras are not part of the autonomous logic of the vehicle, but they are very important for documenting results, inspecting the scene, and visually verifying system behavior during simulation.

### 7.15 Final QCar spawn and RT model startup

The vehicle can be spawned in two predefined positions:

```matlab
calibration_location_rotation = [0, 2.13, 0.005, 0, 0, -90];
taxi_hub_location_rotation = [-1.205, -0.83, 0.005, 0, 0, -44.7];
```

and one of them is then selected according to `spawn_location`:

```matlab
myCar = QLabsQCar2(qlabs);

switch spawn_location
    case 1
        spawn = calibration_location_rotation;
    case 2
        spawn = taxi_hub_location_rotation;
end

myCar.spawn_id_degrees(0, spawn(1:3), spawn(4:6), [1/10, 1/10, 1/10], 1);
```

Subsequently, the RT model associated with the QCar is started:

```matlab
file_workspace = fullfile(getenv('RTMODELS_DIR'), 'QCar2', 'QCar2_Workspace_studio.rt-win64');
pause(2)
system(['quarc_run -D -r -t tcpip://localhost:17000 ', file_workspace]);
pause(3)
```

and finally the traffic controller is activated:

```matlab
trafficLightController(qlabs)
```

At that point, the complete scenario becomes operational: the map exists, the signs are placed, the dynamic pedestrian crosses the street, the static person waits on the sidewalk, the cone is present in the circuit, and the QCar is ready to execute the self-driving algorithm.

## Role of this section within the complete system

This section plays a critical role because it provides the experimental context in which the entire autonomous system is validated. Without a well-defined scenario, the perception, decision, and control modules would not have a meaningful environment in which to operate. Here, precisely that environment is built: one that contains not only geometry, but also dynamic logic and stimuli relevant to the competition.

In other words, this section materializes the world in which the algorithm is tested. Thanks to it, system validation does not take place in an empty scene, but rather in a structured environment that incorporates traffic rules, pedestrian events, obstacles, and autonomous-taxi-style interaction elements.