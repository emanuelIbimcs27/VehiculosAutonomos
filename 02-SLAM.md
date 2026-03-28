---
layout: default
title: SLAM
nav_order: 4
---

---
layout: page
title: "Metodología de Diseño y Validación del Algoritmo de Self-Driving para la CPS IoT Competition 2026"
permalink: /metodologia-self-driving/
nav_order: 3
---

# Metodología de Diseño y Validación del Algoritmo de Self-Driving para la CPS IoT Competition 2026

## Introducción general

El desarrollo presentado en esta sección corresponde al diseño, integración y validación de un algoritmo de conducción autónoma implementado para el entorno virtual de **Quanser City** utilizando el **QCar 2 virtual** dentro de **QLabs**, con una arquitectura principal desarrollada en **MATLAB/Simulink**. La solución fue concebida para la **CPS IoT Self-Driving Competition 2026**, tomando como base el flujo oficial de trabajo del stack virtual de Quanser y extendiéndolo con módulos propios de planeación, percepción, estimación de profundidad, lógica reglamentaria y evasión de obstáculos.

Desde el punto de vista ingenieril, el sistema no fue diseñado como un único bloque monolítico, sino como una cadena funcional compuesta por subsistemas especializados. Esta decisión permitió separar claramente el problema de conducción autónoma en varias capas: configuración del vehículo y del entorno, generación de trayectoria global, percepción visual mediante red neuronal, enriquecimiento espacial de detecciones, lógica de comportamiento frente a señales y obstáculos, y finalmente ejecución de acciones sobre velocidad y dirección.

Una parte clave del proyecto consistió en entrenar un modelo de detección de objetos orientado al escenario de **Quanser City**, de modo que el sistema fuera capaz de reconocer elementos relevantes del entorno, como conos y señales de tránsito, directamente desde imágenes capturadas por el vehículo virtual. Posteriormente, dicho modelo fue integrado con Simulink mediante un enlace bidireccional con Python, permitiendo correr inferencia en línea dentro del pipeline del vehículo autónomo. Así, el sistema no solo sigue una trayectoria previamente calculada, sino que también percibe el entorno, estima distancias y modifica su comportamiento cuando detecta eventos relevantes en la escena.

---

## Arquitectura general de la solución

La arquitectura implementada se estructuró en cinco niveles funcionales. En el primer nivel se definió la parametrización general del vehículo virtual, incluyendo tiempos de muestreo, ganancias de control, constantes geométricas y archivos de calibración. En el segundo nivel se desarrolló el módulo de planeación global, encargado de construir una trayectoria óptima entre un nodo inicial y un nodo objetivo a partir de una representación topológica del mapa. En el tercer nivel se integró la percepción visual mediante un detector de objetos basado en YOLOv8, entrenado específicamente para los elementos presentes en el escenario. En el cuarto nivel se enriquecieron las detecciones 2D con información de profundidad, haciendo posible que el vehículo interpretara la distancia real de los objetos detectados. Finalmente, en el quinto nivel se implementaron reglas de decisión para señales y obstáculos, modificando en tiempo real la velocidad y la dirección del vehículo.

Esta organización modular fue especialmente útil porque permitió validar cada subsistema por separado y después integrarlos de forma jerárquica dentro de Simulink. La trayectoria global actúa como referencia nominal de navegación, pero puede ser temporalmente sobreescrita cuando aparecen condiciones especiales del entorno, por ejemplo una señal de STOP o un cono cercano. De esta manera, el sistema combina planeación de alto nivel con reacción local basada en percepción, que es una característica fundamental de cualquier solución seria de self-driving.

---

## 1. Parametrización del QCar 2 virtual y definición del entorno

La primera etapa del desarrollo consistió en configurar el vehículo virtual y todos los parámetros base del stack. Para ello se utilizó un script de inicialización en MATLAB donde se establece el tipo de mapa, el tipo de QCar, los tiempos de muestreo de cada subsistema, las ganancias del controlador de dirección, los parámetros de estimación y los archivos de calibración utilizados por el modelo.

