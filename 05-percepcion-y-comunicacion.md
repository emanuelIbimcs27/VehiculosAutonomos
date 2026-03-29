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

La métrica $mAP_{50}$ evalúa la precisión media cuando una detección se considera correcta si su intersección sobre unión supera 0.50. La métrica $mAP_{50\text{-}95}$ es más exigente porque promedia el desempeño sobre varios umbrales de IoU, proporcionando una evaluación más robusta de la calidad del detector.

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
## Análisis del desempeño del modelo de detección entrenado

Las métricas obtenidas durante la etapa de validación muestran que el modelo de detección alcanzó un desempeño sólido y adecuado para su integración dentro del pipeline de conducción autónoma. En la evaluación global sobre **504 imágenes** y **968 instancias**, el modelo obtuvo una **precisión de 0.9119**, un **recall de 0.9338**, un **mAP@50 de 0.9605** y un **mAP@50-95 de 0.7938**. Estos resultados indican que el detector no solo identifica correctamente la mayoría de los objetos presentes en el escenario, sino que además mantiene una calidad alta en la localización de las cajas delimitadoras. Desde una perspectiva ingenieril, estos valores son consistentes con un detector confiable para tareas de percepción en un entorno controlado como Quanser City, especialmente considerando que el sistema no se apoya únicamente en clasificación visual, sino también en profundidad y lógica posterior de decisión.

El valor de **mAP@50 = 0.9605** indica que, bajo un criterio de intersección sobre unión relativamente flexible, el modelo logra detectar correctamente casi todos los objetos relevantes del entorno. Esto significa que para el problema práctico del self-driving en simulación, donde el interés principal es reconocer señales, semáforos, peatones y conos con suficiente anticipación, el modelo ofrece una tasa de detección muy alta. Por otro lado, el valor de **mAP@50-95 = 0.7938** muestra que, al exigir mayor precisión geométrica en la superposición de las cajas, el desempeño disminuye, pero se mantiene en un rango bueno. Esta diferencia entre ambas métricas es completamente esperable y su interpretación es importante: el modelo reconoce muy bien la presencia de los objetos, aunque la delimitación exacta de sus contornos todavía presenta una variación moderada cuando el criterio de IoU se vuelve más estricto.

El análisis por clase también permite entender mejor el comportamiento del modelo. Las categorías con mejor desempeño fueron **yield**, **red**, **round**, **stop** y **yellow**, todas con valores de **mAP@50** superiores a 0.97 o muy cercanos a ello. Esto sugiere que los elementos de señalización vial y semáforos fueron aprendidos de forma particularmente robusta, lo cual es una excelente señal para la arquitectura propuesta, ya que precisamente esos objetos constituyen la base de la lógica reglamentaria del vehículo. En particular, la clase **yield** alcanzó un **mAP@50 de 0.987** y un **mAP@50-95 de 0.828**, mostrando un reconocimiento muy consistente tanto a nivel de presencia como de localización. Asimismo, la clase **red** obtuvo un **mAP@50 de 0.981** y **mAP@50-95 de 0.873**, reflejando una detección especialmente fuerte de la luz roja, que es crítica para la seguridad del sistema.

La clase **green** mostró un comportamiento interesante: alcanzó un **recall de 1.0**, lo que significa que el modelo fue capaz de recuperar todos los ejemplos presentes en validación, aunque con una **precisión de 0.861**, menor que la de otras clases. Esto sugiere que el detector fue muy sensible a la presencia del semáforo en verde, pero generó algunos falsos positivos adicionales. Desde el punto de vista funcional, esto puede interpretarse como una tendencia conservadora hacia no perder ejemplos verdaderos de luz verde, aunque todavía con cierta confusión en algunos casos. En contraste, la clase **yellow** mostró una **precisión de 0.969** y un **recall de 0.957**, lo cual indica un equilibrio muy bueno entre detección correcta y baja tasa de falsas alarmas.

La clase con desempeño relativamente más débil fue **person**, con una **precisión de 0.831**, un **recall de 0.750**, un **mAP@50 de 0.898** y un **mAP@50-95 de 0.658**. Aunque sigue siendo un resultado útil, sí marca claramente que la detección de personas es el punto menos robusto del modelo comparado con las señales y semáforos. Esto tiene una explicación razonable: en general, la clase persona presenta más variabilidad en postura, tamaño aparente, orientación y oclusión parcial que una señal rígida o una luz de semáforo. Además, dentro del entorno de simulación, el peatón puede ocupar una porción relativamente pequeña del campo visual dependiendo de su distancia al vehículo. Precisamente por esta razón fue acertado reforzar la arquitectura con una función adicional de seguridad basada en profundidad, en lugar de depender únicamente de la clasificación visual de peatones.

