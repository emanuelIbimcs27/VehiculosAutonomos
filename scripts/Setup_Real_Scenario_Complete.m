%% Configurable Params

% Choose spawn location of QCar
% 1 => calibration location
% 2 => taxi hub area
spawn_location = 2;

%% Traffic Light Function

% Cleanup Function

function cleanupQLabs(qlabs)
    qlabs.close()
end

function trafficLightController(qlabs)
    disp('Iniciando controlador de tráfico y peatón...')
    try
        % Inicialización de semáforos
        t1 = QLabsTrafficLight(qlabs);
        t2 = QLabsTrafficLight(qlabs);
        t3 = QLabsTrafficLight(qlabs);
        t4 = QLabsTrafficLight(qlabs);

        % intersection 1
        t1.spawn_id_degrees(1, [0.6, 1.55, 0.006], [0,0,0], [0.1, 0.1, 0.1], 0, false);
        t2.spawn_id_degrees(2, [-0.6, 1.28, 0.006], [0,0,90], [0.1, 0.1, 0.1], 0, false);
        t3.spawn_id_degrees(3, [-0.37, 0.3, 0.006], [0,0,180], [0.1, 0.1, 0.1], 0, false);
        t4.spawn_id_degrees(4, [0.75, 0.48, 0.006], [0,0,-90], [0.1, 0.1, 0.1], 0, false);
                
        % Referencia al peatón (ID 20)
        hObstacle = QLabsPerson(qlabs);
        hObstacle.actorNumber = 20; 

        
        % Coordenadas peaton 
        LOC_B = [1.441, 0.569, 0.005]; 
        LOC_A = [1.441, 0.809, 0.005]; 

        hacia_B = true; 
        
        intersection1Flag = 0;
        

        clear cleanup;
       
        cleanup = onCleanup(@() qlabs.close());

        while(true)
            fprintf('Ciclo de semáforo: %d\n', intersection1Flag);
            
            
            if intersection1Flag == 0
                t1.set_color(3); t3.set_color(3); t2.set_color(1); t4.set_color(1);
            elseif intersection1Flag == 1
                t2.set_color(2); t4.set_color(2);
            elseif intersection1Flag == 2
                t1.set_color(1); t3.set_color(1); t2.set_color(3); t4.set_color(3);
            elseif intersection1Flag == 3
                t1.set_color(2); t3.set_color(2);
            end

            % Movimiento del peatón
            if hacia_B
                %hObstacle.move_to(LOC_B, hObstacle.WALK, 1);
                hObstacle.move_to(LOC_B, 0.1, 1);
                hacia_B = false;
            else
                %hObstacle.move_to(LOC_A, hObstacle.WALK, 1);
                hObstacle.move_to(LOC_A, 0.1, 1);
                hacia_B = true;
            end

            %pause(6)

            intersection1Flag = mod((intersection1Flag + 1), 4);
            pause(5);
        end
    catch ME
        fprintf('Error en el controlador: %s\n', ME.message);
     
    end
end


%% Set up QLabs Connection and Variables

% MATLAB Path

newPathEntry = fullfile(getenv('QAL_DIR'), '0_libraries', 'matlab', 'qvl');
pathCell = regexp(path, pathsep, 'split');
if ispc  % Windows is not case-sensitive
  onPath = any(strcmpi(newPathEntry, pathCell));
else
  onPath = any(strcmp(newPathEntry, pathCell));
end

if onPath == 0
    path(path, newPathEntry)
    savepath
end

% Stop RT models
try
    qc_stop_model('tcpip://localhost:17000', 'QCar2_Workspace')
catch error
end
pause(1)

try
    qc_stop_model('tcpip://localhost:17000', 'QCar2_Workspace_studio')
    pause(1)
catch error
end
pause(1)

% QLab connection
qlabs = QuanserInteractiveLabs();
connection_established = qlabs.open('localhost');

if connection_established == false
    disp("Failed to open connection.")
    return
end

disp('Connected')
verbose = true;
num_destroyed = qlabs.destroy_all_spawned_actors();