### Definición del tipo de mapa y tipo de vehículo

```matlab
clear all;

%% User configurable parameters
map_type = 1;
qcar_types = 1;
```

En este bloque se definen dos parámetros fundamentales. El primero, `map_type = 1`, indica que se está trabajando sobre el mapa grande del entorno SDCS. El segundo, `qcar_types = 1`, selecciona la configuración correspondiente al **QCar virtual**. Este detalle es importante porque el mismo archivo contempla una diferenciación entre plataforma virtual y plataforma física, lo cual deja preparada la arquitectura para una posible migración futura a hardware real.

### Definición de tiempos de muestreo

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

Este bloque fija la base temporal del sistema. El controlador principal opera con un tiempo de muestreo de `1/500 s`, es decir, a una frecuencia de 500 Hz. A partir de ese periodo base se derivan los tiempos de muestreo de los demás subsistemas, como cámaras, LiDAR, visualización y red neuronal. Esta estrategia de sincronización es técnicamente muy importante, porque evita inconsistencias temporales entre sensores, controladores y módulos de procesamiento. En lugar de que cada componente opere con una frecuencia arbitraria, todos se alinean a una referencia temporal común.

El parámetro `NN_Sample_Time` fue igualado al tiempo de la cámara RealSense, lo cual tiene sentido desde el punto de vista del procesamiento de imágenes: la inferencia del detector de objetos se ejecuta al ritmo en que llegan los frames relevantes del sistema visual.

### Selección del punto de calibración

```matlab
if map_type == 1
    cal_pos = [0, 2, 0]
    disp('Large SDCS Map Being Used ...')
else
    cal_pos = [0, 0, 0]
    disp('Small map Being Used ...')
end
```

La variable `cal_pos` define la posición de calibración usada como referencia del entorno. En este caso, al trabajar sobre el mapa grande, se selecciona el vector `[0, 2, 0]`. Este desplazamiento aparece posteriormente en la visualización de la trayectoria, ya que la ruta generada se ajusta con respecto al marco de referencia del mapa y del sistema de calibración.

### Ganancias del controlador de dirección

```matlab
if qcar_types == 1 % IF VIRTUAL
    steering_Kp = 1.2;
    steering_Kd = 0.6;
elseif qcar_types == 2 % IF PHYSICAL
    steering_Kp = 1;
    steering_Kd = 0.1;
end
```

En este bloque se definen las ganancias del controlador PD de dirección. Para el caso virtual se eligieron `Kp = 1.2` y `Kd = 0.6`. La acción proporcional permite corregir el error de trayectoria, mientras que la acción derivativa ayuda a amortiguar cambios bruscos en la dirección y reduce oscilaciones en la respuesta. El hecho de diferenciar entre parámetros virtuales y físicos indica que el sistema fue diseñado con conciencia del cambio de dinámica entre el simulador y el QCar real.

### Parámetros de filtrado y estimación

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

### Carga de archivos de calibración y referencia angular

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

En esta parte se corrige la orientación del LiDAR con respecto al mapa y se cargan los datos de distancia y ángulos utilizados como referencia espacial. Esto es importante porque la planeación y la visualización necesitan un marco coherente entre el entorno, los sensores y la trayectoria calculada.

---

## 2. Planeación global de trayectoria mediante grafos y penalizaciones

La trayectoria del vehículo no fue definida manualmente. En su lugar, se construyó un grafo dirigido ponderado sobre el mapa de Quanser City, donde los nodos representan posiciones relevantes del escenario y las aristas describen transiciones permitidas entre esos puntos. A cada arista se le asignó un costo compuesto por la distancia geométrica y una penalización adicional, con el objetivo de favorecer rutas no solo cortas, sino también operativamente convenientes.

### Definición de nodos

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

Cada fila de esta matriz representa un nodo del grafo en coordenadas cartesianas \(x, y\). Estos nodos corresponden a puntos estratégicos del mapa, tales como intersecciones, conexiones de carril, curvas y zonas de paso. Esta discretización permite transformar el problema continuo de navegación en un problema de planeación sobre una red topológica.

