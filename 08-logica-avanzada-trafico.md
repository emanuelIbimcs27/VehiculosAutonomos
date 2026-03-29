---
layout: default
title: Lógica Avanzada de Tráfico y Seguridad
nav_order: 6
parent: CPS IoT Competition 2026
permalink: /CPS/logica-avanzada-trafico/
---
# Lógica Avanzada de Tráfico y Seguridad

## 10. Lógica unificada de señales, semáforos, peatón de pickup y frenado reglamentario: `trafficSignsLogic`

Conforme el proyecto fue evolucionando, la lógica del vehículo dejó de limitarse a reaccionar únicamente ante señales simples como STOP, YIELD o glorieta. Fue necesario desarrollar una capa de decisión más avanzada, capaz de integrar varios eventos del entorno dentro de una sola función: señales reglamentarias, semáforos, detección de un pasajero para pickup y una bandera externa de frenado peatonal.

La función `trafficSignsLogic` representa precisamente esa evolución. Se trata de un bloque de decisión híbrido que combina percepción visual, temporización, memoria interna y jerarquía de prioridades para determinar la velocidad final del vehículo en función del contexto observado.

### 10.1 Objetivo de la función

La función recibe:

- una velocidad nominal `speed_in`
- la matriz de detecciones enriquecidas con profundidad
- el tiempo actual `t`
- una bandera externa `pedestrian_flag`

y devuelve:

- una velocidad final `speed_out`
- una bandera `stop_ligth` que representa el estado de detención o luz de freno

Formalmente, la salida puede interpretarse como:

$$
(speed\_out,\ stop\_ligth) = f(speed\_in,\ detections,\ t,\ pedestrian\_flag)
$$

El objetivo es que el vehículo pueda:

- detenerse ante señales STOP,
- ceder momentáneamente el paso ante YIELD,
- reducir velocidad en glorietas,
- detenerse si detecta un peatón o un evento de seguridad frontal,
- aproximarse y detenerse para simular la recolección de un pasajero,
- responder adecuadamente al estado de los semáforos y decidir cuándo comprometerse a cruzar una intersección.

### 10.2 Código completo

