---
layout: default
title: CPS IoT Competition 2026
nav_order: 4
---

# Metodología de Diseño y Validación del Algoritmo de Self-Driving para la CPS IoT Competition 2026

## Introducción

El desarrollo presentado en esta sección corresponde al diseño, integración y validación de un algoritmo de conducción autónoma implementado para el entorno virtual de **Quanser City** utilizando el **QCar 2 virtual** dentro de **QLabs**, con una arquitectura principal desarrollada en **MATLAB/Simulink**. La solución fue concebida para la **CPS IoT Self-Driving Competition 2026**, tomando como base el entorno de competencia y extendiéndolo con módulos propios de planeación, percepción visual, estimación de profundidad, lógica reglamentaria y evasión de obstáculos.

Desde una perspectiva de ingeniería de sistemas autónomos, el vehículo no fue tratado como un simple bloque de seguimiento de trayectoria, sino como una arquitectura jerárquica compuesta por varias capas funcionales. En primer lugar, fue necesario definir la parametrización del vehículo virtual y las condiciones temporales de operación de cada subsistema. Posteriormente, se diseñó una estrategia de planeación global de trayectoria basada en grafos dirigidos y penalizaciones viales. Sobre esta base se incorporó un sistema de percepción visual basado en una red neuronal entrenada específicamente para detectar objetos presentes en el entorno de Quanser City. Finalmente, se añadieron módulos de interpretación espacial y toma de decisiones para que el vehículo pudiera reaccionar frente a señales y obstáculos.

Una de las contribuciones más importantes del proyecto fue el diseño de un pipeline híbrido entre Simulink y Python. Simulink se utilizó como núcleo de integración y control, mientras que Python funcionó como servicio externo de inferencia para la red neuronal exportada a ONNX. Gracias a esta estrategia, el sistema pudo recibir imágenes desde el entorno virtual, detectar objetos de interés, estimar sus distancias y modificar en tiempo real la velocidad y la dirección del vehículo.

---

## Arquitectura general de la solución

La solución implementada se estructuró en varios niveles funcionales que trabajan de manera coordinada. En el primer nivel se ubica la **parametrización del vehículo**, donde se definen tiempos de muestreo, ganancias de control, configuraciones del entorno y parámetros geométricos. En el segundo nivel se encuentra la **planeación global**, encargada de calcular una trayectoria óptima entre un nodo inicial y un nodo objetivo sobre el mapa de competencia. En el tercer nivel se ubica la **percepción visual**, implementada con una red neuronal YOLOv8 entrenada para reconocer objetos del escenario. En el cuarto nivel se incluye la **estimación de profundidad**, cuyo objetivo es transformar cada detección bidimensional en una detección con significado espacial. Finalmente, en el quinto nivel se encuentra la **toma de decisiones**, donde se implementan reglas de comportamiento frente a señales y obstáculos.

Esta arquitectura puede representarse conceptualmente como una tubería de procesamiento:

$$
\text{Mapa} \rightarrow \text{Planeación} \rightarrow \text{Percepción} \rightarrow \text{Profundidad} \rightarrow \text{Decisión} \rightarrow \text{Control}
$$

Desde el punto de vista de navegación autónoma, esta descomposición es importante porque separa claramente tres preguntas fundamentales del problema. La planeación responde **por dónde debe ir el vehículo**. La percepción responde **qué hay en el entorno**. La lógica de decisión responde **qué debe hacer el vehículo ante lo que percibe**. Esta estructura modular facilita la validación individual de cada componente y fortalece la robustez global del sistema.

---

## 1. Parametrización del QCar 2 virtual y definición del entorno

La primera etapa del desarrollo consistió en configurar el vehículo virtual y todos los parámetros base del stack. Para ello se utilizó un script de inicialización en MATLAB donde se establece el tipo de mapa, el tipo de QCar, los tiempos de muestreo de cada subsistema, las ganancias del controlador de dirección, los parámetros de estimación y los archivos de calibración.

### 1.1 Definición del tipo de mapa y tipo de vehículo

```matlab
clear all;

%% User configurable parameters
map_type = 1;
qcar_types = 1;
```

