nodes = [
   -1.2050  -0.83    % nodo 1 #inicio (area taxi hub)
   -0.63    -1.076   % nodo 2
   0.533    -1.071   % nodo 3
   1.626    -1.045   % nodo 4
   2.225    -0.337   % nodo 5
   2.212    0.756    % nodo 6
   2.238    3.125    % nodo 7
   2.029    4.279    % nodo 8
   1.047    4.425    % nodo 9
   -1.274   4.397    % nodo 10
   -1.716   4.156    % nodo 11
   -1.963   3.630    % nodo 12
   -1.956   1.596    % nodo 13
   -1.541   0.927    % nodo 14
   -0.696   0.809    % nodo 15
   0.945    0.815    % nodo 16
   1.711    0.802    % nodo 17
   1.945    0.138    % nodo 18
   1.945    -0.376   % nodo 19
   1.704    -0.714   % nodo 20
   0.799    -0.811   % nodo 21
   0.357    -0.550   % nodo 22
   0.260    0.068    % nodo 23
   0.260    1.791    % nodo 24
   0.344    2.409    % nodo 25
   1.021    3.027    % nodo 26
   1.587    3.092    % nodo 27
   1.951    2.598    % nodo 28
   1.945    1.303    % nodo 29
   1.691    1.102    % nodo 30
   1.001    1.076    % nodo 31
   -0.696   1.063    % nodo 32
   -1.534   1.252    % nodo 33
   -1.690   1.843    % nodo 34
   -1.696   3.559    % nodo 35
   -1.521   3.974    % nodo 36
   -1.177   4.150    % nodo 37
   0.331    4.158    % nodo 38
   0.520    4.106    % nodo 39
   0.767    3.931    % nodo 40
   0.897    3.638    % nodo 41
   0.767    3.170    % nodo 42
   0.240    2.675    % nodo 43
   -0.007   1.759    % nodo 44
   0.006    0.068    % nodo 45
   -1.937   0.4      % nodo 46
   -1.696   -0.399   % nodo 47 #fin (un poco atras de area taxi hub)
   
];

%%
edges = [
   1 2;
   2 3;
   3 4;
   4 5;
   5 6;
   6 7;
   7 8;
   8 9;
   9 10;
   10 11;
   11 12;
   12 13;
   13 14;
   13 46;
   14 15;
   15 16;
   15 45;
   15 24;
   16 17;
   17 18;
   17 6;
   18 19;
   19 20;
   20 21;
   21 22;
   22 23;
   23 16;
   23 24;
   23 32;
   24 25;
   25 26;
   26 27;
   27 28;
   27 8;
   28 29;
   29 30;
   30 31;
   31 32;
   31 24;
   31 45;
   32 33;
   33 34;
   34 35;
   35 36;
   36 37;
   37 38;
   38 39;
   39 40;
   40 41;
   41 42;
   41 27;
   42 43;
   43 44;
   44 45;
   44 32;
   44 16;
   45 3;
   46 47;
   47 1;%-----------
 
];

%%
penalty = zeros(size(edges,1),1);

% Lista de penalizaciones (basada en el orden de las líneas del 1 al 59)
penalty(1) = 0;
penalty(2) = 0;
penalty(3) = 0;
penalty(4) = 0;
penalty(5) = 4;
penalty(6) = 1;
penalty(7) = 1;
penalty(8) = 0;
penalty(9) = 0;
penalty(10) = 0;
penalty(11) = 0;
penalty(12) = 0;
penalty(13) = 0;
penalty(14) = 0;
penalty(15) = 0;
penalty(16) = 7; % 3+2+2
penalty(17) = 7; % 3+2+2
penalty(18) = 7; % 3+2+2
penalty(19) = 2;
penalty(20) = 0;
penalty(21) = 0;
penalty(22) = 0;
penalty(23) = 0;
penalty(24) = 0;
penalty(25) = 0;
penalty(26) = 0;
penalty(27) = 7; % 3+2+2
penalty(28) = 7; % 3+2+2
penalty(29) = 7; % 3+2+2
penalty(30) = 0;
penalty(31) = 0;
penalty(32) = 2; % 1+1
penalty(33) = 0;
penalty(34) = 0;
penalty(35) = 2;
penalty(36) = 0;
penalty(37) = 0;
penalty(38) = 7; % 3+2+2
penalty(39) = 7; % 3+2+2
penalty(40) = 7; % 3+2+2
penalty(41) = 0;
penalty(42) = 0;
penalty(43) = 4;
penalty(44) = 0;
penalty(45) = 0;
penalty(46) = 2; % 1+1
penalty(47) = 2; % 1+1
penalty(48) = 0;
penalty(49) = 0;
penalty(50) = 0;
penalty(51) = 0;
penalty(52) = 0;
penalty(53) = 0;
penalty(54) = 7; % 3+2+2
penalty(55) = 7; % 3+2+2
penalty(56) = 7; % 3+2+2
penalty(57) = 0;
penalty(58) = 2;
penalty(59) = 0; % --------

