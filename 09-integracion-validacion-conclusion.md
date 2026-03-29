---
layout: default
title: Integración, Validación y Conclusión
nav_order: 7
parent: CPS IoT Competition 2026
permalink: /CPS/integracion-validacion-conclusion/
---

# Integración, Validación y Conclusión

## 12. Integración funcional del sistema completo

Una vez desarrollados e incorporados todos los módulos descritos en las secciones anteriores, el sistema final de self-driving quedó constituido como una arquitectura funcional jerárquica capaz de ejecutar navegación autónoma dentro del entorno virtual de la competencia. Esta integración no consistió únicamente en reunir varios scripts independientes, sino en articular una cadena de procesamiento coherente donde cada bloque aporta una función específica dentro del comportamiento total del vehículo.

Desde el punto de vista ingenieril, el valor de la integración radica en que el sistema ya no debe analizarse por componentes aislados, sino como un flujo continuo de información y decisión. La planeación global aporta la ruta nominal; la percepción visual detecta objetos relevantes del entorno; la estimación de profundidad agrega significado geométrico a esas detecciones; la lógica reglamentaria y de seguridad interpreta el contexto vial; y finalmente el vehículo modifica su velocidad y dirección de acuerdo con todo ese conjunto de información.

En términos generales, la arquitectura integrada puede resumirse como una cadena funcional del tipo:

$$
\text{Mapa} \rightarrow \text{Planeación} \rightarrow \text{Percepción} \rightarrow \text{Profundidad} \rightarrow \text{Decisión} \rightarrow \text{Control}
$$

No obstante, una vez incorporadas las capas avanzadas del proyecto, esta estructura se vuelve todavía más rica, ya que la etapa de decisión no solo considera señales básicas, sino también direccionales, semáforos, peatones, pickup de pasajero y frenado robusto de seguridad.

### 12.1 Integración del pipeline base

El flujo principal del sistema se apoya primero en la trayectoria global calculada sobre el grafo del mapa. Si se denota por $P^\star$ la trayectoria óptima, entonces esta se obtiene resolviendo:

$$
P^\star = \arg\min_{P \in \mathcal{P}(s,g)} \sum_{(i,j)\in P} \left(d_{ij} + p_{ij}\right)
$$

donde:

- $s$ es el nodo inicial,
- $g$ es el nodo objetivo,
- $d_{ij}$ es la distancia geométrica entre nodos,
- $p_{ij}$ es la penalización asociada a complejidad vial.

La salida de este módulo no se utiliza de forma discreta, sino que se suaviza mediante interpolación PCHIP para obtener una referencia continua:

$$
x_s(\tau)=\operatorname{PCHIP}(t_k,x_k), \qquad
y_s(\tau)=\operatorname{PCHIP}(t_k,y_k)
$$

Esta trayectoria suavizada representa el camino nominal que el vehículo debe seguir mientras no exista ningún evento del entorno que obligue a modificarlo.

### 12.2 Integración de la percepción visual con la trayectoria

En paralelo al seguimiento de trayectoria, el sistema recibe imágenes del entorno virtual a través de Simulink y las envía a Python para ejecutar inferencia con el modelo YOLOv8 exportado a ONNX. El detector produce una estructura de hasta diez objetos por frame, cada uno descrito como:

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

Esta representación constituye la salida básica del módulo de percepción. Sin embargo, todavía no resulta suficiente para tomar decisiones de navegación, ya que el vehículo necesita conocer no solo qué objeto está viendo, sino también a qué distancia se encuentra.

Por ello, la salida del detector pasa por la función `addDepth`, donde se convierte en una representación enriquecida:

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

donde $\hat{z}_i$ es la profundidad estimada del objeto. Esta transición es clave porque convierte la percepción visual en percepción espacial operativa.

### 12.3 Integración de la lógica reglamentaria

Una vez que las detecciones han sido enriquecidas con profundidad, el sistema puede aplicar lógica vial sobre ellas. En una primera capa se encuentran funciones como `stopLogic`, encargadas de modificar la velocidad del vehículo ante señales básicas como STOP, YIELD y glorieta.

