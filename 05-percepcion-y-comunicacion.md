---
layout: default
title: Percepción Visual y Comunicación Simulink-Python
nav_order: 3
parent: CPS IoT Competition 2026
permalink: /CPS/percepcion-y-comunicacion/
---

# Percepción Visual y Comunicación Simulink-Python

## 3. Entrenamiento y validación del modelo de detección de objetos para Quanser City

Una parte fundamental del sistema de self-driving fue el desarrollo del módulo de percepción visual. En el contexto de la competencia, no era suficiente con que el vehículo siguiera una trayectoria predefinida; también debía ser capaz de identificar elementos relevantes del entorno, tales como conos, señales de tránsito y semáforos, para poder modificar su comportamiento en tiempo real. Por esta razón, se entrenó una red neuronal orientada específicamente al escenario de Quanser City.

El modelo seleccionado fue una variante de **YOLOv8**, entrenada en Google Colab con soporte de GPU y posteriormente exportada al formato ONNX para facilitar su integración con el stack de Simulink. Esta decisión fue importante porque permitió separar el problema de entrenamiento del problema de despliegue. El entrenamiento se realizó en un entorno flexible y acelerado por GPU, mientras que la ejecución final se integró a la arquitectura del vehículo mediante un servicio externo en Python.

### 3.1 Objetivo del modelo de percepción

El propósito del modelo fue transformar imágenes RGB del entorno virtual en una representación estructurada de objetos detectados. Si se denota una imagen capturada por el vehículo como:

$$
I \in \mathbb{R}^{H \times W \times 3}
$$

entonces el objetivo del detector es estimar un conjunto de objetos:

$$
\mathcal{D} = \{d_1, d_2, \dots, d_n\}
$$

donde cada detección queda descrita por una clase, una confianza y una caja delimitadora:

$$
d_i = (c_i,\ \rho_i,\ x_{1,i},\ y_{1,i},\ x_{2,i},\ y_{2,i})
$$

Aquí:

- $c_i$ es la clase detectada,
- $\rho_i$ es la probabilidad o confianza del modelo,
- $(x_{1,i}, y_{1,i})$ y $(x_{2,i}, y_{2,i})$ son las coordenadas del bounding box.

Esta estructura constituye la base del resto del pipeline, ya que posteriormente será enriquecida con profundidad y utilizada por la lógica de decisión del vehículo.

### 3.2 Verificación del entorno de cómputo

Antes de entrenar el modelo, fue necesario verificar que el entorno de Colab tuviera acceso a GPU. Para ello se utilizó el siguiente código:

```python
import torch
print(torch.cuda.is_available())  # Debe imprimir True
print(torch.cuda.device_count())  # Debe imprimir 1 o más
```

Esta verificación es importante porque el entrenamiento de un detector convolucional sobre varias épocas y con imágenes de resolución moderada requiere recursos computacionales significativos. El uso de GPU permite reducir drásticamente el tiempo de entrenamiento y hace factible iterar sobre el modelo dentro de un flujo de trabajo práctico.

### 3.3 Instalación de la librería Ultralytics y revisión del entorno

```python
!pip install ultralytics

import ultralytics
ultralytics.checks()
```

En esta parte se instala la librería `ultralytics`, que proporciona la implementación de YOLOv8 utilizada en el proyecto. La llamada `ultralytics.checks()` verifica que el entorno de ejecución sea consistente y que las dependencias necesarias estén correctamente configuradas. Esto incluye validaciones relacionadas con PyTorch, CUDA, memoria y entorno general de ejecución.

### 3.4 Carga y preparación del dataset

```python
from google.colab import files
uploaded = files.upload()

!unzip detection_2025.v8i.yolov8.zip

!ls
!ls valid
!ls test
!ls train
```

En esta etapa se sube y descomprime el dataset de entrenamiento. La organización del conjunto de datos en carpetas `train`, `valid` y `test` sigue una metodología estándar en aprendizaje supervisado:

- `train`: conjunto usado para ajustar los parámetros del modelo
- `valid`: conjunto usado para monitorear el desempeño durante el entrenamiento
- `test`: conjunto usado para evaluar el comportamiento final del modelo sobre datos no vistos

Esta separación permite reducir el riesgo de sobreajuste y da una base más sólida para evaluar si el detector realmente generaliza a nuevas imágenes del entorno.