En este bloque se definen dos parámetros fundamentales. El primero, `map_type = 1`, indica que se está trabajando sobre el mapa grande del entorno SDCS. El segundo, `qcar_types = 1`, selecciona la configuración correspondiente al **QCar virtual**. Este detalle es importante porque el mismo archivo contempla una diferenciación entre plataforma virtual y plataforma física, lo cual deja preparada la arquitectura para una posible migración futura a hardware real.

### 1.2 Definición de tiempos de muestreo

```matlab
%% Setting Qcar Variables
Controller_Sample_Time = 1/500;
CSI_Sample_Time = Controller_Sample_Time * ceil(0.033 / Controller_Sample_Time);
RealSense_Sample_Time = Controller_Sample_Time * ceil(0.033 / Controller_Sample_Time);
ImageDisplay_Sample_Time = Controller_Sample_Time * 50;
LiDAR_Sample_Time = Controller_Sample_Time * ceil(1/15 / Controller_Sample_Time);
Audio_Sample_Time = Controller_Sample_Time * 100;
Initialization_Time = 23;
cameraStepSize = 3e-2;

NN_Sample_Time = RealSense_Sample_Time*1;
```

Este bloque fija la base temporal del sistema. El controlador principal opera con un tiempo de muestreo de

$$
T_c = \frac{1}{500}\ \text{s}
$$

lo que equivale a una frecuencia de 500 Hz. A partir de ese periodo base se derivan los tiempos de muestreo de los demás subsistemas, como cámaras, LiDAR, visualización y red neuronal. Esta estrategia de sincronización evita inconsistencias temporales entre sensores, controladores y módulos de procesamiento.

En términos de diseño discreto, cada subsistema queda alineado con una malla temporal común. Si el módulo de control opera más rápido que el módulo de visión, el sistema sigue siendo consistente porque ambos comparten una referencia temporal bien definida.

### 1.3 Selección del punto de calibración

```matlab
if map_type == 1
    cal_pos = [0, 2, 0]
    disp('Large SDCS Map Being Used ...')
else
    cal_pos = [0, 0, 0]
    disp('Small map Being Used ...')
end
```

La variable `cal_pos` define la posición de calibración usada como referencia del entorno. En este caso, al trabajar sobre el mapa grande, se selecciona el vector:

$$
\mathbf{p}_{cal} = [0,\ 2,\ 0]
$$

Este desplazamiento aparece después en la visualización de la trayectoria, ya que la ruta calculada se ajusta respecto al marco de referencia del mapa y del sistema de calibración.

### 1.4 Ganancias del controlador de dirección

```matlab
if qcar_types == 1 % IF VIRTUAL
    steering_Kp = 1.2;
    steering_Kd = 0.6;
elseif qcar_types == 2 % IF PHYSICAL
    steering_Kp = 1;
    steering_Kd = 0.1;
end
```

En este bloque se definen las ganancias del controlador PD de dirección. Para el caso virtual se eligieron:

$$
K_p = 1.2,\qquad K_d = 0.6
$$

Por tanto, el control de dirección puede interpretarse de forma general como:

$$
u_{\delta}(t) = K_p\,e(t) + K_d\,\dot{e}(t)
$$

donde \(e(t)\) representa el error de trayectoria o error de orientación respecto a la referencia. La acción proporcional corrige el error principal, mientras que la derivativa amortigua cambios rápidos y reduce oscilaciones.

### 1.5 Parámetros de filtrado y estimación

```matlab
%% QCar KF + EKF
GyroKF_sampleTime = 0.001;

if qcar_types == 1 % IF VIRTUAL
    GyroKF_X0 = [0;0];
    GyroKF_P0 = eye(2);
    
    GyroKF_Q = diag([0.001, 0.001]); 
    GyroKF_R = 0.05;
    
    QCarEKF_sampleTime = GyroKF_sampleTime;
    
    QCarEKF_L = 0.256;
    
    QcarKF_X0 = [0; 0; 0];
    QCarEKF_P0 = eye(3);
    
    QCarEKF_Q = diag([0.001, 0.001, 0.001]);
    
    QCarEKF_R_heading = diag(0.1);
    QCarEKF_R_combined = diag([0.005, 0.005, 0.001]);
end
```

