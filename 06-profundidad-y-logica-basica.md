---
layout: default
title: Profundidad, Señales Básicas y Evasión
nav_order: 4
parent: CPS IoT Competition 2026
permalink: /CPS/profundidad-y-logica-basica/
---
# Profundidad, Señales Básicas y Evasión

## 5. Estimación de profundidad sobre las detecciones: función `addDepth`

El detector de objetos proporciona información bidimensional a partir de imágenes RGB, pero para tomar decisiones de conducción no basta con conocer únicamente la clase del objeto y su localización en el plano de la imagen. En un sistema autónomo también es necesario estimar la distancia real a la que se encuentra cada elemento del entorno. Por esta razón se implementó la función `addDepth`, cuyo objetivo es enriquecer cada detección visual con una estimación robusta de profundidad obtenida a partir del mapa depth asociado a la cámara virtual.

Esta función constituye el puente entre la percepción puramente visual y la percepción espacial. Gracias a ella, una detección deja de ser solo un bounding box con clase y confianza, y pasa a convertirse en un objeto con significado geométrico dentro del entorno del vehículo.

### 5.1 Objetivo de la función

Si el detector entrega, para cada objeto, una estructura del tipo:

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

donde:

- $c_i$ es la clase detectada,
- $\rho_i$ es la confianza,
- $(x_{1,i}, y_{1,i})$ y $(x_{2,i}, y_{2,i})$ son las coordenadas de la caja delimitadora,

entonces la función `addDepth` transforma esa detección en una estructura enriquecida:

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

donde $\hat{z}_i$ representa la profundidad estimada del objeto.

### 5.2 Definición de la función

```matlab
function out = addDepth(detections, depth)

% detections: [6 x 10]
% depth: [480 x 640]

out = zeros(7,10,'single');
```

La matriz `detections` contiene hasta diez objetos detectados, cada uno con seis atributos. La matriz `depth` almacena la información de profundidad por píxel. La salida `out` añade una séptima fila para guardar la distancia estimada de cada detección válida.

La inicialización de la salida con ceros y tipo `single` también es importante, ya que mantiene coherencia numérica con el resto del flujo en Simulink y evita gasto innecesario de memoria.

### 5.3 Código completo

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

### 5.4 Selección de la región de interés

Para cada detección válida, la función toma la caja delimitadora y extrae la región correspondiente del mapa de profundidad. Matemáticamente, si el bounding box del objeto $i$ se define por:

$$
B_i = \{(u,v)\;|\; x_{1,i} \le u \le x_{2,i},\ y_{1,i} \le v \le y_{2,i}\}
$$

entonces la región de interés asociada a profundidad queda dada por:

$$
\mathcal{R}_i = \{D(u,v)\;|\;(u,v)\in B_i\}
$$

donde $D(u,v)$ es la profundidad en el píxel $(u,v)$.

A diferencia de estrategias más simples que toman solo el píxel central de la caja, aquí se analiza toda la región. Esto hace que la estimación sea más robusta, ya que una sola muestra central podría corresponder a un hueco del sensor, al fondo o a un valor atípico no representativo del objeto.

### 5.5 Saneamiento geométrico de la caja delimitadora

Antes de extraer la región del mapa depth, la función realiza varias operaciones de saneamiento:

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

Estas operaciones tienen un propósito claro. Primero, convierten las coordenadas a enteros, ya que los índices de una matriz deben ser discretos. Después, saturan cada coordenada a los límites válidos de la imagen:

$$
x \in [1,640], \qquad y \in [1,480]
$$

Esto evita errores de indexación si la detección se encuentra parcialmente fuera del borde de la imagen.

Además, se verifica que el orden de las coordenadas sea consistente:

```matlab
if x2 < x1
    temp = x1; x1 = x2; x2 = temp;
end
if y2 < y1
    temp = y1; y1 = y2; y2 = temp;
end
```

Esto asegura que siempre se cumpla:

$$
x_{1,i} \le x_{2,i}, \qquad y_{1,i} \le y_{2,i}
$$

lo cual es indispensable para construir una región rectangular válida.

### 5.6 Filtrado de valores inválidos en profundidad

Una vez obtenida la región de interés, la función elimina valores no válidos:

```matlab
roi = roi(~isnan(roi));
roi = roi(roi > 0);
```

