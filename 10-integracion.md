---
layout: default
title: Explicación de Simulink
nav_order: 8
parent: CPS IoT Competition 2026
permalink: /CPS/Simulink/
---

## Arquitectura general del sistema en Simulink

La arquitectura implementada en Simulink fue organizada en módulos funcionales claramente diferenciados, de manera que cada bloque se encargara de una tarea específica dentro del pipeline de conducción autónoma del QCar 2 virtual. Esta organización modular permite separar la adquisición de sensores, la estimación del estado, la planeación de trayectoria, el control longitudinal y lateral, la percepción visual con inferencia externa en Python, la lógica de tránsito y la escritura final de comandos al vehículo. Desde una perspectiva de ingeniería, esta estructura es importante porque facilita la validación individual de cada subsistema y permite integrar nuevas funciones sin alterar por completo el comportamiento global del modelo.

En términos generales, el flujo del sistema puede interpretarse como una cadena de procesamiento donde primero se adquieren datos del vehículo y del entorno, luego se estima la pose actual, posteriormente se selecciona una referencia de trayectoria y se calculan los comandos de velocidad y dirección, después se analizan eventos visuales del entorno mediante la red neuronal y finalmente se aplican decisiones de tránsito y señales luminosas antes de enviar los actuadores al QCar.

---

## 1. Bloque de lectura de sensores

![Bloque Read Sensors](sandbox:/mnt/data/BloqueReadSensor.png)

**Figura.** Subsistema `Read Sensors` donde se leen las señales internas del QCar, como velocidad, aceleración y giroscopio.

El bloque `readQCarDAC` concentra la adquisición de variables internas del vehículo. Entre sus salidas más importantes se encuentran la velocidad medida (`measuredSpeed`), el acelerómetro (`accel`) y el giroscopio (`gyro`), las cuales son esenciales para el control y la estimación del estado. Además, este bloque también entrega otras señales de monitoreo, como odómetro, voltaje de batería, corriente del motor, nivel de batería, potencia del motor y componente `gyro_z`. Aunque no todas estas variables se usan directamente en la lógica principal de navegación, sí forman parte de la instrumentación del sistema y permiten monitorear el comportamiento general del vehículo dentro de la simulación.

Desde el punto de vista de arquitectura, este bloque representa la interfaz entre la planta simulada y el resto del controlador. Es decir, aquí se obtiene la información dinámica básica del QCar que después será utilizada por el bloque de estimación de estado y por el control longitudinal.

---

![Bloque Read Sensors - LiDAR y RealSense](sandbox:/mnt/data/BloqueReadSensor1.png)

**Figura.** Subsistema complementario de lectura de sensores, donde se capturan los datos del LiDAR y de la cámara RealSense.

En esta parte del subsistema aparecen dos bloques fundamentales: `lidarCapture` y `realsenseCapture`. El bloque `lidarCapture` entrega las distancias medidas por el LiDAR, los ángulos asociados a cada medición y una bandera llamada `newLidarReading`, que indica cuándo existe una nueva lectura disponible. Esta bandera es importante porque permite sincronizar la actualización de la pose estimada únicamente cuando llega información nueva del sensor.

Por su parte, el bloque `realsenseCapture` proporciona dos salidas críticas para el módulo de percepción: la imagen de profundidad (`realsenseDepthImage`) y la imagen RGB (`realsenseRGBImage`), junto con las banderas `newDepthImage` y `newRGBImage`. Estas señales son esenciales porque la imagen RGB se emplea para la detección de objetos con la red neuronal, mientras que la imagen de profundidad se usa después para calcular la distancia asociada a cada detección.

---

## 2. Bloque de estimación de estado

![Bloque stateEstimation](sandbox:/mnt/data/BloqueProcessing2.png)

**Figura.** Bloque `stateEstimation`, encargado de calcular la pose actual del QCar a partir de sensores y comandos del vehículo.

El bloque `stateEstimation` recibe como entradas la pose proveniente del LiDAR (`lidarPose`), el giroscopio, la bandera `newLidarReading`, la velocidad del vehículo y el comando de dirección. Con estas señales, el bloque estima la pose actual del carro, expresada como posición en \(x\), posición en \(y\) y orientación \(\theta\). Esta salida aparece etiquetada como `currentPose [x,y,heading] (m,m,rad)`.