% Flooring

x_offset = 0.13;
y_offset = 1.67;
hFloor = QLabsQCarFlooring(qlabs);
hFloor.spawn_degrees([x_offset, y_offset, 0.001],[0, 0, -90]);


%region: Walls
hWall = QLabsWalls(qlabs);
hWall.set_enable_dynamics(false);

for y = 0:4
    hWall.spawn_degrees([-2.4 + x_offset, (-y*1.0)+2.55 + y_offset, 0.001], [0, 0, 0]);
end

for x = 0:4
    hWall.spawn_degrees([-1.9+x + x_offset, 3.05+ y_offset, 0.001], [0, 0, 90]);
end

for y = 0:5
    hWall.spawn_degrees([2.4+ x_offset, (-y*1.0)+2.55 + y_offset, 0.001], [0, 0, 0]);
end

for x = 0:3
    hWall.spawn_degrees([-0.9+x+ x_offset, -3.05+ y_offset, 0.001], [0, 0, 90]);
end

hWall.spawn_degrees([-2.03 + x_offset, -2.275+ y_offset, 0.001], [0, 0, 48]);
hWall.spawn_degrees([-1.575+ x_offset, -2.7+ y_offset, 0.001], [0, 0, 48]);


%% Signage

% stop signs
%parking lot
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

%roundabout signs
myRoundaboutSign = QLabsRoundaboutSign(qlabs);
myRoundaboutSign.spawn_degrees([2.392, 2.522, 0.006], ...
                          [0, 0, -90], ...
                          [0.1, 0.1, 0.1], ...
                          false);

myRoundaboutSign.spawn_degrees([0.698, 2.483, 0.006], ...
                          [0, 0, -145], ...
                          [0.1, 0.1, 0.1], ...
                          false);

myRoundaboutSign.spawn_degrees([0.007, 3.973, 0.006], ...
                        [0, 0, 135], ...
                        [0.1, 0.1, 0.1], ...
                        false);


%yield sign
%one way exit yield
myYieldSign = QLabsYieldSign(qlabs);
myYieldSign.spawn_degrees([0.0, -1.3, 0.006], ...
                          [0, 0, -180], ...
                          [0.1, 0.1, 0.1], ...
                          false);

%roundabout yields
myYieldSign.spawn_degrees([2.4, 3.2, 0.006], ...
                        [0, 0, -90], ...
                        [0.1, 0.1, 0.1], ...
                        false);

myYieldSign.spawn_degrees([1.1, 2.8, 0.006], ...
                        [0, 0, -145], ...
                        [0.1, 0.1, 0.1], ...
                        false);

myYieldSign.spawn_degrees([0.49, 3.8, 0.006], ...
                        [0, 0, 135], ...
                        [0.1, 0.1, 0.1], ...
                        false);

% Spawning crosswalks
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

%Signage line guidance (white lines)
mySpline = QLabsBasicShape(qlabs);
mySpline.spawn_degrees ([2.21, 0.2, 0.006], ...
                        [0, 0, 0], ...
                        [0.27, 0.02, 0.001], ...
                        false);

mySpline.spawn_degrees ([1.951, 1.68, 0.006], ...
                        [0, 0, 0], ...
                        [0.27, 0.02, 0.001], ...
                        false);

mySpline.spawn_degrees ([-0.05, -1.02, 0.006], ...
                        [0, 0, 90], ...
                        [0.38, 0.02, 0.001], ...
                        false);

%% Persona Estática para la Competencia
% Creamos el objeto de la librería de personas
hPersonStatic = QLabsPerson(qlabs);

% Definimos los parámetros según tus coordenadas
loc_persona = [-0.424, 4.55, 0.005]; % Agregamos un pequeño offset en Z para que no atraviese el suelo
rot_persona = [0, 0, -90];            % 90 grados para que esté viendo hacia la calle (ajusta si es necesario)
scale_persona = [0.1, 0.1, 0.1];           % Tamaño normal
id_persona = 10;                     % Un número de ID único para este actor
config_persona = 11;                  % Puedes elegir de 0 a 11 para cambiar su apariencia

