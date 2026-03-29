---
layout: default
title: Generación del Escenario en QLabs
nav_order: 5
parent: CPS IoT Competition 2026
permalink: /CPS/escenario-qlabs/
---
# Generación del Escenario en QLabs

## 9. Generación programática del escenario de competencia en QLabs

Además del diseño del algoritmo de conducción autónoma, una parte esencial del proyecto fue la construcción del entorno de simulación donde dicho algoritmo sería validado. Para ello se desarrolló un script encargado de generar programáticamente el escenario de competencia dentro de **QLabs**, incorporando no solo la infraestructura geométrica del mapa, sino también elementos dinámicos y estáticos relevantes para el comportamiento del vehículo: muros, señalización, cruces peatonales, semáforos, una persona estática para simulación de pickup, un peatón dinámico cruzando la calle y un cono de tráfico como obstáculo de la competencia.

Desde una perspectiva de ingeniería, este script no cumple únicamente una función estética o visual. Su verdadero propósito es crear un entorno de pruebas controlado, reproducible y suficientemente rico como para evaluar el desempeño del vehículo en condiciones cercanas a las de una escena urbana simplificada. De esta manera, el escenario deja de ser un fondo pasivo y se convierte en una parte activa de la validación del sistema.

### 9.1 Objetivo del generador de escenario

El objetivo general de esta rutina es construir una instancia del entorno en la que el vehículo pueda ser probado frente a distintas situaciones de navegación. Estas situaciones incluyen:

- circulación sobre el mapa de competencia,
- interacción con señales de tránsito,
- respuesta ante semáforos con estados cambiantes,
- detección y evasión de un cono,
- simulación de recolección de un pasajero en banqueta,
- detección y respuesta ante un peatón que cruza un paso de cebra.

En términos funcionales, este módulo proporciona el contexto físico y lógico dentro del cual opera el algoritmo de self-driving. Por ello, su papel dentro del sistema completo es fundamental.

### 9.2 Selección del punto de spawn del vehículo

```matlab
%% Configurable Params

% Choose spawn location of QCar
% 1 => calibration location
% 2 => taxi hub area
spawn_location = 2;
```

Este parámetro permite seleccionar la posición inicial del QCar. Existen dos configuraciones posibles:

- `spawn_location = 1`: ubicación de calibración
- `spawn_location = 2`: zona del taxi hub

Esto es útil porque el mismo escenario puede usarse para distintos propósitos. Una posición de calibración sirve para validaciones iniciales de sensores, referencia espacial o arranque del sistema, mientras que la posición del taxi hub permite ejecutar la lógica completa de navegación y pickup desde un punto operativo más representativo del flujo del proyecto.

### 9.3 Función de limpieza y manejo de recursos

```matlab
function cleanupQLabs(qlabs)
    qlabs.close()
end
```

La función de limpieza se encarga de cerrar correctamente la conexión con QLabs. Este tipo de rutina es importante porque evita que queden sesiones abiertas o actores residuales en memoria después de una ejecución fallida o de una terminación abrupta. Desde el punto de vista de robustez experimental, cerrar correctamente la sesión garantiza que el siguiente experimento comience desde un estado limpio.

### 9.4 Controlador dinámico de tráfico y peatón

Una de las piezas más relevantes del script es la función `trafficLightController`, encargada de manejar simultáneamente el estado de los semáforos y el movimiento del peatón dinámico.