Este fragmento define parámetros de filtros de Kalman y de un filtro de Kalman extendido para el vehículo. Aunque el núcleo del proyecto se centra en planeación, visión y toma de decisiones, la inclusión de estos parámetros fortalece la base de estimación del stack y demuestra que el vehículo se encuentra montado sobre una arquitectura más amplia de modelado y fusión de información.

En particular, la longitud efectiva del vehículo se definió como:

$$
L = 0.256\ \text{m}
$$

lo cual es importante para modelos cinemáticos tipo bicicleta y para la propagación del estado en el EKF.

### 1.6 Carga de archivos de calibración y referencia angular

```matlab
if qcar_types == 1 % FOR VIRTUAL
    qcar2_virtual_to_physical_lidar_rotation = -7*pi/180;
    qcar2_lidar_to_map_rotation = -1.5 * pi/180;
    qcar2_lidar_to_body_rotation = 0;
end

load distance_new_qcar2.mat;
load angles_new_qcar2.mat;
range_qcar2 = distance_new_qcar2(2: length(distance_new_qcar2), width(distance_new_qcar2)-5);
angles_qcar2 = angles_new_qcar2(2: length(angles_new_qcar2), width(angles_new_qcar2)-5);
```

Aquí se corrige la orientación del LiDAR con respecto al mapa. Por ejemplo, la rotación del LiDAR al mapa en el caso virtual se fijó como:

$$
\theta_{L\to M} = -1.5^\circ
$$

Esta corrección angular es indispensable para alinear adecuadamente las referencias espaciales del entorno con la trayectoria calculada y con las visualizaciones posteriores.

---

## 2. Planeación global de trayectoria mediante grafos dirigidos, coordenadas del mapa de QLabs y penalizaciones viales

La trayectoria de referencia del vehículo no fue dibujada manualmente. Se construyó a partir de una representación topológica del circuito de competencia, obtenida directamente sobre el mapa de QLabs. Para ello, se seleccionaron puntos estratégicos sobre la red vial del entorno virtual y a cada uno se le asignó una coordenada cartesiana \((x,y)\). Estos puntos se convirtieron en nodos de un grafo dirigido, mientras que las conexiones físicamente transitables entre ellos se modelaron como aristas.

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

### 2.2 Modelado del conjunto de aristas

Una arista dirigida

$$
e_{ij} = (v_i, v_j)
$$

indica que el vehículo puede desplazarse desde el nodo \(i\) hacia el nodo \(j\). El grafo completo queda definido como:

$$
G = (V, E, W)
$$

donde \(E\) es el conjunto de aristas y \(W\) el conjunto de pesos asociados.

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

El uso de un grafo dirigido es esencial, ya que no todas las conexiones del circuito son equivalentes ni simétricas. Esto fuerza al planificador a respetar la lógica de circulación del entorno.

### 2.3 Distancia geométrica entre nodos

Para cada arista \((i,j)\), se calcula primero la distancia euclidiana entre el nodo de origen y el nodo destino:

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

### 2.4 Penalización por complejidad vial

Una de las decisiones más importantes del proyecto fue no seleccionar la trayectoria únicamente por longitud geométrica. En un vehículo autónomo, la ruta más corta no siempre es la más conveniente. Existen segmentos que implican mayor complejidad operativa por su cercanía con señales o infraestructura vial.

Se definió la siguiente tabla de penalizaciones:

| Elemento vial | Penalización |
|---|---:|
| Semáforo | 3 |
| Stop | 4 |
| Cruce de cebra | 2 |
| Rotonda | 1 |
| Yield | 1 |

Si una arista contiene uno o varios de estos elementos, su penalización total se calcula como:

$$
p_{ij} = 3\,n_{sem,ij} + 4\,n_{stop,ij} + 2\,n_{cebra,ij} + 9\,n_{rot,ij} + 9\,n_{yield,ij}
$$

donde:

- $n_{tl,ij}$: número de semáforos en el tramo
- $n_{stop,ij}$: número de señales STOP
- $n_{cw,ij}$: número de cruces peatonales
- $n_{round,ij}$: número de elementos relacionados con rotonda
- $n_{yield,ij}$: número de señales de ceda el paso
El peso total de cada arista queda entonces:

$$
w_{ij} = d_{ij} + p_{ij}
$$

Esto hace que el planificador minimice una combinación de distancia física y complejidad vial.

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