### Definición de aristas

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

Las aristas del grafo indican qué nodos se encuentran conectados y en qué dirección puede desplazarse el vehículo. Esto convierte la planeación en un problema dirigido, acorde con la lógica de circulación del entorno.

### Penalizaciones de trayecto

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

Este vector de penalizaciones es uno de los elementos más valiosos del módulo de planeación. En lugar de elegir únicamente la ruta más corta en distancia, el algoritmo favorece la trayectoria menos costosa desde una perspectiva operativa. Un tramo puede ser corto pero indeseable por su complejidad geométrica, por un cruce conflictivo o por restricciones del entorno. Al sumar penalizaciones, la planeación incorpora inteligencia adicional más allá de la pura distancia.

### Cálculo de pesos de las aristas

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

Aquí se calcula el peso total de cada arista sumando la distancia euclidiana entre nodos y la penalización asignada. Este peso es el que finalmente usa el algoritmo de ruta mínima.

### Cálculo de la ruta óptima

```matlab
G = digraph(edges(:,1), edges(:,2), weights);

startNode = 1;
goalNode = 44;

[pathNodes, totalCost] = shortestpath(G, startNode, goalNode);
```

En esta parte se genera el grafo dirigido ponderado y se calcula la ruta óptima desde el nodo inicial hasta el nodo objetivo usando `shortestpath`. El resultado es una secuencia discreta de nodos que representa el camino seleccionado por el planificador.

### Corrección de intersecciones críticas

```matlab
centro_interseccion = [0.144, 0.939]; 

casos_criticos = [23, 32; 
                  15, 24; 
                  44, 16; 
                  31, 45];

pathNodes_corrected = [];
```

En algunos cruces, una unión directa entre nodos generaba trayectorias geométricamente deficientes. Para resolverlo, se definió un nodo auxiliar en el centro de la intersección, el cual se inserta solo cuando el algoritmo detecta uno de los segmentos críticos definidos.

```matlab
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

Este mecanismo mejora la geometría local de la trayectoria sin alterar la lógica global del planeador. Se trata de una mejora muy útil para el seguimiento posterior por parte del controlador.

### Suavizado de la ruta con PCHIP

```matlab
path_x_final = nodes(pathNodes_corrected, 1);
path_y_final = nodes(pathNodes_corrected, 2);

t_new = 1:length(path_x_final);
tq_new = linspace(1, length(path_x_final), 1761);

path_x_smooth = interp1(t_new, path_x_final, tq_new, 'pchip');
path_y_smooth = interp1(t_new, path_y_final, tq_new, 'pchip');
```

La interpolación PCHIP convierte la trayectoria discreta en una ruta continua y suave, evitando oscilaciones excesivas y cambios bruscos de dirección. Esto es indispensable para que el vehículo pueda seguir la referencia de forma estable.

### Visualización de la trayectoria

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

Este bloque produce la figura final de la planeación. La referencia negra punteada corresponde al marco espacial del entorno, mientras que la línea roja representa la trayectoria final suavizada que el QCar debe seguir.

### Figura de trayectoria planeada

![Trayectoria global generada para el QCar 2 virtual](/assets/img/trayectoria_qcar.png)

**Descripción de la figura.**  
La figura muestra el resultado final del módulo de planeación global. La nube punteada negra representa la referencia espacial del entorno utilizada para la calibración, mientras que la curva roja representa la trayectoria objetivo generada a partir del grafo dirigido, corregida en intersecciones críticas y suavizada mediante interpolación PCHIP. Esta visualización valida que la ruta final es consistente con la topología del mapa y que posee continuidad geométrica suficiente para ser seguida por el controlador del vehículo.

---

## 3. Entrenamiento y validación del modelo de detección de objetos para Quanser City

El sistema de percepción visual se construyó a partir de un modelo YOLOv8 entrenado específicamente para detectar objetos del escenario de Quanser City. El entrenamiento se realizó en Google Colab con soporte de GPU, y posteriormente el modelo fue exportado a ONNX para ser integrado al pipeline de Simulink mediante Python.

### Verificación del entorno de cómputo

```python
import torch
print(torch.cuda.is_available())  # Debe imprimir True
print(torch.cuda.device_count())  # Debe imprimir 1 o más
```

Este bloque verifica la disponibilidad de GPU, condición importante para acelerar el entrenamiento del modelo.

### Instalación de Ultralytics y verificación del entorno

```python
!pip install ultralytics

