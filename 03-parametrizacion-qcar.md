---
layout: default
title: Parametrización del QCar 2 Virtual
nav_order: 1
parent: CPS IoT Competition 2026
permalink: /CPS/parametrizacion-qcar/
---

# Parametrización del QCar 2 Virtual

## 1. Parametrización del QCar 2 virtual y definición del entorno

La primera etapa del desarrollo consistió en configurar el vehículo virtual y todos los parámetros base del stack. Para ello se utilizó un script de inicialización en MATLAB donde se establece el tipo de mapa, el tipo de QCar, los tiempos de muestreo de cada subsistema, las ganancias del controlador de dirección, los parámetros de estimación y los archivos de calibración.

Esta etapa es fundamental porque, antes de que el vehículo pueda planear, percibir o tomar decisiones, debe existir una base consistente sobre la cual opere el sistema completo. En un entorno de simulación como QLabs, una mala definición de tiempos de muestreo, ganancias o referencias geométricas puede traducirse en comportamientos inestables, errores de sincronización o respuestas inconsistentes del controlador. Por ello, la parametrización del QCar constituye el punto de partida de toda la arquitectura de self-driving.

### 1.1 Definición del tipo de mapa y tipo de vehículo

```matlab
clear all;

%% User configurable parameters
map_type = 1;
qcar_types = 1;
```

En este bloque se definen dos parámetros fundamentales. El primero, `map_type = 1`, indica que se está trabajando sobre el mapa grande del entorno SDCS. El segundo, `qcar_types = 1`, selecciona la configuración correspondiente al **QCar virtual**. Este detalle es importante porque el mismo archivo contempla una diferenciación entre plataforma virtual y plataforma física, lo cual deja preparada la arquitectura para una posible migración futura a hardware real.

Desde el punto de vista de diseño, esta distinción permite desacoplar parámetros de simulación y parámetros físicos. Es decir, el stack fue concebido desde el inicio con una estructura suficientemente flexible como para reutilizar el mismo flujo general de trabajo en distintos escenarios, ajustando únicamente las constantes específicas de cada plataforma.

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

lo que equivale a una frecuencia de 500 Hz. A partir de ese periodo base se derivan los tiempos de muestreo de los demás subsistemas, como cámaras, LiDAR, visualización y red neuronal.

Desde el punto de vista de sistemas discretos, esto significa que el tiempo del controlador se toma como referencia común, y todos los demás módulos operan como múltiplos enteros o aproximaciones alineadas a ese periodo. Esta decisión evita inconsistencias temporales entre sensores, controladores y módulos de procesamiento.

Por ejemplo, si un sensor visual opera aproximadamente a 30 Hz, entonces su tiempo de muestreo ideal sería cercano a:

$$
T_v \approx 0.033\ \text{s}
$$

En el código, ese tiempo se ajusta al múltiplo más cercano del periodo del controlador, mediante:

$$
T_v = T_c \cdot \left\lceil \frac{0.033}{T_c} \right\rceil
$$

Esto garantiza que el sistema conserve coherencia temporal interna dentro de Simulink.

La variable `NN_Sample_Time` se iguala al tiempo de la cámara RealSense, lo cual tiene sentido porque la inferencia visual no debe ejecutarse a una frecuencia independiente arbitraria, sino sincronizada con la adquisición de las imágenes sobre las que opera.

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

Este punto funciona como referencia espacial para alinear la representación del mapa, la trayectoria calculada y los datos derivados de sensores. En otras palabras, no basta con conocer las coordenadas absolutas del vehículo o de los nodos; también es necesario establecer un origen operativo común desde el cual se interprete la geometría del entorno.

Más adelante, esta referencia reaparece en la visualización de la trayectoria, cuando se ajustan las coordenadas suavizadas restando la posición de calibración. Esto asegura que la ruta se represente correctamente dentro del marco de referencia del escenario.

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

donde $e(t)$ representa el error de trayectoria o el error de orientación respecto a la referencia.