Este vector representa la traducción práctica de la evaluación vial realizada sobre los distintos segmentos del mapa.

### 2.6 Obtención de la ruta óptima

La ruta óptima se obtiene resolviendo el problema:

$$
P^\star = \arg\min_{P \in \mathcal{P}(s,g)} \sum_{(i,j)\in P} w_{ij}
$$

donde \(s\) es el nodo inicial y \(g\) el nodo objetivo.

```matlab
G = digraph(edges(:,1), edges(:,2), weights);

startNode = 1;
goalNode = 44;

[pathNodes, totalCost] = shortestpath(G, startNode, goalNode);
```

Aquí el vehículo parte del nodo 1 y se dirige al nodo 44.

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

donde $(x_k, y_k)$ son los puntos discretos corregidos y tau es el parámetro continuo de interpolación.

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
La línea roja representa la trayectoria global final que seguirá el QCar 2 virtual. Dicha trayectoria se obtuvo resolviendo un problema de optimización sobre el grafo dirigido del mapa y posteriormente suavizando la ruta discreta mediante interpolación PCHIP. La referencia punteada negra corresponde al marco espacial del entorno utilizado como base de calibración.

---

## 3. Entrenamiento y validación del modelo de detección de objetos para Quanser City

El sistema de percepción visual se construyó a partir de un modelo YOLOv8 entrenado específicamente para detectar objetos del escenario de Quanser City. El entrenamiento se realizó en Google Colab con soporte de GPU, y posteriormente el modelo fue exportado a ONNX para ser integrado al pipeline de Simulink mediante Python.

### 3.1 Verificación del entorno de cómputo

```python
import torch
print(torch.cuda.is_available())  # Debe imprimir True
print(torch.cuda.device_count())  # Debe imprimir 1 o más
```

Este bloque verifica la disponibilidad de GPU, condición importante para acelerar el entrenamiento del modelo.

### 3.2 Instalación de Ultralytics y verificación del entorno

```python
!pip install ultralytics

import ultralytics
ultralytics.checks()
```

### 3.3 Carga y preparación del dataset

```python
from google.colab import files
uploaded = files.upload()

!unzip detection_2025.v8i.yolov8.zip

!ls
!ls valid
!ls test
!ls train
```

### 3.4 Entrenamiento del modelo

```python
from ultralytics import YOLO

model = YOLO("yolov8s.pt")

model.train(
    data="data.yaml",
    epochs=150,
    imgsz=640,
    batch=32
)
```

### 3.5 Exportación a ONNX

```python
model.export(format="onnx", opset=12)
```

### 3.6 Validación cuantitativa del modelo

```python
model = YOLO("runs/detect/train/weights/best.pt")
metrics = model.val(data="data.yaml")
print("mAP@50:", metrics.box.map50)
print("mAP@50-95:", metrics.box.map)
print("Precision:", metrics.box.mp)
print("Recall:", metrics.box.mr)
```

Si se denotan estas métricas de forma general:

- \( \mathrm{mAP}_{50} \): precisión media con IoU = 0.50
- \( \mathrm{mAP}_{50:95} \): precisión media sobre múltiples umbrales IoU
- \(P\): precisión
- \(R\): recall

entonces el módulo de percepción puede evaluarse cuantitativamente mediante:

$$
P = \frac{TP}{TP + FP}, \qquad
R = \frac{TP}{TP + FN}
$$

donde \(TP\) son verdaderos positivos, \(FP\) falsos positivos y \(FN\) falsos negativos.

### 3.7 Prueba cualitativa del modelo exportado

```python
from ultralytics import YOLO
from IPython.display import display
from PIL import Image

model = YOLO("/content/best.onnx")

image_path = "/content/test/images/front_1743683028_9531693_jpg.rf.56133166b031d652d8dcacb3a1fc7015.jpg"

results = model(image_path)
results[0].save(filename="/content/deteccion.jpg")

display(Image.open("/content/deteccion.jpg"))
```

Esta prueba permitió verificar que el modelo exportado seguía funcionando correctamente antes de integrarlo al pipeline en tiempo real.

---

## 4. Comunicación bidireccional entre Simulink y Python

Una vez entrenado el modelo, fue necesario integrarlo al pipeline de self-driving. Para ello se desarrolló un script en Python que se comunica con Simulink mediante sockets TCP. El sistema es bidireccional: Simulink envía frames al script, y el script devuelve una lista estructurada de detecciones.