```matlab
function [speed_out, stop_ligth]= trafficSignsLogic(speed_in, detections, t, pedestrian_flag)

persistent stop_active t_start stop_done
persistent yield_active t_yield_start yield_done
persistent person_active t_person_start person_phase person_done

persistent traffic_state % 0 = WAIT, 1 = GO
persistent green_counter

if isempty(stop_active)
    stop_active = false;
    t_start = 0;
    stop_done = false;

    yield_active = false;
    t_yield_start = 0;
    yield_done = false;

    % persona
    person_active = false;
    t_person_start = 0;
    person_phase = 0;
    person_done = false;
end

if isempty(traffic_state)
    traffic_state = 0;
    green_counter = 0;
end

speed_out = speed_in;

stop_detected = false;
yield_detected = false;
round_detected = false;
person_detected = false;
stop_ligth = 0;

traffic_red = false;
traffic_green = false;
traffic_yellow = false;
traffic_dist = single(999);

for i = 1:10

    class_id = detections(1,i);
    prob     = detections(2,i);
    dist     = detections(7,i);

    x1 = detections(3,i);
    x2 = detections(5,i);
    cx = (x1 + x2)/2;

    frontal = abs(cx - 320) < 100;
    right_side = cx > 360;

    % STOP
    if class_id == 5 && prob > 0.9 && dist < 1.3 && frontal
        stop_detected = true;
    end

    % YIELD
    if class_id == 7 && prob > 0.9 && dist < 1.5 && frontal
        yield_detected = true;
    end

    % ROUND
    if class_id == 4 && prob > 0.8 && dist < 2.0 && frontal
        round_detected = true;
    end

    % PERSONA (lado derecho)
    if class_id == 2 && prob > 0.8 && dist < 7.3 && right_side
        person_detected = true;
    end

    % SEMÁFORO (solo frontal)
    if prob > 0.85 && dist < 3.6 && frontal

        traffic_dist = dist;

        if class_id == 3
            traffic_red = true;
        elseif class_id == 1
            traffic_green = true;
        elseif class_id == 6
            traffic_yellow = true;
        end
    end

end

% PEDESTRIAN STOP (ALTA PRIORIDAD)
if pedestrian_flag == 1
    speed_out = 0;
    stop_ligth = 1;
    return;
end

% STOP
if stop_detected && ~stop_active && ~stop_done
    stop_active = true;
    stop_ligth = 1;
    t_start = t;
end

if stop_active
    if (t - t_start) < 5
        speed_out = 0;
        return;
    else
        stop_ligth = 0;
        stop_active = false;
        stop_done = true;
    end
end

if ~stop_detected
    stop_done = false;
end

% YIELD
if yield_detected && ~yield_active && ~yield_done
    yield_active = true;
    t_yield_start = t;
end

if yield_active
    if (t - t_yield_start) < 2
        speed_out = 0;
        stop_ligth = 1;
        return;
    else
        yield_active = false;
        stop_ligth = 0;
        yield_done = true;
    end
end

if ~yield_detected
    yield_done = false;
end

% PERSONA (pickup)
if person_detected && ~person_active && ~person_done
    person_active = true;
    t_person_start = t;
    person_phase = 1;
end

if person_active

    dt = t - t_person_start;

    % Fase 1: avanzar
    if dt < 5
        speed_out = speed_in; 

    % Fase 2: detenerse
    elseif dt < 9
        speed_out = 0;
        stop_ligth = 1;
    else
        person_active = false;
        person_done = true;
        stop_ligth = 0;
    end

    return;
end

% SEMÁFORO
commit_dist = 1.2;

if traffic_state == 0

    if traffic_green
        green_counter = green_counter + 1;
    else
        green_counter = 0;
    end

    if traffic_red || traffic_yellow
        speed_out = 0;
        stop_ligth = 1;
        return;
    end

    if green_counter > 3
        if traffic_dist < commit_dist
            traffic_state = 1;
        end
    end
end

if traffic_state == 1

    speed_out = speed_in;

    if traffic_dist > 3.5
        traffic_state = 0;
        green_counter = 0;
    end
end

% ROUND
if round_detected
    speed_out = 0.5 * speed_in;
end

end
```

### 10.3 Uso de variables persistentes y memoria temporal

La función se apoya en varias variables persistentes:

```matlab
persistent stop_active t_start stop_done
persistent yield_active t_yield_start yield_done
persistent person_active t_person_start person_phase person_done
persistent traffic_state
persistent green_counter
```

Estas variables convierten la función en una máquina de estados híbrida. No se limita a reaccionar instantáneamente al contenido de un frame, sino que recuerda información temporal sobre eventos ya activados. Esto es esencial porque muchas maniobras del vehículo tienen duración extendida en el tiempo. Por ejemplo, un STOP debe mantenerse durante varios segundos aunque la señal deje de verse un instante, y una lógica de pickup necesita varias fases consecutivas de movimiento y detención.

En términos conceptuales, la función ya no se comporta como una simple regla algebraica, sino como un sistema con memoria interna:

$$
\mathbf{x}_{k+1} = g(\mathbf{x}_k,\ \mathbf{u}_k,\ \mathbf{y}_k)
$$

donde $\mathbf{x}_k$ representa el estado interno de la lógica en el instante $k$.

### 10.4 Detección base de objetos y semántica del entorno

Durante cada iteración, la función recorre las diez detecciones disponibles:

```matlab
for i = 1:10
    class_id = detections(1,i);
    prob     = detections(2,i);
    dist     = detections(7,i);

    x1 = detections(3,i);
    x2 = detections(5,i);
    cx = (x1 + x2)/2;

    frontal = abs(cx - 320) < 100;
    right_side = cx > 360;
```

Aquí aparecen dos criterios geométricos fundamentales:

- **frontal**: el objeto se encuentra aproximadamente centrado en el campo visual
- **right_side**: el objeto aparece del lado derecho de la imagen

Matemáticamente:

$$
frontal \iff |c_x - 320| < 100
$$

$$
right\_side \iff c_x > 360
$$

donde:

$$
c_x = \frac{x_1 + x_2}{2}
$$

Estos criterios permiten que la misma detección visual se interprete de forma distinta según su posición relativa. Por ejemplo, una persona a la derecha puede representar un pasajero esperando para pickup, mientras que una detección frontal puede representar una amenaza inmediata sobre la trayectoria del vehículo.

### 10.5 Lógica STOP

La condición de activación de STOP fue:

$$
c_i = 5,\qquad \rho_i > 0.9,\qquad \hat{z}_i < 1.3,\qquad frontal
$$

En código:

```matlab
if class_id == 5 && prob > 0.9 && dist < 1.3 && frontal
    stop_detected = true;
end
```

Cuando la señal se detecta y no se había procesado previamente, la rutina entra en estado de parada. Si se denota por $t_0$ el instante de activación, la salida se comporta como:

$$
v_{out}(t) =
\begin{cases}
0, & 0 \le t-t_0 < 5 \\
v_{in}(t), & t-t_0 \ge 5
\end{cases}
$$

Además, durante esta fase se activa la bandera:

$$
stop\_ligth = 1
$$

representando el estado de detención o luz de freno.

### 10.6 Lógica YIELD

La condición para ceda el paso es:

$$
c_i = 7,\qquad \rho_i > 0.9,\qquad \hat{z}_i < 1.5,\qquad frontal
$$

Cuando esta condición se cumple, el vehículo se detiene durante 2 segundos:

$$
v_{out}(t) =
\begin{cases}
0, & 0 \le t-t_y < 2 \\
v_{in}(t), & t-t_y \ge 2
\end{cases}
$$

donde $t_y$ es el instante de activación de YIELD.

Esto reproduce una lógica menos estricta que la de STOP, pero suficiente para obligar a una pausa breve antes de continuar.

### 10.7 Lógica de glorieta

La señal de glorieta se detecta con:

$$
c_i = 4,\qquad \rho_i > 0.8,\qquad \hat{z}_i < 2.0,\qquad frontal
$$

y en ese caso la velocidad se reduce a:

$$
v_{out}(t) = 0.5\,v_{in}(t)
$$

Esta reducción modela una conducción más prudente en zonas circulares, donde el vehículo debe navegar con menor velocidad para mantener estabilidad y control.

### 10.8 Lógica de persona para pickup

La detección de una persona candidata a pickup se basa en:

$$
c_i = 2,\qquad \rho_i > 0.8,\qquad \hat{z}_i < 7.3,\qquad right\_side
$$

Esta condición es importante porque no cualquier persona debe interpretarse como un pasajero. La restricción de que aparezca del lado derecho de la imagen refleja que el pasajero se encuentra en la banqueta, en una posición donde el taxi autónomo podría aproximarse para recogerlo.

Cuando esta condición se activa, la función entra en una rutina temporal con dos fases:

1. **Fase de aproximación**  
   Durante los primeros 5 segundos:

   $$
   0 \le dt < 5 \Rightarrow v_{out}(t) = v_{in}(t)
   $$

2. **Fase de detención para pickup**  
   Durante los siguientes 4 segundos:

   $$
   5 \le dt < 9 \Rightarrow v_{out}(t) = 0
   $$

y se activa la luz de freno:

$$
stop\_ligth = 1
$$

Finalmente, la maniobra termina y se marca como completada. Esto implementa una secuencia creíble de acercamiento y parada de servicio.

### 10.9 Lógica de semáforo y máquina de estados WAIT/GO

El control de semáforo se estructuró como una máquina de estados con dos modos:

- `traffic_state = 0`: **WAIT**
- `traffic_state = 1`: **GO**

Además, se definió una distancia de compromiso:

```matlab
commit_dist = 1.2;
```

#### Estado WAIT

Mientras el sistema está en espera, se acumulan frames consecutivos de verde:

```matlab
if traffic_green
    green_counter = green_counter + 1;
else
    green_counter = 0;
end
```

Esto significa que el vehículo no responde a un único frame verde, sino que exige estabilidad temporal. Si el verde persiste más de tres frames y el semáforo se encuentra suficientemente cerca, el vehículo se compromete a cruzar:

$$
green\_counter > 3 \quad \text{y} \quad traffic\_dist < 1.2
$$

Por otro lado, si se detecta rojo o amarillo, el vehículo se detiene:

$$
traffic\_red \lor traffic\_yellow \Rightarrow v_{out}(t)=0
$$

#### Estado GO

Una vez comprometido el cruce, la lógica entra en `GO` y deja de reaccionar al semáforo:

```matlab
if traffic_state == 1
    speed_out = speed_in;
```

El sistema vuelve al estado WAIT solo cuando la distancia al semáforo excede cierto valor:

$$
traffic\_dist > 3.5
$$

Esta lógica evita un comportamiento irreal como detenerse a mitad de la intersección si el color cambia mientras el vehículo ya está cruzando.

### 10.10 Prioridad máxima de la bandera peatonal externa

La primera condición que se revisa dentro de la función es:

```matlab
if pedestrian_flag == 1
    speed_out = 0;
    stop_ligth = 1;
    return;
end
```

Esto significa que cualquier instrucción externa de frenado peatonal tiene prioridad absoluta sobre todas las demás lógicas. En términos de seguridad, esta jerarquía es correcta: si existe evidencia de riesgo frontal inmediato, la lógica reglamentaria debe ceder completamente y detener el vehículo.

---

## 11. Capa robusta de frenado de seguridad basada en detección y profundidad: `pedestrianStopLogic`

Para reforzar la seguridad del sistema se implementó una función específica llamada `pedestrianStopLogic`. Aunque originalmente se pensó para el caso de una persona cruzando, en su forma actual funciona como una capa general de seguridad frontal, combinando detección visual con profundidad para decidir si existe un obstáculo próximo frente al vehículo.

Esta función es especialmente importante porque introduce una verificación adicional independiente de la lógica de señales. Su función no es interpretar normas de tráfico, sino proteger al vehículo frente a un riesgo inmediato.

### 11.1 Código completo

```matlab
function stop_flag = pedestrianStopLogic(detections, depth_frame)

persistent stop_state counter_on counter_off

if isempty(stop_state)
    stop_state = false;
    counter_on = 0;
    counter_off = 0;
end

% 1. DETECCIÓN (gating)
valid_object = false;

for i = 1:10

    class_id = detections(1,i);
    prob     = detections(2,i);
    dist     = detections(7,i);

    if prob < 0.8 || dist == 0
        continue;
    end

    x1 = detections(3,i);
    x2 = detections(5,i);
    cx = (x1 + x2)/2;

    if abs(cx - 320) < 80 && dist < 3.0

        if class_id ~= 0
            valid_object = true;
        end

    end
end

% 2. ROI EN DEPTH
roi = depth_frame(200:350, 260:380);

% 3. PROCESAMIENTO ROBUSTO
valid_pixels = roi(roi > 0);

if isempty(valid_pixels)
    obstacle_close = false;
else
    d_sorted = sort(valid_pixels(:));
    idx = max(1, round(0.1 * length(d_sorted)));
    d_min = d_sorted(idx);

    obstacle_close = d_min < 0.5;
end

% 4. HISTÉRESIS
if valid_object && obstacle_close
    counter_on = counter_on + 1;
    counter_off = 0;
else
    counter_off = counter_off + 1;
    counter_on = 0;
end

% Activar STOP (3 frames consistentes)
if counter_on > 2
    stop_state = true;
end

% Liberar STOP (5 frames seguros)
if counter_off > 4
    stop_state = false;
end

% OUTPUT
stop_flag = stop_state;

end
```

### 11.2 Fase 1: gating por detección visual

La primera etapa verifica si existe un objeto visualmente válido en la región frontal. Las condiciones usadas fueron:

- confianza $\rho_i \ge 0.8$
- distancia estimada $\hat{z}_i > 0$
- posición horizontal centrada:

$$
|c_{x,i} - 320| < 80
$$

- distancia menor a 3.0 m
- clase distinta de cono:

$$
c_i \neq 0
$$

En conjunto:

$$
\rho_i \ge 0.8,\qquad \hat{z}_i > 0,\qquad |c_{x,i}-320|<80,\qquad \hat{z}_i<3.0,\qquad c_i \neq 0
$$