La importancia de este bloque es muy alta dentro del sistema, ya que la pose estimada es la variable que le permite al algoritmo saber dónde se encuentra el vehículo dentro del mapa. A partir de esta pose trabajan el planeador de trayectoria, el controlador lateral y también la lógica de luces. En otras palabras, este bloque actúa como el puente entre las mediciones sensoriales y la representación geométrica del vehículo dentro del entorno.

---

## 3. Bloques de planeación y control lateral

![Bloques pathPlanner y steeringCommander](sandbox:/mnt/data/BloqueProcessing1.png)

**Figura.** Subsistema de procesamiento lateral compuesto por los bloques `pathPlanner` y `steeringCommander`.

El bloque `pathPlanner`, que aparece en color naranja, recibe la pose actual del vehículo y la velocidad deseada o ajustada, además de una distancia de anticipación llamada `lookAheadDistance`. A partir de estas entradas, produce como salidas la trayectoria deseada (`desiredPath`), el punto actual sobre la ruta (`currentPathXY`), el punto objetivo o siguiente referencia (`desiredPathXY`) y la distancia entre el vehículo y la trayectoria (`distanceToPath`). Este bloque funciona como la capa de navegación local sobre la trayectoria global, ya que decide qué parte del camino debe seguir el coche en el instante actual.

Encima de él se encuentra el bloque `steeringCommander`, encargado del control lateral. Este bloque utiliza como entradas la razón de giro (`yawRate`), el identificador de la trayectoria deseada, la velocidad ajustada, la pose actual, la distancia al camino y las coordenadas actuales y deseadas sobre la ruta. A partir de ello calcula el comando final de dirección (`steeringCmd`). En términos funcionales, este bloque convierte la información geométrica del error lateral y del estado del vehículo en una señal de dirección que permite seguir la trayectoria de forma estable.

Desde una perspectiva de control, ambos bloques trabajan en conjunto: el `pathPlanner` decide **qué punto de la ruta debe seguirse**, mientras que el `steeringCommander` decide **cómo orientar el vehículo para alcanzarlo**.

---

## 4. Bloque de control longitudinal

![Bloque speedController](sandbox:/mnt/data/BloqueProcessing.png)

**Figura.** Bloque `speedController`, responsable del control de velocidad del QCar.

El bloque `speedController` recibe la velocidad objetivo, el comando de dirección, la velocidad actual medida, la distancia a un obstáculo y una bandera de habilitación del QCar. A partir de estas entradas genera dos salidas principales: el comando PWM que se aplicará al motor (`pwmCmd`) y una velocidad ajustada llamada `tunedSpeedCmd`.

La lógica de este bloque consiste en transformar una velocidad deseada en una orden longitudinal físicamente aplicable al vehículo. Sin embargo, su papel no se limita a ser un simple conversor de velocidad a PWM. También incorpora el contexto del entorno a través de la distancia al obstáculo y produce una velocidad ajustada que posteriormente será utilizada por el planeador y por la lógica de tránsito. Esto significa que este bloque no solo controla la velocidad, sino que además la adapta a la situación actual del vehículo dentro del escenario.

---

## 5. Bloque de inferencia visual y comunicación con Python

![Bloque de inferencia en Simulink](sandbox:/mnt/data/BloqueSimulink3.png)

**Figura.** Subsistema de comunicación entre Simulink y Python para ejecutar la inferencia del modelo de detección y construir la matriz final de objetos con profundidad.

En la parte izquierda de este subsistema se recibe la señal `realsenseRGBImage`, que corresponde al frame RGB capturado por la cámara. De acuerdo con tu explicación, primero esta imagen pasa por un bloque de conversión de tipo de dato para asegurarse de que esté en formato `uint8`, y posteriormente por un bloque `reshape` que la transforma en un vector fila. Esto se hace con el objetivo de empaquetar el frame y enviarlo por TCP/IP al script de Python que ejecuta la red neuronal. El bloque `Model_Input_Stream` funciona como cliente TCP/IP en modo emisor y, según tus transcripciones, se configuró en la dirección `tcpip://localhost:18002`, con un tamaño amplio de buffer para que los frames no llegaran cortados y con tiempo de muestreo igual al de la cámara. :contentReference[oaicite:4]{index=4}