```matlab
function trafficLightController(qlabs)
    disp('Iniciando controlador de tráfico y peatón...')
    try
        % Inicialización de semáforos
        t1 = QLabsTrafficLight(qlabs);
        t2 = QLabsTrafficLight(qlabs);
        t3 = QLabsTrafficLight(qlabs);
        t4 = QLabsTrafficLight(qlabs);

        % Referencia al peatón (ID 20)
        hObstacle = QLabsPerson(qlabs);
        hObstacle.actorNumber = 20; 

        % Coordenadas
        LOC_A = [1.441, 0.569, 0.005]; 
        LOC_B = [1.441, 0.809, 0.005]; 
        hacia_B = true; 

        intersection1Flag = 0;

        clear cleanup;
        cleanup = onCleanup(@() qlabs.close());

        while(true)
            fprintf('Ciclo de semáforo: %d\n', intersection1Flag);

            if intersection1Flag == 0
                t1.set_color(3); t3.set_color(3); t2.set_color(1); t4.set_color(1);
            elseif intersection1Flag == 1
                t2.set_color(2); t4.set_color(2);
            elseif intersection1Flag == 2
                t1.set_color(1); t3.set_color(1); t2.set_color(3); t4.set_color(3);
            elseif intersection1Flag == 3
                t1.set_color(2); t3.set_color(2);
            end

            % Movimiento del peatón
            if hacia_B
                hObstacle.move_to(LOC_B, 0.3, 1);
                hacia_B = false;
            else
                hObstacle.move_to(LOC_A, 0.3, 1);
                hacia_B = true;
            end

            intersection1Flag = mod((intersection1Flag + 1), 4);
            pause(5);
        end
    catch ME
        fprintf('Error en el controlador: %s\n', ME.message);
    end
end
```

### 9.5 Lógica temporal del sistema semafórico

La variable `intersection1Flag` funciona como un índice de estado discreto que evoluciona cíclicamente según:

$$
intersection1Flag_{k+1} = (intersection1Flag_k + 1) \bmod 4
$$

Esto genera un ciclo periódico con cuatro fases:

$$
0 \rightarrow 1 \rightarrow 2 \rightarrow 3 \rightarrow 0 \rightarrow \dots
$$

Cada fase representa una combinación distinta del estado de los semáforos. Aunque el script no modela explícitamente todas las complejidades de un sistema de tráfico urbano real, sí genera una alternancia suficiente para obligar al vehículo a detectar colores, decidir si debe esperar y determinar el momento apropiado para comprometerse a cruzar la intersección.

Esta estructura es muy útil porque introduce un entorno dinámico pero controlado. Al cambiar cada cinco segundos:

$$
T_{ciclo} = 5\ \text{s}
$$

se obtiene una señal temporal suficientemente lenta para ser capturada y procesada por la percepción del vehículo, pero suficientemente dinámica como para poner a prueba su lógica de decisión.

### 9.6 Movimiento cíclico del peatón dinámico

El peatón asociado al actor 20 se mueve entre dos puntos:

```matlab
LOC_A = [1.441, 0.569, 0.005]; 
LOC_B = [1.441, 0.809, 0.005];
```

La trayectoria del peatón puede describirse como una oscilación periódica entre dos extremos:

$$
A \rightarrow B \rightarrow A \rightarrow B \rightarrow \dots
$$

La variable booleana `hacia_B` controla el sentido del movimiento. Este diseño permite simular un peatón que cruza repetidamente un paso de cebra, lo cual es ideal para probar el módulo de detección peatonal y la lógica de frenado del vehículo.

Desde el punto de vista de validación, esta elección es muy conveniente porque el evento peatonal no depende del azar: siempre ocurre en la misma zona del mapa, de forma repetible, y con una velocidad controlada.

### 9.7 Configuración del entorno de MATLAB y QLabs

Antes de construir el escenario, el script verifica que la librería de QLabs esté en el path de MATLAB y detiene posibles modelos RT previamente activos:

```matlab
newPathEntry = fullfile(getenv('QAL_DIR'), '0_libraries', 'matlab', 'qvl');
...
qc_stop_model('tcpip://localhost:17000', 'QCar2_Workspace')
...
qc_stop_model('tcpip://localhost:17000', 'QCar2_Workspace_studio')
```

Posteriormente establece la conexión con QLabs:

```matlab
qlabs = QuanserInteractiveLabs();
connection_established = qlabs.open('localhost');
```

y limpia el mundo virtual eliminando actores preexistentes:

```matlab
num_destroyed = qlabs.destroy_all_spawned_actors();
```

Estas operaciones son importantes porque garantizan que cada ejecución del experimento comience desde un entorno limpio y consistente. Esto evita resultados contaminados por objetos residuales o configuraciones previas del simulador.