De forma general, esta etapa puede describirse como una transformación de velocidad nominal:

$$
v_{out}(t) = f(v_{in}(t), \mathbf{o}_i, t)
$$

donde la salida depende tanto del tipo de objeto detectado como de su distancia, posición relativa y contexto temporal. Por ejemplo, la detección de una señal STOP genera una ventana de detención de cinco segundos, mientras que una glorieta provoca únicamente una reducción de velocidad.

Esta lógica constituye la primera capa de interpretación del entorno y permite que el vehículo responda de manera coherente con reglas básicas de tránsito.

### 12.4 Integración de la evasión local de obstáculos

Además de señales, el sistema debe reaccionar ante obstáculos físicos, como el cono colocado en el entorno de la competencia. Para ello, la función `avoidCone` modifica temporalmente la dirección nominal del vehículo mediante una ley senoidal:

$$
\delta_{avoid}(t) = A \sin\left(\frac{2\pi (t-t_0)}{T_{total}}\right)
$$

donde:

- $A$ es la amplitud máxima de giro,
- $T_{total}$ es la duración total de la maniobra,
- $t_0$ es el instante de activación del esquive.

La dirección final queda entonces como:

$$
\delta_{out}(t) =
\begin{cases}
\delta_{avoid}(t), & \text{si la evasión está activa} \\
\delta_{in}(t), & \text{en otro caso}
\end{cases}
$$

Este módulo se integra sobre la trayectoria nominal sin necesidad de recalcular toda la ruta global. En términos de arquitectura, esto es importante porque demuestra que el sistema puede resolver eventos locales de manera reactiva sin comprometer la planeación general.

### 12.5 Integración del comportamiento vial mediante direccionales

Una vez generada la trayectoria global suavizada, también se definieron segmentos específicos donde el vehículo debe encender sus direccionales. Esto se logró proyectando reglas de maniobra entre nodos sobre índices concretos de la trayectoria interpolada.

Si se denota por $\mathcal{P}$ la trayectoria suavizada, entonces los conjuntos:

$$
\mathcal{S}_{izq} = \{[a_1,b_1], [a_2,b_2], \dots\}
$$

$$
\mathcal{S}_{der} = \{[c_1,d_1], [c_2,d_2], \dots\}
$$

representan los intervalos de la trayectoria donde deben activarse las direccionales izquierda y derecha, respectivamente.

Este módulo es importante porque añade una capa de comportamiento vial expresivo al sistema. Es decir, el vehículo no solo sigue una ruta y evita obstáculos, sino que además comunica visualmente sus maniobras de giro conforme a reglas predefinidas sobre la topología del mapa.

### 12.6 Integración del entorno dinámico en QLabs

Todos los módulos anteriores se validan dentro de un entorno programáticamente generado en QLabs. En este entorno se integran:

- el mapa físico del circuito,
- los muros y límites,
- señales de tránsito,
- pasos peatonales,
- semáforos dinámicos,
- una persona estática para simulación de pickup,
- un peatón dinámico cruzando un paso de cebra,
- un cono como obstáculo de competencia.

Esto significa que la arquitectura de self-driving no se evalúa en un mundo abstracto o idealizado, sino en un escenario con eventos dinámicos y señales relevantes que exigen reacción contextual. Desde el punto de vista de validación, este entorno es indispensable porque provee los estímulos físicos sobre los cuales se ponen a prueba los módulos de percepción y decisión.

### 12.7 Integración de la lógica avanzada de tráfico y seguridad

En la etapa final del desarrollo, la lógica básica fue extendida mediante la función `trafficSignsLogic`, que integra en una sola capa decisional:

- STOP,
- YIELD,
- glorieta,
- semáforos,
- persona de pickup,
- y una bandera externa de frenado peatonal.

Adicionalmente, se desarrolló `pedestrianStopLogic`, cuyo propósito es actuar como una capa de seguridad frontal inmediata basada en detección visual, análisis de profundidad y una lógica con histéresis temporal.

Esto introduce una jerarquía de control muy importante. La seguridad inmediata domina sobre la lógica reglamentaria. En términos de prioridad, la arquitectura final puede entenderse así:

$$
\text{Seguridad frontal inmediata} \;>\; \text{Lógica reglamentaria} \;>\; \text{Seguimiento nominal de trayectoria}
$$

Esta decisión es correcta desde el punto de vista de diseño de vehículos autónomos, ya que un obstáculo o peatón frente al vehículo debe tener prioridad absoluta sobre cualquier otra consideración operativa.

---

## 13. Validación general del sistema

La validación del sistema se realizó de manera modular e integral. Esto significa que no se evaluó únicamente el comportamiento final del vehículo, sino también el desempeño individual de cada subsistema, con el fin de garantizar que la integración completa se apoyara en componentes previamente verificados.

### 13.1 Validación del módulo de planeación

La planeación global se validó observando que la trayectoria generada a partir del grafo fuera coherente con la topología del mapa y con las restricciones viales introducidas mediante penalizaciones. En particular, se verificó que:

- la ruta óptima conectara correctamente el nodo inicial y el nodo objetivo,
- el camino elegido evitara tramos innecesariamente costosos desde el punto de vista operativo,
- la corrección de intersecciones mediante el nodo auxiliar mejorara la geometría local de ciertos cruces,
- la interpolación PCHIP produjera una curva continua y físicamente seguible por el vehículo.

La validación visual mediante el plot final de la trayectoria fue especialmente importante, ya que permitió comprobar que la curva roja generada coincidía con la geometría útil del circuito y conservaba continuidad en zonas críticas.

### 13.2 Validación del módulo de percepción

El detector de objetos se validó tanto cuantitativa como cualitativamente. Cuantitativamente, se analizaron métricas como:

- $\mathrm{mAP}_{50}$,
- $\mathrm{mAP}_{50:95}$,
- precisión,
- recall.

Estas métricas permitieron comprobar que el modelo entrenado era capaz de reconocer objetos relevantes del entorno con un desempeño suficientemente sólido para el contexto de la competencia.

Cualitativamente, se verificó que el modelo exportado a ONNX siguiera detectando correctamente sobre imágenes del conjunto de prueba y posteriormente en el flujo conectado con Simulink. Este paso fue muy importante, ya que garantizó que el comportamiento del modelo se conservara durante el despliegue y no solo durante el entrenamiento.

### 13.3 Validación del módulo de profundidad

La función `addDepth` se validó comprobando que las distancias asignadas a las detecciones fueran consistentes con la región física observada en el entorno. Se verificó que:

- la caja delimitadora se recortara adecuadamente dentro de los límites válidos de la imagen,
- la región depth asociada al objeto excluyera valores no válidos,
- la mediana de la región proporcionara una estimación estable de profundidad,
- el valor centinela 999 se asignara únicamente cuando la profundidad no pudiera medirse de forma confiable.

Esta validación fue importante porque toda la lógica posterior depende directamente de la confiabilidad de $\hat{z}_i$.

### 13.4 Validación de la lógica básica de señales y evasión

Las funciones `stopLogic` y `avoidCone` se validaron observando que:

- el vehículo se detuviera correctamente durante 5 segundos ante una señal STOP,
- realizara una pausa breve ante YIELD,
- redujera la velocidad ante glorietas,
- activara la maniobra senoidal de evasión cuando un cono se encontrara dentro del umbral especificado.

Aquí la validación temporal fue especialmente relevante, ya que la correcta duración de las maniobras era tan importante como su activación.

### 13.5 Validación de las direccionales

El sistema de direccionales se validó proyectando las reglas basadas en nodos sobre la trayectoria suavizada y verificando visualmente que los segmentos verdes y rojos coincidieran con las zonas correctas del mapa.

Esta validación permitió confirmar que:

- las maniobras de giro estaban correctamente identificadas,
- el nodo auxiliar central mejoraba la representación de cruces izquierdos,
- la activación de direccionales cubría todo el tramo de la maniobra y no solo un punto aislado.

### 13.6 Validación del entorno dinámico en QLabs

El script de generación del escenario se validó comprobando que todos los actores y elementos del entorno aparecieran correctamente ubicados y se comportaran como se esperaba. En particular se verificó que:

- el QCar se spawneara en la posición seleccionada,
- la persona estática apareciera sobre la banqueta,
- el peatón dinámico cruzara repetidamente el paso peatonal,
- el cono quedara colocado en la posición prevista,
- los semáforos cambiaran de estado según el ciclo programado.

Esto fue fundamental, ya que sin un entorno reproducible no sería posible validar el resto del sistema de forma consistente.

### 13.7 Validación de la lógica avanzada de tráfico y seguridad

La capa final de validación consistió en observar el comportamiento del sistema completo frente a eventos combinados. Esto incluyó revisar que:

- `trafficSignsLogic` integrara correctamente señales, semáforos y pickup,
- el vehículo se comprometiera a cruzar la intersección solo cuando el semáforo estuviera en verde estable,
- la rutina de pickup se ejecutara como una secuencia temporal de aproximación y parada,
- `pedestrianStopLogic` activara el frenado solo después de varios frames consistentes,
- el frenado se liberara también con histéresis, evitando oscilaciones rápidas.

En esta etapa quedó validada la lógica jerárquica completa del sistema.

---

## 14. Discusión técnica del sistema integrado

El sistema desarrollado demuestra que una arquitectura modular bien diseñada permite construir un comportamiento de self-driving más complejo sin perder trazabilidad ni control sobre cada componente. Cada módulo fue añadido sobre una base previa ya validada, lo cual hizo posible escalar el sistema de manera ordenada.

Desde el punto de vista funcional, el proyecto evolucionó desde un seguidor de trayectoria hacia un agente autónomo más completo. Inicialmente la referencia principal era únicamente la ruta calculada. Posteriormente se añadieron señales reglamentarias, luego obstáculos locales, después direccionales, y finalmente capas avanzadas de seguridad y contexto vial. Esta progresión muestra que la arquitectura fue correctamente pensada para admitir crecimiento incremental.

Otro aspecto importante es que el sistema no se limita a una única forma de inteligencia. Combina:

- **planeación algorítmica**, mediante grafos y camino mínimo;
- **percepción basada en aprendizaje profundo**, mediante YOLOv8;
- **estimación geométrica**, mediante profundidad;
- **lógica simbólica**, mediante reglas y máquinas de estados;
- **seguridad reactiva**, mediante histéresis y gating frontal.

Precisamente esta combinación de enfoques es lo que hace que el sistema sea técnicamente valioso y digno de presentarse en el contexto de una competencia de self-driving.

---

## 15. Conclusión técnica

La solución desarrollada para la CPS IoT Self-Driving Competition 2026 integra una arquitectura modular de conducción autónoma implementada sobre el **QCar 2 virtual** en **QLabs**, utilizando **MATLAB/Simulink** como entorno principal de integración y **Python** como plataforma de inferencia visual. A nivel metodológico, el proyecto combinó parametrización formal del vehículo, planeación global mediante grafos dirigidos con penalizaciones, entrenamiento de un detector de objetos orientado al escenario de Quanser City, comunicación bidireccional entre Simulink y Python, estimación de profundidad sobre regiones detectadas, lógica reglamentaria frente a señales, evasión de obstáculos, activación de direccionales, generación programática del escenario y una capa avanzada de interacción con semáforos y peatones.

Desde una perspectiva de ingeniería, el principal valor del proyecto radica en que cada módulo fue diseñado con una función específica, validado de forma independiente e integrado posteriormente en una arquitectura jerárquica coherente. El sistema no solo genera una ruta y la sigue, sino que además percibe el entorno, estima distancias, interpreta señales, reconoce condiciones de riesgo, modifica su comportamiento según el contexto y se valida dentro de un escenario dinámico reproducible.

En consecuencia, el trabajo presentado trasciende la idea de un simple recorrido autónomo dentro de un simulador. Se trata de una propuesta técnicamente estructurada, explicable, escalable y consistente con los principios fundamentales de un sistema de self-driving. Esta solidez metodológica y arquitectónica es precisamente lo que hace que el proyecto sea una aportación defendible y competitiva dentro del marco de la CPS IoT Self-Driving Competition 2026.