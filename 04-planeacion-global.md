---
layout: default
title: Planeación Global de Trayectoria
nav_order: 2
parent: CPS IoT Competition 2026
permalink: /CPS/planeacion-global/
---

# Planeación Global de Trayectoria

## 2. Planeación global de trayectoria mediante grafos dirigidos, coordenadas del mapa de QLabs y penalizaciones viales

La trayectoria de referencia del vehículo no fue dibujada manualmente. Se construyó a partir de una representación topológica del circuito de competencia, obtenida directamente sobre el mapa de QLabs. Para ello, se seleccionaron puntos estratégicos sobre la red vial del entorno virtual y a cada uno se le asignó una coordenada cartesiana $(x,y)$. Estos puntos se convirtieron en nodos de un grafo dirigido, mientras que las conexiones físicamente transitables entre ellos se modelaron como aristas.

Desde el punto de vista de ingeniería de navegación, esta metodología permite convertir un problema continuo de movilidad en un problema discreto de optimización sobre red. En lugar de preguntarse continuamente “por dónde debo moverme en el plano”, el vehículo resuelve primero “por qué secuencia de nodos debo pasar para llegar al destino con el menor costo posible”. Después, esa secuencia discreta se suaviza para generar una trayectoria continua físicamente seguible por el controlador.

### 2.1 Modelado del conjunto de nodos

Si se denota por

$$
V = \{v_1, v_2, \dots, v_N\}
$$

al conjunto de nodos, entonces cada nodo se define como:

$$
v_i = (x_i, y_i)
$$

En este proyecto se utilizaron 47 nodos, es decir:

$$
N = 47
$$

La matriz de nodos fue:

```matlab
nodes = [
   -1.2050  -0.83
   -0.63    -1.076
   0.533    -1.071
   1.626    -1.045
   2.225    -0.337
   2.212    0.756
   2.238    3.125
   2.029    4.279
   1.047    4.425
   -1.274   4.397
   -1.716   4.156
   -1.963   3.630
   -1.956   1.596
   -1.541   0.927
   -0.696   0.809
   0.945    0.815
   1.711    0.802
   1.945    0.138
   1.945    -0.376
   1.704    -0.714
   0.799    -0.811
   0.357    -0.550
   0.260    0.068
   0.260    1.791
   0.344    2.409
   1.021    3.027
   1.587    3.092
   1.951    2.598
   1.945    1.303
   1.691    1.102
   1.001    1.076
   -0.696   1.063
   -1.534   1.252
   -1.690   1.843
   -1.696   3.559
   -1.521   3.974
   -1.177   4.150
   0.331    4.158
   0.520    4.106
   0.767    3.931
   0.897    3.638
   0.767    3.170
   0.240    2.675
   -0.007   1.759
   0.006    0.068
   -1.937   0.4
   -1.696   -0.399
];
```

Estos nodos fueron extraídos del mapa de QLabs y colocados en posiciones clave del circuito: cambios de curvatura, entradas y salidas de intersecciones, conexiones entre lazo externo e interno, así como zonas relevantes para maniobras de giro y transición entre carriles.

Cada nodo representa una posición geométrica relevante dentro de la red vial. Por ejemplo, si un nodo aparece en la entrada de una intersección, su función no es solo “marcar un punto”, sino dividir el mapa en tramos navegables con sentido lógico para el vehículo. Esto permite que la planeación no dependa únicamente de la forma visual del circuito, sino de su estructura funcional.

### 2.2 Modelado del conjunto de aristas

Una arista dirigida

$$
e_{ij} = (v_i, v_j)
$$

indica que el vehículo puede desplazarse desde el nodo $i$ hacia el nodo $j$. El grafo completo queda definido como:

$$
G = (V, E, W)
$$

donde $E$ es el conjunto de aristas y $W$ el conjunto de pesos asociados.

```matlab
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
   47 1;
];
```