% Spawneamos a la persona
hStatus = hPersonStatic.spawn_id_degrees(id_persona, loc_persona, rot_persona, scale_persona, config_persona, true);

if hStatus == 0
    disp('Persona spawneada con éxito en la banqueta.');
else
    disp('Error al spawnear la persona. Revisa la conexión con QLabs.');
end

%% Persona Dinámica cruzando la calle
hPersonObstacle = QLabsPerson(qlabs);
% Punto A (Banqueta derecha), Punto B (Banqueta izquierda)
LOC_B_OBSTACULO = [1.441, 0.62, 0.005]; 
LOC_A_OBSTACULO = [1.441, 0.81, 0.005];


% Spawn inicial del obstáculo (ID 20 para no chocar con la otra)
hPersonObstacle.spawn_id_degrees(20, LOC_A_OBSTACULO, [0, 0, -180], [0.1, 0.1, 0.1], 11, true);

disp('Persona DINÁMICA lista para cruzar (ID 20).');

%% Obstáculo: Cono de Competencia (Versión Oficial)
% Usamos la clase específica de la documentación
hTrafficCone = QLabsTrafficCone(qlabs);

% Configuración según tus coordenadas
loc_cone = [2.221, 1.017, 0.25]; % Z en 0.25 como recomienda el ejemplo
rot_cone = [0, 0, 0];
scale_cone = [0.2, 0.2, 0.2]; % Mantengo tu escala pequeña
id_cone = 101;

% 1. SPAWN (Usando spawn_id_degrees para asegurar el ID)
hStatusCone = hTrafficCone.spawn_id_degrees(id_cone, loc_cone, rot_cone, scale_cone, 0, true);

if hStatusCone == 0
    disp('Cono de tráfico spawneado con éxito.');
    
    % 2. COLOR (Opcional, porque el slot 0 ya es naranja por defecto)
    % Si quieres asegurar un naranja específico: [R, G, B]
    color_naranja = [1, 0.2, 0]; 
    % Argumentos: slot, color, roughness, metallic, waitForConfirmation
    hTrafficCone.set_material_properties(0, color_naranja, 0.4, false, true);
    
    % El slot 1 suele ser la base o las cintas reflectantes (negro por defecto)
    hTrafficCone.set_material_properties(1, [0, 0, 0], 1.0, false, true);
else
    disp('Error al spawnear el cono de tráfico.');
end

%% Cameras
%spawn cameras 1. birds eye, 2. edge 1, possess the qcar

camera1Loc = [0.15, 1.7, 5];
camera1Rot = [0, 90, 0];
camera1 = QLabsFreeCamera(qlabs);
camera1.spawn_degrees(camera1Loc, camera1Rot);

camera1.possess();

camera2Loc = [-0.36+ x_offset, -3.691+ y_offset, 2.652];
camera2Rot = [0, 47, 90];
camera2=QLabsFreeCamera(qlabs);
camera2.spawn_degrees (camera2Loc, camera2Rot);

%% Spawn QCar 2 and start rt model

% Use user configured parameters

calibration_location_rotation = [0, 2.13, 0.005, 0, 0, -90];
taxi_hub_location_rotation = [-1.205, -0.83, 0.005, 0, 0, -44.7];

%QCar
myCar = QLabsQCar2(qlabs);

switch spawn_location
    case 1
        spawn = calibration_location_rotation;
    case 2
        spawn = taxi_hub_location_rotation;
end


myCar.spawn_id_degrees(0, spawn(1:3), spawn(4:6), [1/10, 1/10, 1/10], 1);

% Start RT models
file_workspace = fullfile(getenv('RTMODELS_DIR'), 'QCar2', 'QCar2_Workspace_studio.rt-win64');
pause(2)
system(['quarc_run -D -r -t tcpip://localhost:17000 ', file_workspace]);
pause(3)

% Run traffic controller
trafficLightController(qlabs)