### 3.5 Entrenamiento del modelo

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

Aquí se define el modelo base usando el checkpoint preentrenado `yolov8s.pt`. La elección de esta variante responde a un compromiso entre capacidad de representación y costo computacional. Un modelo demasiado pequeño podría no detectar bien señales u objetos pequeños; uno demasiado grande podría ser más costoso de entrenar y menos práctico de desplegar.

Los parámetros principales del entrenamiento fueron:

- `epochs=150`: número de épocas de optimización
- `imgsz=640`: tamaño de entrada de la imagen
- `batch=32`: tamaño del lote de entrenamiento

Desde una perspectiva matemática, el entrenamiento busca resolver un problema de minimización de pérdida:

$$
\theta^\star = \arg\min_{\theta} \mathcal{L}(\theta)
$$

donde $\theta$ representa los parámetros del modelo y $\mathcal{L}$ la función de pérdida total del detector. En YOLO, esta pérdida combina típicamente errores de clasificación, localización de bounding boxes y confianza de detección.

El archivo `data.yaml` contiene la definición del dataset, incluyendo clases y rutas de acceso a los subconjuntos correspondientes. Esto es esencial para que el modelo conozca la estructura del problema de clasificación/detección que debe aprender.

### 3.6 Exportación a ONNX

```python
model.export(format="onnx", opset=12)
```

Una vez entrenado el modelo, se exportó a formato ONNX. Esta decisión fue muy importante desde el punto de vista de integración. Aunque el entrenamiento se realizó en Colab, la inferencia debía ejecutarse posteriormente dentro de una arquitectura conectada con Simulink. ONNX proporciona un formato interoperable que facilita el despliegue del modelo fuera del entorno original de entrenamiento.

En otras palabras, el flujo completo fue:

$$
\text{Entrenamiento en Colab} \rightarrow \text{Modelo } .pt \rightarrow \text{Exportación a ONNX} \rightarrow \text{Inferencia conectada con Simulink}
$$

### 3.7 Validación cuantitativa del modelo

```python
model = YOLO("runs/detect/train/weights/best.pt")
metrics = model.val(data="data.yaml")
print("mAP@50:", metrics.box.map50)
print("mAP@50-95:", metrics.box.map)
print("Precision:", metrics.box.mp)
print("Recall:", metrics.box.mr)
```

Después del entrenamiento se calcularon métricas estándar para evaluar el desempeño del detector. Si se denotan estas métricas de forma general:

- $\mathrm{mAP}_{50}$: precisión media con IoU = 0.50
- $\mathrm{mAP}_{50:95}$: precisión media sobre múltiples umbrales IoU
- $P$: precisión
- $R$: recall

entonces el módulo de percepción puede evaluarse cuantitativamente mediante:

$$
P = \frac{TP}{TP + FP}
$$

$$
R = \frac{TP}{TP + FN}
$$

donde:

- $TP$: verdaderos positivos
- $FP$: falsos positivos
- $FN$: falsos negativos

La métrica $\mathrm{mAP}_{50}$ evalúa la precisión media cuando una detección se considera correcta si su intersección sobre unión supera 0.50. La métrica $\mathrm{mAP}_{50:95}$ es más exigente porque promedia el desempeño sobre varios umbrales de IoU, proporcionando una evaluación más robusta de la calidad del detector.

### 3.8 Prueba cualitativa del modelo exportado

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

Esta prueba permitió verificar que el modelo exportado a ONNX seguía funcionando correctamente antes de integrarlo con Simulink. Este paso es importante porque un modelo puede comportarse adecuadamente en su formato de entrenamiento original y presentar diferencias inesperadas al convertirse a otro formato. Validar el modelo exportado reduce ese riesgo y aporta confianza al proceso de despliegue.

---

## 4. Comunicación bidireccional entre Simulink y Python

Una vez entrenado el modelo, fue necesario integrarlo al pipeline de self-driving. Para ello se desarrolló un script en Python que se comunica con Simulink mediante sockets TCP. El sistema es bidireccional: Simulink envía frames al script, y el script devuelve una lista estructurada de detecciones.

La importancia de este módulo radica en que sirve como puente entre dos entornos complementarios:

- **Simulink**, que se utiliza como núcleo del sistema de control y decisión
- **Python**, que se utiliza como entorno de inferencia para el modelo ONNX

De esta manera, la arquitectura aprovecha lo mejor de ambos mundos sin perder modularidad.

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

lo cual corresponde a una imagen RGB de resolución 640 por 480. El socket principal queda encargado de recibir desde Simulink un flujo continuo de bytes correspondiente a cada frame.

La variable `latest_frame` se usa como buffer compartido entre hilos, mientras que `running` funciona como bandera global de ejecución.

### 4.2 Creación del canal de retorno

```python
send_socket = socket.socket()
send_socket.bind(("localhost", 18001))
send_socket.listen(1)

print("Esperando conexión de Simulink (retorno)...")
conn_send, addr_send = send_socket.accept()
print("Simulink conectado para retorno:", addr_send)
```

Aquí se crea un segundo canal independiente, dedicado a devolver resultados a Simulink. Esta separación entre canal de entrada y canal de salida simplifica la arquitectura de comunicación y evita ambigüedades en el flujo de datos.

En términos de sistema, la estructura queda así:

$$
\text{Simulink} \xrightarrow[\text{frames}]{18002} \text{Python} \xrightarrow[\text{detecciones}]{18001} \text{Simulink}
$$

### 4.3 Carga del modelo de inferencia

```python
print("Importando YOLO...")
from ultralytics import YOLO

print("Cargando modelo...")
model = YOLO(r"C:\Users\desqu\OneDrive\Desktop\decimo semestre\sins autonomos\best2.onnx", task="detect")
print("Modelo cargado")
```

En esta etapa se carga el modelo ONNX previamente exportado. La instrucción `task="detect"` deja explícito que el modelo se utilizará para tareas de detección de objetos. Una vez cargado, el modelo puede aplicarse a cada frame recibido desde Simulink.

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

Este hilo se encarga de reconstruir cada imagen a partir del flujo de bytes recibido. Hay dos detalles técnicos particularmente importantes aquí.

El primero es la acumulación de bytes hasta alcanzar el tamaño completo esperado del frame. Esto evita procesar imágenes incompletas.

El segundo es el uso de:

```python
order='F'
```

al hacer `reshape`. Esto es crucial porque MATLAB/Simulink trabaja con almacenamiento en orden de columnas, mientras que NumPy suele asumir orden por filas. Al usar `order='F'`, el frame se reconstruye respetando la forma en que Simulink lo envió, evitando distorsiones o reordenamientos incorrectos de la imagen.

Posteriormente, el frame se convierte de RGB a BGR para compatibilidad con OpenCV y con la rutina de visualización.

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

Este hilo toma el frame más reciente y ejecuta la inferencia sobre él. El resultado del detector se convierte a una estructura fija con capacidad para hasta 10 detecciones por frame:

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

Cada fila de la matriz `output` representa una detección, y la matriz completa tiene dimensiones:

$$
10 \times 6
$$

Este diseño es importante porque impone una interfaz de comunicación estable entre Python y Simulink. Aun cuando un frame tenga menos de 10 detecciones, la salida conserva siempre la misma forma, lo cual simplifica enormemente su procesamiento posterior dentro del modelo.

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

La ejecución se divide en dos hilos:

- `t1`: recepción continua de imágenes
- `t2`: inferencia continua y retorno de resultados

Esta estructura concurrente permite desacoplar la llegada de frames del tiempo de ejecución de la red neuronal. En vez de bloquear todo el sistema mientras un frame se procesa, el módulo mantiene una arquitectura más fluida y cercana al comportamiento esperado en tiempo real.

## Papel de esta sección dentro del sistema completo

Esta sección representa la capa de percepción del sistema de self-driving. El entrenamiento del detector proporciona la capacidad de reconocer objetos relevantes del entorno, mientras que la comunicación Simulink–Python permite integrar esa capacidad dentro de la arquitectura del vehículo.

En conjunto, este módulo transforma una imagen cruda del entorno en un conjunto estructurado de detecciones que luego será usado por las funciones de profundidad y de decisión. Por tanto, actúa como el punto de entrada del conocimiento visual del sistema y constituye una pieza esencial para que el vehículo deje de ser un simple seguidor de trayectoria y se convierta en un agente capaz de interpretar el entorno en el que circula.