El uso de un grafo dirigido es esencial, ya que no todas las conexiones del circuito son equivalentes ni simétricas. Esto obliga al planificador a respetar la lógica de circulación del entorno y evita rutas físicamente inviables o contrarias al sentido esperado de desplazamiento.

### 2.3 Distancia geométrica entre nodos

Para cada arista $(i,j)$, se calcula primero la distancia euclidiana entre el nodo de origen y el nodo destino:

$$
d_{ij} = \sqrt{(x_j - x_i)^2 + (y_j - y_i)^2}
$$

En código:

```matlab
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
```

Esta distancia representa el costo puramente geométrico de transitar entre dos nodos consecutivos. Si la planeación dependiera solo de este término, el vehículo elegiría siempre la ruta de menor longitud total. Sin embargo, en un entorno vial eso no siempre conduce a la mejor trayectoria desde el punto de vista operacional.

### 2.4 Penalización por complejidad vial

Una de las decisiones más importantes del proyecto fue no seleccionar la trayectoria únicamente por longitud geométrica. En un sistema de conducción autónoma, la ruta más corta no siempre es la más conveniente, ya que ciertos tramos del mapa implican mayor complejidad operativa debido a la presencia de elementos viales como semáforos, señales de alto, cruces peatonales, glorietas o señales de ceda el paso. Por esta razón, a cada arista del grafo se le asignó una penalización adicional según los elementos presentes en ese tramo.

La tabla de penalizaciones utilizada fue la siguiente:

| Elemento vial | Penalización |
|---|---:|
| Traffic light | 3 |
| Stop signal | 4 |
| Crosswalk | 2 |
| Round signal | 1 |
| Yield signal | 1 |

De este modo, si una arista conecta dos nodos y en ese trayecto existe más de un elemento vial, la penalización total de dicha arista se obtiene sumando las contribuciones individuales de todos los elementos presentes. Matemáticamente, la penalización asociada a la arista que conecta el nodo $i$ con el nodo $j$ se define como:

$$
p_{ij} = 3\,n_{tl,ij} + 4\,n_{stop,ij} + 2\,n_{cw,ij} + 1\,n_{round,ij} + 1\,n_{yield,ij}
$$

donde:

- $n_{tl,ij}$: número de semáforos en el tramo
- $n_{stop,ij}$: número de señales STOP
- $n_{cw,ij}$: número de cruces peatonales
- $n_{round,ij}$: número de elementos relacionados con rotonda
- $n_{yield,ij}$: número de señales de ceda el paso

Por tanto, el peso total de cada arista no depende únicamente de su longitud geométrica, sino de la suma entre su distancia y su penalización vial:

$$
w_{ij} = d_{ij} + p_{ij}
$$

donde $d_{ij}$ es la distancia euclidiana entre los nodos $i$ y $j$, calculada como:

$$
d_{ij} = \sqrt{(x_j - x_i)^2 + (y_j - y_i)^2}
$$

Esta formulación permite que el algoritmo de planeación prefiera trayectorias no solo más cortas, sino también más convenientes desde el punto de vista operativo.

#### Ejemplo de aplicación de la penalización

Si entre dos nodos del mapa, por ejemplo entre el nodo $n$ y el nodo $m$, existe un **crosswalk** y una **stop signal**, entonces la penalización total de ese tramo se calcula como:

$$
p_{nm} = 2 + 4 = 6
$$

y por tanto el peso final de la arista queda:

$$
w_{nm} = d_{nm} + 6
$$

De manera análoga, si un tramo contiene un semáforo y una señal de yield, la penalización sería:

$$
p_{ij} = 3 + 1 = 4
$$

Este criterio convierte el problema de planeación en una optimización sobre un mapa ponderado, donde el vehículo busca la ruta de menor costo total y no simplemente la de menor distancia.

### 2.5 Vector de penalizaciones utilizado