Desde el punto de vista temporal, el reporte de validación también muestra un desempeño de inferencia muy favorable. El modelo presentó aproximadamente **1.3 ms de preprocesamiento**, **6.9 ms de inferencia** y **1.3 ms de postprocesamiento** por imagen. Esto corresponde a un tiempo total cercano a **9.5 ms por frame**, lo que equivale teóricamente a un procesamiento del orden de **más de 100 imágenes por segundo** en la GPU Tesla T4 utilizada durante la validación. Aunque este valor no debe interpretarse de forma idéntica al desempeño final dentro del sistema completo —ya que en la implementación real también intervienen transferencia de imágenes, sockets, Simulink y lógica adicional— sí demuestra que el detector por sí mismo tiene una latencia suficientemente baja como para ser incorporado a un pipeline casi en tiempo real.

### Interpretación de las curvas de entrenamiento y validación

Las gráficas de entrenamiento muestran un comportamiento consistente con una convergencia saludable del modelo. En la parte superior se observa que las pérdidas de entrenamiento **train/box_loss**, **train/cls_loss** y **train/dfl_loss** descienden de manera sostenida a lo largo de las épocas. La reducción de **box_loss** indica que la red fue aprendiendo a ajustar mejor las cajas delimitadoras sobre los objetos; la caída de **cls_loss** muestra que mejoró la discriminación entre clases; y la disminución de **dfl_loss** confirma una mejor precisión en la regresión de bordes, aspecto especialmente importante en YOLOv8. El hecho de que estas tres curvas bajen sin oscilaciones severas ni divergencias es una evidencia clara de que el proceso de optimización fue estable.

Las curvas de validación refuerzan esta interpretación. Las métricas **val/box_loss**, **val/cls_loss** y **val/dfl_loss** también descienden de manera sostenida, lo cual indica que la mejora observada durante el entrenamiento sí se transfirió a datos no vistos. Esto es un punto crucial, porque si las pérdidas de entrenamiento bajaran pero las de validación permanecieran altas o aumentaran, existiría evidencia de sobreajuste. Aquí ocurre lo contrario: ambas familias de curvas siguen una tendencia coherente, lo cual sugiere una buena capacidad de generalización del modelo sobre el conjunto de validación.

En las gráficas de desempeño se observa además que **precision(B)** crece gradualmente hasta estabilizarse alrededor de 0.91–0.92, mientras que **recall(B)** se mantiene alto, en torno a 0.93–0.95, con ligeras fluctuaciones normales durante el entrenamiento. De forma paralela, **mAP50(B)** aumenta rápidamente durante las primeras épocas y luego entra en una zona de saturación cercana a 0.96, mientras que **mAP50-95(B)** también crece de manera progresiva hasta estabilizarse alrededor de 0.79. Esta forma de las curvas sugiere que el modelo ya había capturado la mayor parte de la estructura del problema desde etapas intermedias del entrenamiento, y que las épocas posteriores sirvieron principalmente para refinar la localización de los objetos y consolidar el rendimiento final.

En conjunto, estas curvas permiten concluir que el entrenamiento fue exitoso, que la red alcanzó convergencia sin signos severos de sobreajuste y que el modelo obtenido posee un nivel de desempeño suficientemente alto para soportar las decisiones posteriores del vehículo autónomo.

### Figura de métricas finales del modelo

![Resultados de validación del modelo](/assets/img/Entrenamiento.jpeg)

**Figura.** Resultados de validación del modelo YOLOv8 utilizado para detectar objetos del entorno de Quanser City. En la evaluación global se obtuvo una precisión de 0.9119, un recall de 0.9338, un mAP@50 de 0.9605 y un mAP@50-95 de 0.7938. Estos resultados muestran que el detector reconoce de forma confiable la mayor parte de los objetos relevantes del escenario y que su desempeño es suficientemente robusto para integrarse al pipeline de conducción autónoma.

### Figura de curvas de entrenamiento

![Curvas de entrenamiento del modelo](/assets/img/MetricasEntre.jpeg)

**Figura.** Evolución de las pérdidas de entrenamiento y de las métricas de precisión y recall durante el proceso de optimización. Se observa una disminución sostenida de las funciones de pérdida y un incremento progresivo en precisión y recall, lo que evidencia un entrenamiento estable y una convergencia adecuada del modelo.

### Figura de curvas de validación

![Curvas de validación del modelo](/assets/img/MetricasEntre2.jpeg)

**Figura.** Evolución de las pérdidas de validación y de las métricas mAP@50 y mAP@50-95. La tendencia descendente de las pérdidas y el crecimiento sostenido de las métricas de desempeño indican que el modelo generaliza adecuadamente sobre datos no vistos y que no presenta señales severas de sobreajuste.

---

## Análisis del seccionamiento de la ruta para activación de direccionales

La ruta generada para el QCar 2 virtual no solo fue utilizada como referencia geométrica de navegación, sino también como base para definir comportamientos viales adicionales, en particular la activación de direccionales. Para ello, después de calcular la trayectoria global suavizada, se realizó un seccionamiento del camino con el fin de identificar en qué tramos concretos debía encenderse la direccional izquierda y en cuáles la derecha. Esto permitió que el vehículo no se limitara a seguir una curva, sino que además expresara visualmente sus maniobras conforme a reglas de conducción más realistas.