La acción proporcional corrige el error principal, mientras que la acción derivativa amortigua cambios rápidos y reduce oscilaciones. Esto es particularmente importante en un vehículo autónomo que sigue una trayectoria curva, ya que un control puramente proporcional puede producir sobreoscilación o correcciones demasiado agresivas en curvas e intersecciones.

El hecho de que exista una configuración distinta para `qcar_types == 2` también es importante. Sugiere que la plataforma física presenta una dinámica diferente a la del simulador, por lo que las ganancias deben adaptarse al comportamiento real del sistema.

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

Este fragmento define parámetros de filtros de Kalman y de un filtro de Kalman extendido para el vehículo. Aunque el núcleo del proyecto se centra principalmente en planeación, percepción y toma de decisiones, la inclusión de estos parámetros fortalece la base de estimación del stack y demuestra que el vehículo se encuentra montado sobre una arquitectura más amplia de modelado y fusión de información.

En particular, la longitud efectiva del vehículo se definió como:

$$
L = 0.256\ \text{m}
$$

Este parámetro es importante para modelos cinemáticos tipo bicicleta y para la propagación del estado en un EKF.

Las matrices de covarianza también reflejan una decisión de diseño relevante. Si se denota por $\mathbf{Q}$ la covarianza del ruido de proceso y por $\mathbf{R}$ la covarianza del ruido de medición, entonces el filtro opera sobre la lógica clásica de estimación:

$$
\hat{\mathbf{x}}_{k|k-1} = f(\hat{\mathbf{x}}_{k-1|k-1}, \mathbf{u}_{k-1})
$$

$$
\mathbf{P}_{k|k-1} = \mathbf{A}_k \mathbf{P}_{k-1|k-1}\mathbf{A}_k^\top + \mathbf{Q}
$$

y posteriormente actualiza con la medición:

$$
\mathbf{K}_k = \mathbf{P}_{k|k-1}\mathbf{H}_k^\top \left(\mathbf{H}_k \mathbf{P}_{k|k-1} \mathbf{H}_k^\top + \mathbf{R}\right)^{-1}
$$

$$
\hat{\mathbf{x}}_{k|k} = \hat{\mathbf{x}}_{k|k-1} + \mathbf{K}_k \left(\mathbf{z}_k - h(\hat{\mathbf{x}}_{k|k-1})\right)
$$

Aunque en esta parte de la metodología no se desarrolla toda la implementación del EKF, el hecho de definir sus parámetros deja claro que el sistema fue preparado para trabajar sobre una base formal de estimación del estado.

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

Asimismo, se definió una corrección adicional entre representación virtual y física del LiDAR:

$$
\theta_{virt\to phys} = -7^\circ
$$

Estas correcciones angulares son indispensables para alinear adecuadamente las referencias espaciales del entorno con la trayectoria calculada y con las visualizaciones posteriores. En un sistema autónomo, una desalineación angular entre el sensor y el mapa puede provocar que los obstáculos o la referencia geométrica se interpreten en posiciones incorrectas, afectando tanto la planeación como la toma de decisiones.

Los archivos `distance_new_qcar2.mat` y `angles_new_qcar2.mat` almacenan información de distancia y ángulos usada como referencia geométrica del entorno. Al cargarlos, el sistema dispone de una representación consistente del espacio de trabajo sobre la cual puede superponerse la trayectoria planeada.

## Rol de esta sección dentro del sistema completo

La parametrización del QCar 2 virtual constituye la base técnica del sistema completo. Gracias a esta etapa se define una estructura temporal coherente, una referencia espacial clara, un conjunto de ganancias adecuadas para el controlador y una preparación inicial para estimación del estado y alineación sensorial. Todo esto permite que los módulos posteriores —planeación, percepción, profundidad y lógica de decisión— operen sobre una base estable.

En otras palabras, esta sección no describe un conjunto de parámetros aislados, sino el marco operacional que hace posible que el resto del algoritmo de self-driving funcione correctamente dentro del entorno virtual de la competencia.