```matlab
penalty = zeros(size(edges,1),1);

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
penalty(16) = 7;
penalty(17) = 7;
penalty(18) = 7;
penalty(19) = 2;
penalty(20) = 0;
penalty(21) = 0;
penalty(22) = 0;
penalty(23) = 0;
penalty(24) = 0;
penalty(25) = 0;
penalty(26) = 0;
penalty(27) = 7;
penalty(28) = 7;
penalty(29) = 7;
penalty(30) = 0;
penalty(31) = 0;
penalty(32) = 2;
penalty(33) = 0;
penalty(34) = 0;
penalty(35) = 2;
penalty(36) = 0;
penalty(37) = 0;
penalty(38) = 7;
penalty(39) = 7;
penalty(40) = 7;
penalty(41) = 0;
penalty(42) = 0;
penalty(43) = 4;
penalty(44) = 0;
penalty(45) = 0;
penalty(46) = 2;
penalty(47) = 2;
penalty(48) = 0;
penalty(49) = 0;
penalty(50) = 0;
penalty(51) = 0;
penalty(52) = 0;
penalty(53) = 0;
penalty(54) = 7;
penalty(55) = 7;
penalty(56) = 7;
penalty(57) = 0;
penalty(58) = 2;
penalty(59) = 0;
```

Este vector representa la traducción práctica de la evaluación vial realizada sobre los distintos segmentos del mapa. En términos ingenieriles, lo que se hizo fue asignar a cada arista del grafo un costo adicional derivado del contexto vial que le corresponde. Esto significa que el mapa no se trató como una simple colección de distancias geométricas, sino como una red de caminos con distinto nivel de complejidad operativa.

### 2.6 Obtención de la ruta óptima

La ruta óptima se obtiene resolviendo el problema:

$$
P^\star = \arg\min_{P \in \mathcal{P}(s,g)} \sum_{(i,j)\in P} w_{ij}
$$

donde $s$ es el nodo inicial y $g$ el nodo objetivo.

```matlab
G = digraph(edges(:,1), edges(:,2), weights);

startNode = 1;
goalNode = 44;

[pathNodes, totalCost] = shortestpath(G, startNode, goalNode);
```

Aquí el vehículo parte del nodo 1 y se dirige al nodo 44. La variable `pathNodes` contiene la secuencia discreta de nodos que minimiza el costo total. La variable `totalCost` representa el valor acumulado de esa función objetivo.

### 2.7 Corrección geométrica de cruces críticos

Aunque la ruta discreta resultante es óptima en términos del grafo, algunas transiciones en intersecciones pueden ser geométricamente pobres. Para resolver esto se definió un nodo auxiliar central:

```matlab
centro_interseccion = [0.144, 0.939]; 

casos_criticos = [23, 32; 
                  15, 24; 
                  44, 16; 
                  31, 45];
```

y se inserta cuando aparece una conexión crítica:

```matlab
pathNodes_corrected = [];

for k = 1:length(pathNodes)-1
    nodo_actual = pathNodes(k);
    nodo_siguiente = pathNodes(k+1);

    pathNodes_corrected = [pathNodes_corrected, nodo_actual];

    es_critico = any(all(casos_criticos == [nodo_actual, nodo_siguiente], 2));

    if es_critico
        nodes(end+1, :) = centro_interseccion; 
        pathNodes_corrected = [pathNodes_corrected, size(nodes,1)];
    end
end
pathNodes_corrected = [pathNodes_corrected, pathNodes(end)];
```

Esta corrección no cambia la lógica global del camino mínimo, pero sí mejora su forma geométrica local. El nodo auxiliar funciona como punto de apoyo adicional en zonas donde un giro directo entre nodos extremos produciría una curva poco natural para el vehículo.

### 2.8 Suavizado de trayectoria mediante PCHIP

Una vez corregida la secuencia discreta, se genera una trayectoria continua:

```matlab
path_x_final = nodes(pathNodes_corrected, 1);
path_y_final = nodes(pathNodes_corrected, 2);

t_new = 1:length(path_x_final);
tq_new = linspace(1, length(path_x_final), 1761);

path_x_smooth = interp1(t_new, path_x_final, tq_new, 'pchip');
path_y_smooth = interp1(t_new, path_y_final, tq_new, 'pchip');
```

Matemáticamente:

$$
x_s(\tau) = \operatorname{PCHIP}(t_k, x_k), \qquad
y_s(\tau) = \operatorname{PCHIP}(t_k, y_k)
$$

donde $(x_k, y_k)$ son los puntos discretos corregidos y $\tau$ es el parámetro continuo de interpolación.

El uso de PCHIP es especialmente adecuado porque preserva mejor la forma local de la trayectoria y evita oscilaciones artificiales. Esto es importante para el vehículo autónomo, ya que una referencia demasiado ondulada o con cambios bruscos de curvatura puede dificultar el seguimiento estable por parte del controlador.

### 2.9 Visualización final de la trayectoria

```matlab
load distance_new_qcar2.mat;
load angles_new_qcar2.mat;

range_qcar2 = distance_new_qcar2(:,end);
angles_qcar2 = angles_new_qcar2(:,end);

qcar2_lidar_to_map_rotation = -1.5 * pi/180;
cal_pos = [0, 2, 0];

figure(1)
hold on;

polar(-angles_qcar2-qcar2_lidar_to_map_rotation, range_qcar2,'k.');

plot(path_x_smooth - cal_pos(1), ...
     path_y_smooth - cal_pos(2), ...
     'r', 'LineWidth', 2);

axis equal
grid on
hold off;

path_x_dijkstra  = path_x_smooth(:);
path_y_dijkstra  = path_y_smooth(:);
```

### Figura del mapa base con nodos del grafo

![Mapa base con nodos y conectividad del grafo](/assets/img/Grfos.jpeg)

**Descripción técnica de la figura.**  
La figura muestra el mapa de competencia utilizado para construir el grafo del sistema de planeación. Sobre el circuito se colocaron nodos numerados en posiciones clave del entorno: cambios de curvatura, entradas y salidas de intersecciones, conexiones entre lazo externo e interno y zonas cercanas a eventos viales. A partir de estas coordenadas se construyó la estructura topológica del problema.

### Figura de trayectoria global generada

![Trayectoria global generada para el QCar 2 virtual](/assets/img/MapaVirtualGenerado.jpeg)

**Descripción técnica de la figura.**  
La línea roja representa la trayectoria global final que seguiría el QCar 2 virtual dentro del entorno de simulación. Esta trayectoria se obtuvo al resolver un problema de optimización sobre el grafo dirigido del mapa y, posteriormente, suavizar la ruta discreta mediante interpolación PCHIP, con el fin de generar una referencia continua y físicamente más adecuada para el seguimiento del vehículo. Por su parte, la línea punteada negra corresponde al marco espacial del entorno utilizado como base de calibración. Es importante señalar que esta trayectoria se presenta únicamente como un ejemplo de planeación entre el nodo 1 y el nodo 44.

## Interpretación de esta sección dentro del sistema completo

La planeación global constituye la columna vertebral del comportamiento nominal del vehículo. Todos los demás módulos del sistema —detección de objetos, lógica de señales, profundidad, direccionales y evasión— se montan sobre esta referencia de trayectoria. Si la planeación no fuera consistente, estable o geométricamente razonable, el resto del pipeline trabajaría sobre una base defectuosa.

Por ello, esta sección no solo define una ruta, sino que construye un espacio estructurado de navegación donde cada segmento tiene sentido geométrico y también operacional. La combinación de coordenadas extraídas del mapa, aristas dirigidas, penalizaciones viales, corrección geométrica e interpolación final permite obtener una trayectoria que no solo conecta un origen y un destino, sino que también es apropiada para ser seguida por el vehículo en un entorno urbano simulado.