import ultralytics
ultralytics.checks()
```

Aquí se instala la librería `ultralytics` y se comprueba que el entorno de ejecución sea compatible con el entrenamiento de YOLOv8.

### Carga y preparación del dataset

```python
from google.colab import files
uploaded = files.upload()

!unzip detection_2025.v8i.yolov8.zip

!ls
!ls valid
!ls test
!ls train
```

En esta etapa se sube y descomprime el dataset. La separación en carpetas `train`, `valid` y `test` permite seguir una metodología correcta de entrenamiento, validación y evaluación.

### Entrenamiento del modelo

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

Se eligió como punto de partida `yolov8s.pt`, que corresponde a la variante *small* del modelo. El entrenamiento se realizó durante 150 épocas, con imágenes de tamaño 640 y lotes de 32 muestras. Esta configuración buscó un equilibrio entre capacidad de detección y viabilidad de despliegue.

### Exportación a ONNX

```python
model.export(format="onnx", opset=12)
```

La exportación a ONNX fue un paso esencial, ya que permitió llevar el detector entrenado a un formato portable e integrarlo posteriormente con el script de inferencia en Python.

### Validación cuantitativa del modelo

```python
model = YOLO("runs/detect/train/weights/best.pt")
metrics = model.val(data="data.yaml")
print("mAP@50:", metrics.box.map50)
print("mAP@50-95:", metrics.box.map)
print("Precision:", metrics.box.mp)
print("Recall:", metrics.box.mr)
```

Este bloque calcula las métricas más importantes para evaluar el desempeño del detector. El `mAP@50` y el `mAP@50-95` permiten medir la calidad general de detección, mientras que `Precision` y `Recall` informan sobre la exactitud y cobertura del modelo respecto a los objetos reales del entorno.

### Prueba cualitativa del modelo exportado

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

Esta prueba cualitativa permitió verificar que el modelo ONNX exportado seguía funcionando correctamente sobre nuevas imágenes, antes de ser integrado en línea con Simulink.

---

## 4. Comunicación bidireccional entre Simulink y Python

Una vez entrenado el modelo, fue necesario integrarlo al pipeline de self-driving. Para ello se desarrolló un script en Python que se comunica con Simulink mediante sockets TCP. El sistema es bidireccional: Simulink envía frames al script, y el script devuelve una lista estructurada de detecciones.

### Configuración inicial del servicio

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

Este primer bloque crea un socket de entrada para recibir imágenes desde Simulink. Se define un tamaño fijo de frame de `640*480*3`, lo cual indica que cada imagen se transmitirá como una matriz RGB de tamaño 640 por 480 píxeles.

### Creación del canal de retorno hacia Simulink

```python
send_socket = socket.socket()
send_socket.bind(("localhost", 18001))
send_socket.listen(1)

print("Esperando conexión de Simulink (retorno)...")
conn_send, addr_send = send_socket.accept()
print("Simulink conectado para retorno:", addr_send)
```

Aquí se crea un segundo canal, esta vez para devolver a Simulink los resultados de la inferencia. Esta separación entre recepción y retorno facilita mucho la integración.

### Carga del modelo de inferencia

```python
print("Importando YOLO...")
from ultralytics import YOLO