Esto significa que la estimación de profundidad se basa únicamente en el conjunto:

$$
\mathcal{Z}_i =
\left\{
D(u,v)\;|\;(u,v)\in B_i,\ D(u,v)>0,\ D(u,v)\neq \text{NaN}
\right\}
$$

Este filtrado es necesario porque los mapas depth pueden contener píxeles nulos, huecos o lecturas indefinidas. Si esos valores se usaran directamente, la distancia estimada sería poco confiable y podría disparar decisiones incorrectas en la lógica del vehículo.

### 5.7 Uso de la mediana como estimador robusto

La distancia final del objeto se calcula como:

```matlab
if isempty(roi)
    dist = single(999);
else
    dist = median(roi); 
end
```

En términos matemáticos:

$$
\hat{z}_i =
\begin{cases}
\operatorname{median}(\mathcal{Z}_i), & \mathcal{Z}_i \neq \varnothing \\
999, & \mathcal{Z}_i = \varnothing
\end{cases}
$$

La mediana fue elegida como estimador robusto porque reduce la influencia de valores extremos. Si dentro de la caja existen píxeles espurios, huecos parciales o zonas del fondo, la mediana sigue proporcionando una medida representativa de la distancia del objeto. Esto es especialmente útil en escenas urbanas simuladas donde las cajas pueden abarcar bordes o regiones mixtas.

El valor `999` se usa como centinela para indicar que no fue posible obtener una medición válida. De este modo, la lógica de decisión puede distinguir entre un objeto detectado con profundidad fiable y uno cuya distancia no pudo estimarse correctamente.

### 5.8 Salida enriquecida

Finalmente, la función conserva los seis atributos originales de la detección y agrega la profundidad calculada:

```matlab
out(1:6,i) = detections(:,i);
out(7,i) = dist;
```

Con esto, la salida deja de ser una detección puramente visual y se convierte en una detección con contenido geométrico. Esta transformación es esencial para el resto del sistema, ya que las funciones de STOP, YIELD, semáforo, pickup y evasión toman decisiones en función de la distancia estimada y no únicamente de la presencia visual del objeto.

---

## 6. Lógica reglamentaria para señales: `stopLogic`

Una vez que las detecciones fueron enriquecidas con distancia, se implementó una lógica reglamentaria básica para que el vehículo pudiera responder a señales del entorno. La función `stopLogic` constituye la primera capa de decisión basada en reglas y se diseñó para atender tres elementos viales principales:

- señales de **STOP**
- señales de **YIELD**
- señales de **ROUNDABOUT**

Su función es modificar la velocidad del vehículo según el tipo de señal detectada, su confianza, su distancia y su posición relativa dentro del campo visual.

### 6.1 Objetivo de la función

La función recibe:

- una velocidad de entrada `speed_in`
- la matriz de detecciones enriquecidas
- el tiempo actual `t`

y devuelve una velocidad ajustada:

$$
speed\_out = f(speed\_in,\ detections,\ t)
$$

El objetivo es que el vehículo reduzca o anule temporalmente su velocidad cuando se enfrente a señales específicas, siguiendo una jerarquía de prioridades coherente con reglas básicas de tránsito.

### 6.2 Código completo

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

### 6.3 Cálculo de frontalidad de la señal

La función no solo analiza la clase, confianza y distancia de la detección, sino también su posición horizontal en la imagen. Para ello calcula el centro horizontal del bounding box:

$$
c_{x,i} = \frac{x_{1,i} + x_{2,i}}{2}
$$

y define una condición de frontalidad:

$$
|c_{x,i} - 320| < 100
$$

Aquí 320 representa el centro horizontal de una imagen de ancho 640 píxeles. Esta condición significa que solo se consideran relevantes las señales que aparecen aproximadamente frente al vehículo, descartando aquellas que estén demasiado a la izquierda o a la derecha del campo visual.

Esta decisión es muy importante porque evita falsos disparos de la lógica por objetos que sí fueron detectados, pero que no pertenecen al carril o a la escena directamente relevante para el movimiento inmediato del vehículo.

### 6.4 Detección de STOP

La condición para considerar válida una señal de STOP fue:

$$
c_i = 5,\qquad \rho_i > 0.9,\qquad \hat{z}_i < 1.3,\qquad |c_{x,i} - 320| < 100
$$