### 9.8 Construcción del piso y referencia geométrica del escenario

```matlab
x_offset = 0.13;
y_offset = 1.67;
hFloor = QLabsQCarFlooring(qlabs);
hFloor.spawn_degrees([x_offset, y_offset, 0.001],[0, 0, -90]);
```

Aquí se define el piso del escenario con una traslación $(x_{offset}, y_{offset})$ y una rotación de \(-90^\circ\). Esta etapa es importante porque establece el marco físico sobre el cual se montan el resto de los elementos del escenario. La correcta ubicación del piso permite que la distribución de muros, señales y actores corresponda con las coordenadas utilizadas por la trayectoria del vehículo y por el mapa topológico de nodos.

### 9.9 Construcción de muros y límites físicos

El script genera múltiples muros para delimitar el circuito:

```matlab
hWall = QLabsWalls(qlabs);
hWall.set_enable_dynamics(false);

for y = 0:4
    hWall.spawn_degrees([-2.4 + x_offset, (-y*1.0)+2.55 + y_offset, 0.001], [0, 0, 0]);
end

for x = 0:4
    hWall.spawn_degrees([-1.9+x + x_offset, 3.05+ y_offset, 0.001], [0, 0, 90]);
end
...
```

Estos muros cumplen una doble función. Por un lado, reproducen la geometría del circuito de competencia. Por otro, actúan como elementos físicos de referencia visual y espacial dentro de QLabs. Desactivar la dinámica de los muros implica que estos se comportan como elementos estáticos del entorno, lo cual es apropiado porque su propósito es delimitar la infraestructura y no interactuar dinámicamente con el vehículo.

### 9.10 Señalización vertical y horizontal

El escenario incorpora varios tipos de señalización. Entre ellos:

- señales de STOP,
- señales de glorieta,
- señales de YIELD,
- cruces peatonales,
- líneas guía blancas.

Por ejemplo, las señales de STOP se generan mediante:

```matlab
myStopSign = QLabsStopSign(qlabs);

myStopSign.spawn_degrees([-1.5, 3.6, 0.006], ...
                        [0, 0, -35], ...
                        [0.1, 0.1, 0.1], ...
                        false);
```

y los cruces peatonales mediante:

```matlab
myCrossWalk = QLabsCrosswalk(qlabs);
myCrossWalk.spawn_degrees([-2 + x_offset, -1.475 + y_offset, 0.01], ...
                          [0,0,0], ...
                          [0.1,0.1,0.075], ...
                          0);
```

La presencia explícita de estos elementos es clave, ya que el modelo de percepción y la lógica de tránsito del vehículo dependen directamente de ellos. En otras palabras, el escenario fue diseñado para contener exactamente los objetos que el pipeline de self-driving necesita detectar e interpretar.

### 9.11 Persona estática para simulación de pickup

```matlab
hPersonStatic = QLabsPerson(qlabs);

loc_persona = [-0.424, 4.55, 0.005];
rot_persona = [0, 0, -90];
scale_persona = [0.1, 0.1, 0.1];
id_persona = 10;
config_persona = 11;

hStatus = hPersonStatic.spawn_id_degrees(id_persona, loc_persona, rot_persona, scale_persona, config_persona, true);
```

Esta persona estática representa al pasajero que el vehículo debe simular recoger. Su ubicación sobre la banqueta es intencional, ya que obliga al sistema a distinguir entre una persona esperando en un punto de recogida y un peatón cruzando activamente la calle.

Desde el punto de vista del proyecto, este actor introduce una lógica de alto nivel relacionada con el caso de uso taxi autónomo.

### 9.12 Persona dinámica cruzando la calle

```matlab
hPersonObstacle = QLabsPerson(qlabs);
LOC_A_OBSTACULO = [1.441, 0.62, 0.005]; 
LOC_B_OBSTACULO = [1.441, 0.81, 0.005]; 

hPersonObstacle.spawn_id_degrees(20, LOC_A_OBSTACULO, [0, 0, -180], [0.1, 0.1, 0.1], 11, true);
```