Si al menos una detección cumple estas condiciones, la variable `valid_object` se activa. Esto filtra el problema a objetos plausiblemente relevantes frente al vehículo.

### 11.3 Fase 2: validación espacial mediante ROI en depth

Una vez que existe evidencia visual, la función analiza una región fija del mapa de profundidad:

```matlab
roi = depth_frame(200:350, 260:380);
```

Esta región corresponde aproximadamente a una ventana central-baja de la imagen, es decir, la zona del espacio directamente frente al vehículo donde un obstáculo inminente sería más peligroso.

Si se define:

$$
\mathcal{R} = \{D(u,v)\;|\; 200 \le u \le 350,\ 260 \le v \le 380,\ D(u,v) > 0\}
$$

entonces la decisión espacial se toma únicamente a partir de ese subconjunto de píxeles válidos del mapa depth.

### 11.4 Uso del percentil 10 como estimador robusto

En lugar de utilizar el mínimo absoluto de profundidad, la función ordena los valores y toma el percentil 10:

```matlab
d_sorted = sort(valid_pixels(:));
idx = max(1, round(0.1 * length(d_sorted)));
d_min = d_sorted(idx);
```

Esto equivale a estimar:

$$
d_{10\%} = Q_{0.10}(\mathcal{R})
$$

donde $Q_{0.10}$ es el cuantil 10 %. Esta decisión es muy adecuada porque evita que un solo píxel espurio, demasiado cercano, dispare un frenado falso. El percentil 10 sigue siendo sensible a obstáculos próximos, pero es mucho más robusto que tomar el mínimo puro.

Se considera entonces que existe un obstáculo cercano si:

$$
d_{10\%} < 0.5
$$

### 11.5 Histéresis temporal

La activación del frenado no depende de una sola observación instantánea, sino de una lógica con histéresis temporal. Se emplean dos contadores:

- `counter_on`: número de frames consecutivos con evidencia de obstáculo
- `counter_off`: número de frames consecutivos sin evidencia de obstáculo

La lógica es:

```matlab
if valid_object && obstacle_close
    counter_on = counter_on + 1;
    counter_off = 0;
else
    counter_off = counter_off + 1;
    counter_on = 0;
end
```

El sistema activa el estado de STOP cuando:

$$
counter\_on > 2
$$

es decir, después de tres frames consistentes con riesgo. Y lo libera cuando:

$$
counter\_off > 4
$$

es decir, después de cinco frames seguros consecutivos.

Esta histéresis reduce el efecto del ruido y evita oscilaciones rápidas entre frenar y avanzar.

### 11.6 Salida del módulo y acoplamiento con la lógica principal

El resultado final es:

```matlab
stop_flag = stop_state;
```

Esta bandera se conecta como entrada a `trafficSignsLogic`, donde tiene la máxima prioridad. En consecuencia, la arquitectura de decisión queda jerarquizada de la siguiente manera:

1. `pedestrianStopLogic` evalúa riesgo inmediato frontal
2. si detecta riesgo, emite `stop_flag = 1`
3. `trafficSignsLogic` recibe esa bandera y ordena detener el vehículo antes de considerar cualquier otra regla

Este diseño es correcto desde el punto de vista de seguridad, porque separa claramente dos niveles de decisión:

- una capa de **seguridad reactiva inmediata**
- una capa de **comportamiento reglamentario y contextual**

## Papel de esta sección dentro del sistema completo

Esta sección representa la capa más avanzada de decisión del vehículo. Mientras las funciones básicas reaccionaban a señales individuales, aquí el sistema pasa a integrar múltiples eventos simultáneos del entorno: semáforos, peatones, pickups, señales reglamentarias y criterios de seguridad inmediata.

En otras palabras, esta parte del proyecto es la que más se aproxima al comportamiento de un vehículo autónomo real dentro de una escena urbana simplificada. No se limita a seguir una trayectoria o a reconocer objetos, sino que organiza prioridades, maneja estados temporales y decide cómo debe comportarse el vehículo según el contexto completo del entorno.