print("Cargando modelo...")
model = YOLO(r"C:\Users\desqu\OneDrive\Desktop\decimo semestre\sins autonomos\best2.onnx", task="detect")
print("Modelo cargado")
```

Este bloque carga el archivo ONNX que se utilizará para la detección de objetos durante la ejecución del sistema.

### Hilo de recepción de imágenes

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

Esta función recibe continuamente imágenes desde Simulink. Un detalle muy importante es el uso de `order='F'`, que respeta la convención de almacenamiento tipo *column-major* utilizada por MATLAB. Si este parámetro no se incluyera, la imagen podría reconstruirse de forma incorrecta.

### Hilo de inferencia y envío de resultados

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

Este es el núcleo del servicio de inferencia. El script toma el último frame disponible, ejecuta YOLO sobre él y construye una matriz fija de tamaño `10 x 6`, donde cada detección contiene: clase, confianza, coordenada `x1`, coordenada `y1`, coordenada `x2` y coordenada `y2`. Esa matriz se aplana y se envía a Simulink en forma de bytes.

La decisión de usar una estructura de salida fija es muy importante, porque simplifica la integración con bloques de Simulink y evita manejar listas de tamaño variable en tiempo real.

### Creación y ejecución de hilos

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

Finalmente, el sistema se ejecuta usando dos hilos: uno dedicado a la recepción de imágenes y otro a la inferencia. Esto permite desacoplar la llegada de frames del tiempo de procesamiento del detector.

---

## 5. Estimación de profundidad sobre las detecciones: función `addDepth`

El modelo YOLO entrega cajas delimitadoras en 2D, pero una detección 2D por sí sola no basta para tomar decisiones de conducción. Por ello se implementó la función `addDepth`, cuyo propósito es añadir a cada detección una estimación de distancia basada en la imagen de profundidad.

### Definición de la función

```matlab
function out = addDepth(detections, depth)

% detections: [6 x 10]
% depth: [480 x 640]

out = zeros(7,10,'single');
```

La matriz `detections` contiene hasta diez objetos con seis atributos por cada uno. La matriz `depth` contiene la información de profundidad por píxel. La salida `out` agrega una séptima fila para almacenar la distancia estimada.

### Iteración sobre las detecciones

```matlab
for i = 1:10
    
    prob = detections(2,i);
    
    if prob > 0
        
        x1 = detections(3,i);
        y1 = detections(4,i);
        x2 = detections(5,i);
        y2 = detections(6,i);
```

Aquí se recorren las detecciones una por una y se extraen las coordenadas del bounding box correspondiente.

### Conversión a índices válidos y saturación

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

Este bloque garantiza que las coordenadas sean enteras y estén dentro de los límites válidos de la imagen. Es un paso indispensable para evitar errores de indexación al extraer la región de interés.

### Corrección del orden de coordenadas

```matlab
        if x2 < x1
            temp = x1; x1 = x2; x2 = temp;
        end
        if y2 < y1
            temp = y1; y1 = y2; y2 = temp;
        end
```

En caso de que el bounding box llegue con coordenadas invertidas, aquí se corrige su orden. Esto mejora la robustez de la función.

### Extracción de la región de profundidad y filtrado de valores inválidos

```matlab
        roi = depth(y1:y2, x1:x2);

        roi = roi(~isnan(roi));
        roi = roi(roi > 0);
```

En lugar de tomar la profundidad del centro del objeto, se utiliza toda la región contenida dentro de la caja. Esto es una decisión muy adecuada, porque reduce la sensibilidad a huecos del sensor o píxeles atípicos.

### Estimación robusta de la distancia

```matlab
        if isempty(roi)
            dist = single(999);
        else
            dist = median(roi); 
        end
```

La distancia final se calcula como la mediana de la región de profundidad válida. La mediana es un estimador robusto frente a valores extremos, por lo que suele ser más confiable que el promedio en este tipo de aplicaciones.

### Guardado de la salida enriquecida

```matlab
        out(1:6,i) = detections(:,i);
        out(7,i) = dist;
        
    end
end
```

Al final, cada detección queda enriquecida con una medida espacial, lo cual es crucial para que la lógica de señales y evasión pueda decidir no solo qué objeto se detectó, sino a qué distancia se encuentra.

---

## 6. Lógica reglamentaria para señales: `stopLogic`

La función `stopLogic` implementa el comportamiento del vehículo frente a señales de tránsito relevantes del escenario, concretamente **STOP**, **YIELD** y **ROUNDABOUT**. Este módulo modifica la velocidad del vehículo de acuerdo con reglas jerárquicas y tiempos de espera definidos.

### Variables persistentes

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
```