Este peatón es el actor que cruza repetidamente un paso peatonal. Su función es alimentar la lógica de frenado y validación peatonal del vehículo. El hecho de que se le asigne un identificador propio (`ID 20`) permite que el controlador dinámico lo localice y actualice su posición de forma consistente.

### 9.13 Obstáculo tipo cono

```matlab
hTrafficCone = QLabsTrafficCone(qlabs);

loc_cone = [2.221, 1.017, 0.25];
rot_cone = [0, 0, 0];
scale_cone = [0.2, 0.2, 0.2];
id_cone = 101;

hStatusCone = hTrafficCone.spawn_id_degrees(id_cone, loc_cone, rot_cone, scale_cone, 0, true);
```

El cono representa un obstáculo físico de la competencia y es precisamente el objeto que activa la función de evasión `avoidCone`. Su colocación en el mapa permite introducir un evento local de obstrucción que obliga al vehículo a apartarse temporalmente de la trayectoria nominal.

Desde el punto de vista experimental, este actor es muy valioso porque permite validar una reacción local de navegación sin tener que rediseñar la ruta global.

### 9.14 Cámaras del entorno

El script también genera cámaras libres para observación y depuración:

```matlab
camera1Loc = [0.15, 1.7, 5];
camera1Rot = [0, 90, 0];
camera1 = QLabsFreeCamera(qlabs);
camera1.spawn_degrees(camera1Loc, camera1Rot);

camera1.possess();
```

y otra cámara lateral:

```matlab
camera2Loc = [-0.36+ x_offset, -3.691+ y_offset, 2.652];
camera2Rot = [0, 47, 90];
camera2=QLabsFreeCamera(qlabs);
camera2.spawn_degrees (camera2Loc, camera2Rot);
```

Estas cámaras no forman parte de la lógica autónoma del vehículo, pero sí son muy importantes para documentar resultados, inspeccionar la escena y verificar visualmente el comportamiento del sistema durante la simulación.

### 9.15 Spawn final del QCar y arranque del modelo RT

El vehículo puede spawnearse en dos posiciones definidas:

```matlab
calibration_location_rotation = [0, 2.13, 0.005, 0, 0, -90];
taxi_hub_location_rotation = [-1.205, -0.83, 0.005, 0, 0, -44.7];
```

y después se selecciona una de ellas según `spawn_location`:

```matlab
myCar = QLabsQCar2(qlabs);

switch spawn_location
    case 1
        spawn = calibration_location_rotation;
    case 2
        spawn = taxi_hub_location_rotation;
end

myCar.spawn_id_degrees(0, spawn(1:3), spawn(4:6), [1/10, 1/10, 1/10], 1);
```

Posteriormente se inicia el modelo RT asociado al QCar:

```matlab
file_workspace = fullfile(getenv('RTMODELS_DIR'), 'QCar2', 'QCar2_Workspace_studio.rt-win64');
pause(2)
system(['quarc_run -D -r -t tcpip://localhost:17000 ', file_workspace]);
pause(3)
```

y finalmente se activa el controlador de tráfico:

```matlab
trafficLightController(qlabs)
```

Con ello, el escenario completo queda operativo: el mapa existe, las señales están colocadas, el peatón dinámico cruza la calle, la persona estática espera en la banqueta, el cono está presente en el circuito y el QCar queda listo para ejecutar el algoritmo de self-driving.

## Papel de esta sección dentro del sistema completo

Esta sección cumple un rol crítico porque proporciona el contexto experimental en el cual se valida todo el sistema autónomo. Sin un escenario bien definido, los módulos de percepción, decisión y control no tendrían un entorno significativo sobre el cual operar. Aquí se construye precisamente ese entorno: uno que no solo contiene geometría, sino también lógica dinámica y estímulos relevantes para la competencia.

En otras palabras, esta sección materializa el mundo donde se prueba el algoritmo. Gracias a ella, la validación del sistema no se realiza en una escena vacía, sino en un entorno estructurado que incorpora reglas viales, eventos peatonales, obstáculos y elementos de interacción tipo taxi autónomo.