Es decir, el objeto detectado debe pertenecer a la clase STOP, tener alta confianza, encontrarse a menos de 1.3 metros y aparecer frontalmente.

En el código:

```matlab
if class_id == 5 && prob > 0.9 && dist < 1.3 && frontal
    stop_detected = true;
end
```

Cuando esta condición se activa y la rutina no se había ejecutado previamente, la función entra en un estado de parada:

```matlab
if stop_detected && ~stop_active && ~stop_done
    stop_active = true;
    t_start = t;
end
```

La salida del vehículo queda entonces:

$$
v_{out}(t) =
\begin{cases}
0, & 0 \le t-t_0 < 5 \\
v_{in}(t), & t-t_0 \ge 5
\end{cases}
$$

donde $t_0$ es el instante de activación.

Esto significa que el vehículo permanece completamente detenido durante 5 segundos, reproduciendo un comportamiento reglamentario claro y verificable.

### 6.5 Detección de YIELD

La condición para una señal de ceda el paso fue:

$$
c_i = 7,\qquad \rho_i > 0.9,\qquad \hat{z}_i < 1.5,\qquad |c_{x,i} - 320| < 100
$$

Implementada como:

```matlab
if class_id == 7 && prob > 0.9 && dist < 1.5 && frontal
    yield_detected = true;
end
```

Cuando se activa, la función entra en una rutina temporal de espera de 2 segundos:

$$
v_{out}(t) =
\begin{cases}
0, & 0 \le t-t_y < 2 \\
v_{in}(t), & t-t_y \ge 2
\end{cases}
$$

donde $t_y$ es el instante de activación de YIELD.

Este comportamiento refleja una lógica menos severa que STOP, pero suficiente para obligar al vehículo a ceder momentáneamente el paso antes de continuar.

### 6.6 Detección de glorieta

La señal de glorieta se definió con la condición:

$$
c_i = 4,\qquad \rho_i > 0.8,\qquad \hat{z}_i < 2.0,\qquad |c_{x,i} - 320| < 100
$$

En código:

```matlab
if class_id == 4 && prob > 0.8 && dist < 2.0 && frontal
    round_detected = true;
end
```

A diferencia de STOP y YIELD, esta señal no obliga al vehículo a detenerse. En su lugar, reduce la velocidad nominal al 50 %:

$$
v_{out}(t) = 0.5\,v_{in}(t)
$$

Esto modela una conducción más prudente en zonas de giro circular, sin interrumpir completamente la marcha.

### 6.7 Uso de variables persistentes y memoria de eventos

La función utiliza variables persistentes para recordar si una maniobra ya fue activada:

```matlab
persistent stop_active t_start stop_done
persistent yield_active t_yield_start yield_done
```

Esto convierte la lógica en una máquina de estados simple, donde el sistema no depende únicamente del frame actual, sino también de su historial reciente. Gracias a ello:

- una señal de STOP no reactiva constantemente la detención mientras permanece visible
- un YIELD no reinicia su temporización en cada iteración
- el sistema puede distinguir entre una maniobra ya ejecutada y una señal nueva

En otras palabras, la lógica no es puramente instantánea, sino temporalmente coherente.

### 6.8 Jerarquía de prioridades

La función fue diseñada con una jerarquía clara:

$$
\text{STOP} > \text{YIELD} > \text{ROUNDABOUT}
$$

Esto se refleja en el uso de `return` dentro de los bloques de STOP y YIELD. Si el vehículo está ejecutando una parada por STOP, la función sale inmediatamente y no evalúa ninguna otra lógica. Lo mismo ocurre con YIELD antes de llegar a la reducción por glorieta.

Esta decisión es importante porque impone un orden reglamentario coherente: una señal de alto total debe dominar sobre cualquier comportamiento de circulación continua.

### 6.9 Papel de esta sección dentro del sistema completo

La función `stopLogic` representa la primera capa de decisión reglamentaria del vehículo. Su importancia radica en que transforma detecciones visuales enriquecidas con profundidad en comandos concretos de velocidad. Mientras que el módulo de percepción dice **qué hay en la escena**, esta lógica dice **qué debe hacer el vehículo frente a ello**.

En conjunto con `addDepth`, esta sección marca la transición entre percepción e interpretación. El sistema deja de limitarse a observar objetos en una imagen y empieza a actuar de forma consistente con reglas básicas de conducción.