Estas variables permiten que la función mantenga memoria entre iteraciones. Gracias a ello, una vez activada una maniobra de STOP o YIELD, el sistema puede mantenerla durante el tiempo requerido sin depender únicamente del frame actual.

### Variables de detección

```matlab
speed_out = speed_in;

stop_detected = false;
yield_detected = false;
round_detected = false;
```

Aquí se inicializan banderas para cada tipo de señal.

### Evaluación de cada objeto detectado

```matlab
for i = 1:10
    
    class_id = detections(1,i);
    prob     = detections(2,i);
    dist     = detections(7,i);
    
    x1 = detections(3,i);
    x2 = detections(5,i);
    cx = (x1 + x2)/2;
    
    frontal = abs(cx - 320) < 100;
```

Además de revisar la clase, la confianza y la distancia, la lógica calcula si la señal se encuentra aproximadamente centrada en la imagen. Esto es importante porque evita activar decisiones por señales detectadas a un costado y que probablemente no estén asociadas al carril del vehículo.

### Detección de STOP

```matlab
    if class_id == 5 && prob > 0.9 && dist < 1.3 && frontal
        stop_detected = true;
    end
```

La señal de STOP solo activa la lógica si cumple simultáneamente con alta confianza, cercanía suficiente y posición frontal.

### Detección de YIELD

```matlab
    if class_id == 7 && prob > 0.9 && dist < 1.5 && frontal
        yield_detected = true;
    end
```

La lógica de ceda el paso sigue el mismo patrón, aunque con un umbral de distancia diferente.

### Detección de ROUNDABOUT

```matlab
    if class_id == 4 && prob > 0.8 && dist < 2.0 && frontal
        round_detected = true;
    end
    
end
```

La glorieta se detecta con un umbral algo más permisivo y a mayor distancia, permitiendo anticipar el evento con más tiempo.

### Prioridad máxima para STOP

```matlab
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
```

Aquí se ve claramente la prioridad máxima de STOP. Una vez activado, el vehículo se detiene completamente durante 5 segundos y la función retorna de inmediato, sin evaluar ninguna otra regla.

### Lógica de YIELD

```matlab
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
```

La señal YIELD genera una detención temporal de 2 segundos. Tiene prioridad menor que STOP, pero mayor que la lógica de glorieta.

### Reducción de velocidad en glorieta

```matlab
if round_detected
    speed_out = 0.5 * speed_in;
end
```

La presencia de una glorieta no detiene completamente al vehículo, pero reduce la velocidad al 50 % de su valor nominal. Esta es una respuesta coherente con una conducción más prudente en zonas de giro circular.

---

## 7. Evasión de obstáculos tipo cono: `avoidCone`

La función `avoidCone` implementa una maniobra local de evasión cuando el sistema detecta un cono cercano. En lugar de replantear toda la ruta global, se genera una perturbación temporal y suave sobre la dirección nominal del vehículo.

### Estado interno de la maniobra

```matlab
function [steering_out, direction]= avoidCone(steering_in, detections, t)
    persistent avoid_active t_start
    if isempty(avoid_active)
        avoid_active = false;
        t_start = 0;
    end
```

Estas variables persistentes permiten saber si el sistema ya se encuentra ejecutando una maniobra de evasión.

### Parámetros de la evasión

```matlab
    T_total = 3.0; % Duración total de la maniobra en segundos
    Amp = 0.5;     % Amplitud máxima del giro para esquivar
```

La maniobra tiene una duración total de 3 segundos y una amplitud máxima de steering de 0.5. Estos parámetros fueron ajustados experimentalmente para lograr una desviación suficiente sin volver la respuesta demasiado agresiva.

### Detección del cono

```matlab
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
```