### 4.1 Configuración inicial del servicio

```python
import socket
import numpy as np
import cv2
import threading

HOST = "localhost"
PORT = 18002

frame_size = 640*480*3
latest_frame = None
running = True

s = socket.socket()
s.bind((HOST, PORT))
s.listen(1)

print("Esperando conexión...")
conn, addr = s.accept()
print("Conectado desde:", addr)
```

Aquí el tamaño de frame se define como:

$$
N_{bytes} = 640 \times 480 \times 3
$$

### 4.2 Creación del canal de retorno

```python
send_socket = socket.socket()
send_socket.bind(("localhost", 18001))
send_socket.listen(1)

print("Esperando conexión de Simulink (retorno)...")
conn_send, addr_send = send_socket.accept()
print("Simulink conectado para retorno:", addr_send)
```

### 4.3 Carga del modelo de inferencia

```python
print("Importando YOLO...")
from ultralytics import YOLO

print("Cargando modelo...")
model = YOLO(r"C:\Users\desqu\OneDrive\Desktop\decimo semestre\sins autonomos\best2.onnx", task="detect")
print("Modelo cargado")
```

### 4.4 Hilo de recepción de imágenes

```python
def receive_frames():
    global latest_frame, running

    while running:

        data = b''

        while len(data) < frame_size:
            packet = conn.recv(frame_size - len(data))
            if not packet:
                running = False
                return
            data += packet

        frame = np.frombuffer(data, dtype=np.uint8)
        frame = frame.reshape((480,640,3), order='F')
        frame = cv2.cvtColor(frame, cv2.COLOR_RGB2BGR)

        latest_frame = frame
```

### 4.5 Hilo de inferencia y retorno de resultados

```python
def inference_loop():
    global latest_frame, running

    while running:

        if latest_frame is None:
            continue

        frame = latest_frame.copy()

        results = model(frame, verbose=False)

        annotated = results[0].plot()

        MAX_DET = 10
        output = np.zeros((MAX_DET, 6), dtype=np.float32)

        boxes = results[0].boxes

        if boxes is not None:

            for i in range(min(len(boxes), MAX_DET)):

                cls = int(boxes.cls[i].item())
                conf = float(boxes.conf[i].item())
                x1, y1, x2, y2 = boxes.xyxy[i].cpu().numpy()

                output[i] = [cls, conf, x1, y1, x2, y2]

        data_bytes = output.flatten().tobytes()
        conn_send.sendall(data_bytes)
        print("Enviando bytes:", len(data_bytes))

        cv2.imshow("deteccion", annotated)

        if cv2.waitKey(1) == 27:
            running = False
            break
```

Cada detección enviada a Simulink queda representada como:

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

con un máximo de 10 detecciones por frame.

### 4.6 Ejecución concurrente

```python
t1 = threading.Thread(target=receive_frames)
t2 = threading.Thread(target=inference_loop)

t1.start()
t2.start()

t1.join()
t2.join()

conn.close()
cv2.destroyAllWindows()
```

---

## 5. Estimación de profundidad sobre las detecciones: función `addDepth`

El detector de objetos proporciona información bidimensional, pero para tomar decisiones de conducción también es necesario estimar la distancia real del objeto. Para ello se implementó la función `addDepth`.

### 5.1 Definición de la función

```matlab
function out = addDepth(detections, depth)

% detections: [6 x 10]
% depth: [480 x 640]

out = zeros(7,10,'single');
```

La salida agrega una séptima componente \(\hat{z}_i\) a cada detección:

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

### 5.2 Código completo

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

### 5.3 Formulación matemática

La región de interés del objeto se define como:

$$
B_i = \{(u,v)\;|\; x_{1,i} \le u \le x_{2,i},\ y_{1,i} \le v \le y_{2,i}\}
$$

Luego se forma el conjunto de profundidades válidas:

$$
\mathcal{Z}_i =
\left\{
D(u,v)\;|\;(u,v)\in B_i,\ D(u,v)>0,\ D(u,v)\neq \text{NaN}
\right\}
$$

y la distancia estimada se calcula como:

$$
\hat{z}_i =
\begin{cases}
\operatorname{median}(\mathcal{Z}_i), & \mathcal{Z}_i \neq \varnothing \\
999, & \mathcal{Z}_i = \varnothing
\end{cases}
$$

La mediana se eligió por su robustez frente a valores atípicos y ruido dentro del bounding box.

---

## 6. Lógica reglamentaria para señales: `stopLogic`

La función `stopLogic` implementa el comportamiento del vehículo frente a señales de tránsito relevantes del escenario: **STOP**, **YIELD** y **ROUNDABOUT**.

### 6.1 Código completo

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

### 6.2 Formulación matemática

Para cada detección se calcula el centro horizontal:

$$
c_{x,i} = \frac{x_{1,i}+x_{2,i}}{2}
$$

y una señal se considera frontal si:

$$
|c_{x,i} - 320| < 100
$$

#### Condición STOP

$$
c_i = 5,\qquad \rho_i > 0.9,\qquad \hat{z}_i < 1.3,\qquad |c_{x,i} - 320| < 100
$$

Cuando se activa:

$$
v_{out}(t) =
\begin{cases}
0, & 0 \le t-t_0 < 5 \\
v_{in}(t), & t-t_0 \ge 5
\end{cases}
$$

#### Condición YIELD

$$
c_i = 7,\qquad \rho_i > 0.9,\qquad \hat{z}_i < 1.5,\qquad |c_{x,i} - 320| < 100
$$

Cuando se activa:

$$
v_{out}(t) =
\begin{cases}
0, & 0 \le t-t_y < 2 \\
v_{in}(t), & t-t_y \ge 2
\end{cases}
$$

#### Condición ROUNDABOUT

$$
c_i = 4,\qquad \rho_i > 0.8,\qquad \hat{z}_i < 2.0,\qquad |c_{x,i} - 320| < 100
$$

Cuando se detecta:

$$
v_{out}(t) = 0.5\,v_{in}(t)
$$

#### Jerarquía de prioridades

La función fue diseñada con la jerarquía:

$$
\text{STOP} > \text{YIELD} > \text{ROUNDABOUT}
$$

---

## 7. Evasión de obstáculos tipo cono: `avoidCone`

La función `avoidCone` implementa una maniobra local de evasión cuando el vehículo detecta un cono cercano.

### 7.1 Código completo

```matlab
function [steering_out, direction]= avoidCone(steering_in, detections, t)
    persistent avoid_active t_start
    if isempty(avoid_active)
        avoid_active = false;
        t_start = 0;
    end

    % Parámetros de la maniobra
    T_total = 3.0;
    Amp = 0.5;

    cone_detected = false;
    direction = 0;

    for i = 1:size(detections, 2)
        class_id = detections(1,i);
        prob     = detections(2,i);
        dist     = detections(7,i);
        
        if class_id == 0 && prob > 0.85 && dist < 1.5 
            cone_detected = true;
            direction = 1;
            break;
        end
    end

    if cone_detected && ~avoid_active
        avoid_active = true;
        direction = 1;
        t_start = t;
    end

    if avoid_active
        dt = t - t_start;
        direction = 1;
        
        if dt < T_total
            steering_avoid = Amp * sin(2 * pi * dt / T_total);
            steering_out = steering_avoid; 
        else
            avoid_active = false;
            steering_out = steering_in;
        end
    else
        steering_out = steering_in;
        direction = 0;
    end
end
```

### 7.2 Formulación matemática

La evasión se activa cuando existe al menos una detección que satisfaga:

$$
c_i = 0,\qquad \rho_i > 0.85,\qquad \hat{z}_i < 1.5
$$

Durante la evasión, la señal de dirección se define como:

$$
\delta_{avoid}(t) = A \sin\left(\frac{2\pi (t-t_0)}{T_{total}}\right)
$$

con:

$$
A = 0.5,\qquad T_{total} = 3.0\ \text{s}
$$

La dirección final queda entonces:

$$
\delta_{out}(t) =
\begin{cases}
\delta_{avoid}(t), & \text{si la evasión está activa} \\
\delta_{in}(t), & \text{en otro caso}
\end{cases}
$$

Esta ley genera una maniobra tipo “S”, suave y continua, que permite esquivar el obstáculo sin introducir cambios bruscos en la dirección.

