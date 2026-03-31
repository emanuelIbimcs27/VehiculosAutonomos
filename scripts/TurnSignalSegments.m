%% =============================
% MAPEO NODOS → INDICES EN TRAYECTORIA
% =============================

num_nodes_path = length(pathNodes_corrected);
node_to_idx = zeros(num_nodes_path,1);

search_start = 1; %  clave: evita ambigüedades
AUX = 48;

for k = 1:num_nodes_path
    
    nodo_id = pathNodes_corrected(k);
    nodo_xy = nodes(nodo_id,:);
    
    min_dist = inf;
    best_idx = search_start;
    
    for i = search_start:length(path_x_smooth)
        
        dx = path_x_smooth(i) - nodo_xy(1);
        dy = path_y_smooth(i) - nodo_xy(2);
        d = dx^2 + dy^2; % sin sqrt (más rápido)
        
        if d < min_dist
            min_dist = d;
            best_idx = i;
        end
    end
    
    node_to_idx(k) = best_idx;
    search_start = best_idx; % solo busca hacia adelante
end

%% =============================
% DEFINIR TUS REGLAS
% =============================

%izq = [7 8; 8 9; 15 24; 17 6; 23 AUX; AUX 32; 27 7; 31 45; 44 16];
der = [9 41; 13 46; 15 45; 17 18; 23 16; 26 27; 27 28;
       31 25; 39 40; 40 41; 41 42; 44 32; 45 3];

izq = [7 8; 8 9; 15 AUX; AUX 24; 17 6; 23 AUX; AUX 32; 27 7; 31 AUX; AUX 45; 44 AUX; AUX 16];

%% =============================
% CREAR SEGMENTOS
% =============================

segmentos_izq = [];
segmentos_der = [];

for k = 1:length(pathNodes_corrected)-1
    
    n1 = pathNodes_corrected(k);
    n2 = pathNodes_corrected(k+1);
    
    idx1 = node_to_idx(k);
    idx2 = node_to_idx(k+1);
    
    segmento = [min(idx1,idx2), max(idx1,idx2)];
    
    % Verificar si este tramo está en tus reglas
    
    if any(all(izq == [n1 n2],2))
        segmentos_izq = [segmentos_izq; segmento];
    end
    
    if any(all(der == [n1 n2],2))
        segmentos_der = [segmentos_der; segmento];
    end
    
end

%% =============================
% (OPCIONAL) UNIR SEGMENTOS CONTIGUOS
% =============================

merge_segments = @(seg) ...
    cell2mat(arrayfun(@(i) ...
    [seg(i,1), seg(find(seg(:,1)==seg(i,2),1,'first'),2)], ...
    1:size(seg,1)-1, 'UniformOutput', false)');

%% =============================
% GUARDAR
% =============================

save('segmentos_direccionales.mat', 'segmentos_izq', 'segmentos_der');

%% =============================
%  VISUALIZACIÓN 
% =============================

figure; hold on; grid on; axis equal;

h_traj = plot(path_x_smooth, path_y_smooth, 'k');

% IZQUIERDA (verde)
h_izq = [];
for i = 1:size(segmentos_izq,1)
    idx = segmentos_izq(i,1):segmentos_izq(i,2);
    h_izq = plot(path_x_smooth(idx), path_y_smooth(idx), 'g', 'LineWidth', 3);
end

% DERECHA (rojo)
h_der = [];
for i = 1:size(segmentos_der,1)
    idx = segmentos_der(i,1):segmentos_der(i,2);
    h_der = plot(path_x_smooth(idx), path_y_smooth(idx), 'r', 'LineWidth', 3);
end

legend([h_traj, h_izq, h_der], {'Path', ' left turn signal', 'right turn signal'});