El sistema activa evasión cuando detecta un objeto de clase cono con alta confianza y a menos de 1.5 metros.

### Activación de la maniobra

```matlab
    if cone_detected && ~avoid_active
        avoid_active = true;
        direction = 1;
        t_start = t;
    end
```

Cuando el cono aparece y no existe una maniobra activa, se registra el instante inicial y se activa el modo de evasión.

### Generación de la maniobra senoidal

```matlab
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

El steering evasivo se genera mediante una onda senoidal completa. Esta decisión es muy valiosa desde el punto de vista de control, porque produce una maniobra tipo “S” suave: el vehículo se desvía, rodea el obstáculo y luego vuelve gradualmente a la referencia nominal. Mientras la evasión está activa, el steering nominal se ignora temporalmente para asegurar que la maniobra tenga autoridad real sobre el vehículo.

---

## 8. Integración general del pipeline dentro de Simulink

Todos los módulos anteriores se integran dentro de una arquitectura de ejecución continua. El flujo completo del sistema puede describirse de la siguiente manera.

Primero, el script de parámetros configura el QCar 2 virtual, los tiempos de muestreo y la calibración del entorno. Después, el planificador de grafos calcula una trayectoria global óptima entre el punto inicial y el objetivo. Esa trayectoria suavizada se convierte en la referencia principal de navegación del vehículo. Paralelamente, Simulink transmite frames del entorno virtual a Python mediante sockets. Python ejecuta el modelo YOLO exportado a ONNX y devuelve a Simulink una matriz fija de detecciones. Esas detecciones son enriquecidas con profundidad mediante `addDepth`, lo cual permite conocer la distancia de señales y conos respecto al vehículo. Posteriormente, la función `stopLogic` decide si debe detenerse o reducir velocidad según el tipo de señal observada, mientras que `avoidCone` modifica temporalmente el steering en caso de detectar un obstáculo cercano. Finalmente, el vehículo sigue la trayectoria planeada siempre que ninguna lógica de prioridad la sobreescriba.

Este acoplamiento entre planeación global, percepción visual, estimación espacial y decisión reactiva es precisamente lo que convierte el proyecto en una solución de conducción autónoma completa y no solo en una demostración de seguimiento de trayectoria.

---

## 9. Conclusión técnica

La solución desarrollada para la CPS IoT Self-Driving Competition 2026 integra una arquitectura modular de conducción autónoma implementada sobre el **QCar 2 virtual** en **QLabs**, utilizando **MATLAB/Simulink** como entorno principal de integración. A nivel metodológico, el proyecto combinó parametrización formal del vehículo, planeación global mediante grafos dirigidos con penalizaciones, entrenamiento de un detector de objetos orientado al escenario de Quanser City, comunicación bidireccional entre Simulink y Python, estimación de profundidad sobre regiones detectadas, lógica reglamentaria frente a señales y maniobras locales de evasión de obstáculos.

Desde una perspectiva de ingeniería, el valor de la solución radica en que cada módulo fue diseñado con una función clara y validable, y después fue integrado en una arquitectura jerárquica coherente. El sistema no solo genera una ruta, sino que también percibe el entorno, interpreta señales, estima distancias y modifica su comportamiento en tiempo real. Esta combinación de planeación, percepción y reacción contextual hace que la propuesta sea una solución técnicamente sólida, defendible y alineada con los requerimientos de una competencia de self-driving de alto nivel.

---

## Anexo: código completo de planeación de trayectoria

Si deseas mostrar el script completo dentro de la página, puedes colocarlo en una sección colapsable o como bloque largo de referencia:

```matlab
% Pega aquí el script completo de nodos, aristas, penalizaciones,
% shortestpath, corrección de intersecciones y suavizado.
```

## Anexo: código completo del detector y comunicación con Simulink

```python
# Pega aquí el script completo del servidor Python con sockets,
# recepción de frames, inferencia y retorno de detecciones.
```

## Anexo: código completo de funciones auxiliares

```matlab
% addDepth.m
% stopLogic.m
% avoidCone.m
```