---

## 8. Integración del pipeline completo

Una vez integrados todos los módulos, el flujo funcional del sistema puede resumirse así:

1. El planificador genera una trayectoria global óptima:

$$
P^\star = \arg\min_{P \in \mathcal{P}(s,g)} \sum_{(i,j)\in P} \left(d_{ij}+p_{ij}\right)
$$

2. La trayectoria discreta se suaviza:

$$
x_s(\tau)=\operatorname{PCHIP}(t_k,x_k), \qquad
y_s(\tau)=\operatorname{PCHIP}(t_k,y_k)
$$

3. El detector entrega hasta diez objetos por frame:

$$
\mathbf{d}_i =
\begin{bmatrix}
c_i & \rho_i & x_{1,i} & y_{1,i} & x_{2,i} & y_{2,i}
\end{bmatrix}^T
$$

4. La función de profundidad enriquece cada detección:

$$
\mathbf{o}_i =
\begin{bmatrix}
c_i & \rho_i & x_{1,i} & y_{1,i} & x_{2,i} & y_{2,i} & \hat{z}_i
\end{bmatrix}^T
$$

5. La lógica reglamentaria calcula la velocidad final:

$$
v_{out}(t) =
\begin{cases}
0, & \text{si STOP o YIELD están activos} \\
0.5\,v_{in}(t), & \text{si se detecta glorieta} \\
v_{in}(t), & \text{en otro caso}
\end{cases}
$$

6. La lógica de evasión calcula la dirección final:

$$
\delta_{out}(t) =
\begin{cases}
A \sin\left(\dfrac{2\pi (t-t_0)}{T_{total}}\right), & \text{si hay evasión activa} \\
\delta_{in}(t), & \text{en otro caso}
\end{cases}
$$

De esta manera, el vehículo no solo sigue una trayectoria previamente calculada, sino que adapta en tiempo real sus comandos de velocidad y dirección según el contexto del entorno percibido.

---

## 9. Validación general del sistema

La validación del sistema se realizó de manera modular. El módulo de planeación se validó observando la coherencia geométrica de la trayectoria generada sobre el mapa y verificando que el camino óptimo siguiera una lógica consistente con la red vial y las penalizaciones definidas. El módulo de percepción se validó con métricas cuantitativas como mAP, precisión y recall, además de pruebas cualitativas sobre imágenes de test y sobre inferencia en línea. El módulo de profundidad se validó comprobando que las distancias estimadas fueran consistentes con la región de interés de los objetos detectados. Finalmente, la lógica de decisión se validó revisando que STOP, YIELD, ROUNDABOUT y evasión de conos modificaran correctamente los comandos del vehículo bajo las condiciones previstas.

En conjunto, la solución presentada constituye un pipeline de self-driving técnicamente estructurado, donde cada parte del sistema puede justificarse con criterios matemáticos, geométricos y funcionales.

---

## 10. Conclusión técnica

La solución desarrollada para la CPS IoT Self-Driving Competition 2026 integra una arquitectura modular de conducción autónoma implementada sobre el **QCar 2 virtual** en **QLabs**, utilizando **MATLAB/Simulink** como entorno principal de integración. A nivel metodológico, el proyecto combinó parametrización formal del vehículo, planeación global mediante grafos dirigidos con penalizaciones, entrenamiento de un detector de objetos orientado al escenario de Quanser City, comunicación bidireccional entre Simulink y Python, estimación de profundidad sobre regiones detectadas, lógica reglamentaria frente a señales y maniobras locales de evasión de obstáculos.

Desde una perspectiva de ingeniería, el valor de la solución radica en que cada módulo fue diseñado con una función clara y validable, y después fue integrado en una arquitectura jerárquica coherente. El sistema no solo genera una ruta, sino que también percibe el entorno, interpreta señales, estima distancias y modifica su comportamiento en tiempo real. Esta combinación de planeación, percepción y reacción contextual hace que la propuesta sea una solución técnicamente sólida, defendible y alineada con los requerimientos de una competencia de self-driving de alto nivel.

---

## Anexo A. Código completo de planeación global

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

G = digraph(edges(:,1), edges(:,2), weights);

startNode = 1;
goalNode = 44;

[pathNodes, totalCost] = shortestpath(G, startNode, goalNode);