La primera imagen de trayectoria muestra el camino global final del vehículo dentro del mapa. En ella se observa la ruta en rojo recorriendo el entorno delimitado por el contorno punteado negro. Esta figura valida que el algoritmo de planeación, basado en grafo y suavizado posterior, logró generar una referencia continua y físicamente consistente con la geometría del circuito. La trayectoria recorre tanto la periferia como la parte interna del escenario, conectando de manera suave distintos tramos rectos y curvos. Desde una perspectiva de navegación, esta figura representa el camino nominal que seguiría el vehículo en ausencia de eventos que alteren su comportamiento, como señales, peatones u obstáculos.

### Figura de trayectoria global generada

![Trayectoria global del vehículo](/assets/img/MapaVirtualGenerado.jpeg)

**Figura.** Trayectoria global final del QCar 2 virtual obtenida a partir del grafo del mapa, el cálculo de camino mínimo y el suavizado mediante interpolación PCHIP. La curva roja representa la referencia nominal que seguirá el vehículo dentro del entorno virtual.

La segunda figura corresponde al seccionamiento de esa misma trayectoria para la lógica de direccionales. En ella, la ruta completa se muestra en color negro, mientras que los tramos donde debe activarse la direccional izquierda aparecen en verde y los tramos donde debe activarse la direccional derecha aparecen en rojo. Esta visualización es especialmente valiosa porque confirma que las reglas definidas sobre pares de nodos fueron correctamente proyectadas sobre índices reales de la trayectoria suavizada. Es decir, el sistema no activa las direccionales únicamente en un punto discreto, sino a lo largo de intervalos continuos del camino, lo que hace el comportamiento mucho más natural y consistente con una maniobra vehicular real.

Desde el punto de vista ingenieril, este seccionamiento tiene una interpretación muy clara. La ruta global es una curva continua compuesta por muchos puntos interpolados, mientras que las reglas de direccionales fueron definidas sobre nodos discretos del grafo. Por ello, fue necesario construir un mapeo entre nodos y posiciones efectivas dentro de la trayectoria suavizada. Una vez realizado ese mapeo, cada transición relevante entre nodos pudo traducirse en un segmento concreto del camino. El resultado es precisamente la figura mostrada: una descomposición del trayecto total en subconjuntos donde la lógica de luces puede actuar con precisión temporal y espacial.

La figura también permite validar visualmente que los giros importantes del circuito fueron clasificados de manera coherente. Los segmentos verdes corresponden a maniobras donde el vehículo realiza giros o inserciones asociadas a una lógica de direccional izquierda, mientras que los segmentos rojos representan maniobras equivalentes para la derecha. Lo importante aquí no es únicamente que existan tramos coloreados, sino que esos tramos coinciden con zonas geométricamente congruentes del mapa. En otras palabras, la activación de direccionales no fue arbitraria, sino consistente con la forma de la trayectoria y con la semántica vial previamente definida mediante las reglas nodo a nodo.

Otro punto importante es que el seccionamiento no cubre toda curva presente en el recorrido, sino únicamente aquellas transiciones que fueron definidas como maniobras viales relevantes. Esto significa que el sistema distingue entre curvatura puramente geométrica y giro reglamentario. Esa diferencia es muy importante en un proyecto como este, porque una trayectoria suavizada puede contener variaciones de curvatura que no necesariamente implican una maniobra que amerite encender una direccional. La lógica implementada selecciona solamente aquellos tramos que corresponden a cambios de dirección significativos desde el punto de vista del comportamiento vial.

Además, el uso del nodo auxiliar ubicado en el centro de la intersección permitió modelar mejor ciertos giros izquierdos complejos. Gracias a ello, algunos cambios de dirección que de otra forma se verían como una transición abrupta entre dos nodos extremos pudieron representarse como un arco más natural dentro de la trayectoria. En la práctica, esto mejora tanto la geometría del seguimiento como la coherencia del intervalo donde se activa la direccional. Dicho de otro modo, el nodo auxiliar no solo mejoró la suavidad de la ruta, sino también la calidad semántica del seccionamiento vial.

En términos de validación, la figura de direccionales demuestra tres aspectos importantes. Primero, que el mapeo entre nodos y trayectoria interpolada funciona correctamente. Segundo, que las reglas definidas a nivel topológico realmente se traducen en segmentos físicamente ubicados donde el vehículo ejecuta maniobras consistentes. Y tercero, que el sistema final puede combinar navegación geométrica con comportamiento vial expresivo, lo cual fortalece la presentación del proyecto como una arquitectura de self-driving más completa.

### Figura de seccionamiento de direccionales

![Seccionamiento de la trayectoria para direccionales](/assets/img/MapaVirtualDireccionales.jpeg)

**Figura.** Seccionamiento de la trayectoria para activación de direccionales. La ruta completa se muestra en negro, los segmentos donde debe encenderse la direccional izquierda en verde y los segmentos donde debe encenderse la direccional derecha en rojo. Esta proyección valida la correcta correspondencia entre reglas nodo a nodo y tramos reales de la trayectoria suavizada.