El segundo bloque de comunicación es `InferenceDecoder`, que opera en modo receptor y se conecta al puerto `18001`. Su función es recibir desde Python la salida del modelo de inferencia, es decir, la lista de objetos detectados con sus seis atributos: identificador de clase, probabilidad, \(x_1\), \(y_1\), \(x_2\) y \(y_2\). Esa información llega como un vector fijo de 60 elementos y después se reorganiza con un `reshape` a una matriz de 6×10, donde cada columna representa un objeto detectado. Elegir un tamaño fijo de 6×10 fue una decisión muy importante, porque simplifica el manejo en Simulink y evita el uso de matrices dinámicas. Si hay menos de diez objetos, el resto de las columnas se rellena con ceros. :contentReference[oaicite:5]{index=5}

A la derecha aparece el bloque `BuildDetectionMatrix`, que utiliza internamente la función `addDepth`. La finalidad de este bloque es tomar la matriz de detecciones 6×10 y agregar una séptima fila que representa la distancia estimada del objeto. Para ello, usa las coordenadas del bounding box \((x_1,y_1,x_2,y_2)\) y calcula una región de interés dentro del frame de profundidad (`realsenseDepthImage`). A partir de esa región obtiene la distancia asociada al objeto detectado. El resultado final es una matriz 7×10, que ya no solo contiene información visual, sino también contenido geométrico. Esa matriz enriquecida es la que alimenta después los bloques de lógica de tránsito, evasión de obstáculos y frenado peatonal. :contentReference[oaicite:6]{index=6} :contentReference[oaicite:7]{index=7}

En la parte inferior de este mismo subsistema se encuentra la lógica de frenado peatonal, a la que te refieres como `AEB Pedestrian Logic`. Según tu explicación, este bloque recibe la matriz 7×10 y la imagen de profundidad, y su función es distinguir si el objeto que aparece delante del coche corresponde a una persona o a un cono. Si es un cono, entonces no se frena sino que se activa la lógica de evasión; si es una persona, el bloque debe emitir una bandera de paro que será utilizada posteriormente por la lógica de tránsito. También explicas que en ese momento esta parte todavía estaba en ajuste fino, porque el objetivo era evitar que el vehículo atropellara al peatón dentro de la simulación. :contentReference[oaicite:8]{index=8}

---

## 6. Lógica de tránsito y toma de decisiones

La función `traffic signal logic` es la capa principal de decisión reglamentaria del sistema. Según tus transcripciones, esta función recibe la matriz de detecciones 7×10, la velocidad calculada por el controlador y un reloj de simulación, además de la bandera `pedestrian_flag`. El reloj se utiliza para medir cuánto tiempo ha transcurrido desde que se detectó un evento, como un STOP o un YIELD, y así poder implementar detenciones temporales reales dentro de la simulación. :contentReference[oaicite:9]{index=9}

Internamente, la función declara variables persistentes para manejar estados asociados a STOP, YIELD y glorieta. Después recorre la matriz de detecciones y valida, para cada objeto, su clase, probabilidad, distancia y si está siendo observado de frente. Por ejemplo, cuando la clase detectada corresponde a una señal de STOP, la probabilidad es suficientemente alta, la distancia es pequeña y el objeto está frontal al vehículo, entonces activa la lógica de parada. Lo mismo ocurre con YIELD, mientras que para glorieta lo que haces es reducir la velocidad multiplicándola por un factor menor, para que el vehículo entre más lento. También mencionas que para los semáforos implementaste una especie de persistencia o distancia de compromiso: si el coche ya vio verde y ya se comprometió a cruzar, entonces sigue avanzando aunque después aparezca amarillo o rojo, evitando quedarse detenido a mitad de la intersección. :contentReference[oaicite:10]{index=10}