centro_interseccion = [0.144, 0.939]; 

casos_criticos = [23, 32; 
                  15, 24; 
                  44, 16; 
                  31, 45];

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

path_x_final = nodes(pathNodes_corrected, 1);
path_y_final = nodes(pathNodes_corrected, 2);

t_new = 1:length(path_x_final);
tq_new = linspace(1, length(path_x_final), 1761);

path_x_smooth = interp1(t_new, path_x_final, tq_new, 'pchip');
path_y_smooth = interp1(t_new, path_y_final, tq_new, 'pchip');
```

---

## Anexo B. Código completo del servicio de inferencia Python

```python
import socket
import numpy as np
import cv2
import threading

HOST = "localhost"
PORT = 18002

frame_size = 640*480*3
latest_frame = None
running = True

s = socket.socket()
s.bind((HOST, PORT))
s.listen(1)

print("Esperando conexión...")
conn, addr = s.accept()
print("Conectado desde:", addr)

send_socket = socket.socket()
send_socket.bind(("localhost", 18001))
send_socket.listen(1)

print("Esperando conexión de Simulink (retorno)...")
conn_send, addr_send = send_socket.accept()
print("Simulink conectado para retorno:", addr_send)

print("Importando YOLO...")
from ultralytics import YOLO

print("Cargando modelo...")
model = YOLO(r"C:\Users\desqu\OneDrive\Desktop\decimo semestre\sins autonomos\best2.onnx", task="detect")
print("Modelo cargado")

def receive_frames():
    global latest_frame, running

    while running:

        data = b''

        while len(data) < frame_size:
            packet = conn.recv(frame_size - len(data))
            if not packet:
                running = False
                return
            data += packet

        frame = np.frombuffer(data, dtype=np.uint8)
        frame = frame.reshape((480,640,3), order='F')
        frame = cv2.cvtColor(frame, cv2.COLOR_RGB2BGR)

        latest_frame = frame

def inference_loop():
    global latest_frame, running

    while running:

        if latest_frame is None:
            continue

        frame = latest_frame.copy()

        results = model(frame, verbose=False)

        annotated = results[0].plot()

        MAX_DET = 10
        output = np.zeros((MAX_DET, 6), dtype=np.float32)

        boxes = results[0].boxes

        if boxes is not None:

            for i in range(min(len(boxes), MAX_DET)):

                cls = int(boxes.cls[i].item())
                conf = float(boxes.conf[i].item())
                x1, y1, x2, y2 = boxes.xyxy[i].cpu().numpy()

                output[i] = [cls, conf, x1, y1, x2, y2]

        data_bytes = output.flatten().tobytes()
        conn_send.sendall(data_bytes)
        print("Enviando bytes:", len(data_bytes))

        cv2.imshow("deteccion", annotated)

        if cv2.waitKey(1) == 27:
            running = False
            break

t1 = threading.Thread(target=receive_frames)
t2 = threading.Thread(target=inference_loop)

t1.start()
t2.start()

t1.join()
t2.join()

conn.close()
cv2.destroyAllWindows()
```

---

## Anexo C. Código completo de funciones auxiliares

### `addDepth.m`

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

### `stopLogic.m`

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

### `avoidCone.m`

```matlab
function [steering_out, direction]= avoidCone(steering_in, detections, t)
    persistent avoid_active t_start
    if isempty(avoid_active)
        avoid_active = false;
        t_start = 0;
    end

    T_total = 3.0;
    Amp = 0.5;

    cone_detected = false;
    direction = 0;

    for i = 1:size(detections, 2)
        class_id = detections(1,i);
        prob     = detections(2,i);
        dist     = detections(7,i);
        
        if class_id == 0 && prob > 0.85 && dist < 1.5 
            cone_detected = true;
            direction = 1;
            break;
        end
    end

    if cone_detected && ~avoid_active
        avoid_active = true;
        direction = 1;
        t_start = t;
    end

    if avoid_active
        dt = t - t_start;
        direction = 1;
        
        if dt < T_total
            steering_avoid = Amp * sin(2 * pi * dt / T_total);
            steering_out = steering_avoid; 
        else
            avoid_active = false;
            steering_out = steering_in;
        end
    else
        steering_out = steering_in;
        direction = 0;
    end
end
```