%%

numEdges = size(edges,1);
weights = zeros(numEdges,1);

for k = 1:numEdges
    i = edges(k,1);
    j = edges(k,2);

    dx = nodes(j,1) - nodes(i,1);
    dy = nodes(j,2) - nodes(i,2);

    dist = sqrt(dx^2 + dy^2);

    weights(k) = dist + penalty(k); 
end

%%
G = digraph(edges(:,1), edges(:,2), weights);

startNode = 1;
goalNode = 44; %44

[pathNodes, totalCost] = shortestpath(G, startNode, goalNode);

%%
% path_x_graph = nodes(pathNodes,1);
% path_y_graph = nodes(pathNodes,2);
% 1. Definir el centro de la intersección (Tu nodo auxiliar)
centro_interseccion = [0.144, 0.939]; 

% 2. Identificar los pares críticos que deben pasar por el centro
casos_criticos = [23, 32; 
                  15, 24; 
                  44, 16; 
                  31, 45];

% 3. Crear un nuevo pathNodes que incluya el centro si detecta el cruce
pathNodes_corrected = [];

for k = 1:length(pathNodes)-1
    nodo_actual = pathNodes(k);
    nodo_siguiente = pathNodes(k+1);
    
    % Añadimos el nodo actual a la nueva ruta
    pathNodes_corrected = [pathNodes_corrected, nodo_actual];
    
    % Verificamos si este segmento es uno de los 4 casos críticos
    es_critico = any(all(casos_criticos == [nodo_actual, nodo_siguiente], 2));
    
    if es_critico
        % INSERTAMOS UN NODO VIRTUAL (El centro) entre los dos nodos
        % Para que pchip tenga un punto de apoyo en la curva
        % Lo añadimos temporalmente a nuestra lista de coordenadas
        nodes(end+1, :) = centro_interseccion; 
        pathNodes_corrected = [pathNodes_corrected, size(nodes,1)];
    end
end
pathNodes_corrected = [pathNodes_corrected, pathNodes(end)]; % Añadir el último

% 4. Generar la nueva trayectoria suavizada con los puntos extra
path_x_final = nodes(pathNodes_corrected, 1);
path_y_final = nodes(pathNodes_corrected, 2);

t_new = 1:length(path_x_final);
tq_new = linspace(1, length(path_x_final), 1761);

path_x_smooth = interp1(t_new, path_x_final, tq_new, 'pchip');
path_y_smooth = interp1(t_new, path_y_final, tq_new, 'pchip');

%%
load distance_new_qcar2.mat;
load angles_new_qcar2.mat;

range_qcar2 = distance_new_qcar2(:,end);
angles_qcar2 = angles_new_qcar2(:,end);

qcar2_lidar_to_map_rotation = -1.5 * pi/180;
cal_pos = [0, 2, 0];

%%
figure(1)
hold on;

polar(-angles_qcar2-qcar2_lidar_to_map_rotation, range_qcar2,'k.');

plot(path_x_smooth - cal_pos(1), ...
     path_y_smooth - cal_pos(2), ...
     'r', 'LineWidth', 2);


% --- Marcar Start y Goal ---
plot(nodes(startNode,1) - cal_pos(1), ...
     nodes(startNode,2) - cal_pos(2), ...
     'go', 'MarkerSize', 8, 'MarkerFaceColor', 'g');

plot(nodes(goalNode,1) - cal_pos(1), ...
     nodes(goalNode,2) - cal_pos(2), ...
     'mo', 'MarkerSize', 8, 'MarkerFaceColor', 'm');

% --- Leyenda ---
legend({'Track edge', 'Final Path', 'Start Node (taxi hub)', 'Goal Node'}, ...
       'Location', 'best');

axis equal
grid on

hold off;

%%
path_x_dijkstra  = path_x_smooth(:);
path_y_dijkstra  = path_y_smooth(:);