Otro aspecto importante que explicas es que esta función opera como un bloque de *switching* de velocidad. Es decir, normalmente deja pasar la velocidad que viene del controlador longitudinal, pero si detecta una condición que obliga a detenerse, conmutas esa señal por un cero. Una vez que pasa el tiempo de espera o deja de existir la condición, vuelves a conmutar a la velocidad del controlador. También mencionas que, como no se dispone de cámaras laterales, para simular la recolección de un peatón haces una aproximación temporal: cuando lo detectas a cierta distancia, comienzas a contar un tiempo y luego ordenas la detención, de forma que el coche se frene aproximadamente al lado del pasajero y no exactamente enfrente. :contentReference[oaicite:11]{index=11}

Además de esta lógica, también cuentas con el bloque `avoid cone`, al que le envías la misma matriz de detección, el reloj de simulación y el `steering` calculado por el controlador. Cuando se detecta un cono, la dirección calculada por el control lateral se conmuta por una trayectoria de evasión suave, que describes como una señal sigmoidal para que el esquive no sea brusco. Si no hay cono, la dirección de entrada simplemente se conserva. También señalas que la evasión del cono se hace siempre por la izquierda, siguiendo la lógica de rebase por ese lado, y que de este bloque sale una bandera `direction` que más adelante usa el sistema de luces. :contentReference[oaicite:12]{index=12}

---

## 7. Bloque de escritura al QCar y actuación final

![Bloque writeToQCarDAC](sandbox:/mnt/data/BloqueWriteToCar.png)

**Figura.** Bloque `writeToQCarDAC`, encargado de aplicar al vehículo los comandos de motor, dirección y señales luminosas.

El bloque `writeToQCarDAC` es el último eslabón de la cadena de control. Recibe como entradas el comando del motor (`motor_cmd`), el comando de dirección (`steering_cmd`), el vector de LEDs (`leds`) y la tira RGB (`ledStrip`). Esto significa que aquí convergen tanto las decisiones puramente dinámicas del vehículo como la lógica luminosa asociada a freno y direccionales.

De acuerdo con tu transcripción, la tira RGB y las señales de luz son generadas por un bloque `light controller`, al que le pasas la pose actual del vehículo, el PWM, un generador de pulsos para hacer parpadear las direccionales, la trayectoria suavizada, los segmentos donde deben prenderse las luces izquierda y derecha, el flag `avoid` de evasión de cono y el `stop_light` proveniente de la lógica de tránsito. La idea central de ese bloque es que las luces se activen ya sea por **eventos** —como un STOP, la recogida de una persona o la evasión de un cono— o por **segmentos específicos de la trayectoria**, es decir, zonas donde el coche ya sabe que debe indicar una maniobra hacia izquierda o derecha. También explicas que el generador de pulsos se multiplica por las banderas de señal izquierda o derecha para crear el efecto de parpadeo real, y que cuando el coche está frenado o el PWM es cero, se enciende la lógica de freno sobre la tira de luces. :contentReference[oaicite:13]{index=13}

Desde el punto de vista funcional, este bloque representa la interfaz final entre el controlador y la planta. Aquí es donde todas las decisiones tomadas a lo largo del pipeline se convierten en acciones reales sobre el QCar: avanzar, girar, frenar o encender las señales luminosas correspondientes.

---

## Interpretación global de la arquitectura

En conjunto, la arquitectura construida en Simulink puede interpretarse como un sistema jerárquico donde cada bloque cumple una función bien definida. Los sensores entregan información del vehículo y del entorno; la estimación de estado calcula la pose actual; el planeador y el controlador lateral determinan cómo seguir la trayectoria; el controlador de velocidad ajusta la marcha longitudinal; el módulo de percepción detecta objetos mediante la red neuronal y les añade profundidad; la lógica de tránsito decide si debe detenerse, reducir velocidad o continuar; la función de evasión modifica la dirección si aparece un cono; el controlador de luces expresa visualmente las maniobras y eventos del vehículo; y, por último, el bloque de escritura aplica todo ello sobre el QCar. Esta organización modular permite que el sistema no sea un simple seguidor de trayectoria, sino una arquitectura completa de self-driving capaz de percibir, decidir y actuar de forma integrada.