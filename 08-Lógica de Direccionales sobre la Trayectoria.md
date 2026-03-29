---
layout: default
title: Lógica de Direccionales sobre la Trayectoria
nav_order: 6
parent: CPS IoT Competition 2026
permalink: /CPS/directionalLogic/
---
## Direccionales y Comportamiento Vial

### Análisis detallado del seccionamiento de la ruta para activación de direccionales

La trayectoria generada para el **QCar 2 virtual** no se utilizó únicamente como referencia geométrica de navegación, sino también como base para incorporar comportamiento vial explícito, particularmente la activación de direccionales. Esta decisión fue relevante porque, dentro de un sistema de conducción autónoma orientado a un entorno urbano, no basta con que el vehículo siga correctamente una curva o se mantenga cerca de una trayectoria objetivo; también debe comunicar visualmente sus maniobras cuando entra, sale o cruza intersecciones, cuando cambia de rama dentro de la red vial del mapa o cuando ejecuta un giro reglamentario claramente identificable.

Por esta razón, una vez obtenida la trayectoria global suavizada mediante planeación sobre grafo e interpolación **PCHIP**, se realizó un proceso adicional de segmentación de la ruta. Dicho proceso consistió en determinar qué partes de la trayectoria correspondían a maniobras donde debía encenderse la direccional izquierda y cuáles correspondían a maniobras donde debía encenderse la direccional derecha. Esta capa de procesamiento permitió que el vehículo no solo recorriera el mapa de manera correcta, sino que además lo hiciera con una lógica de señalización coherente con las reglas viales definidas para el entorno.

---

### Ejemplo de trayectoria generada del nodo 1 al nodo 30

Como ejemplo de planeación, se presenta una trayectoria calculada entre el **nodo 1** y el **nodo 30**. La figura siguiente muestra la ruta final obtenida para ese recorrido.

![Trayectoria global del nodo 1 al nodo 30](/assets/img/TrayectoriaNodo1a30.jpeg)

**Figura.** Trayectoria global generada como ejemplo de planeación entre el **nodo 1** y el **nodo 30**. La curva roja representa la trayectoria final suavizada que seguiría el **QCar 2 virtual**, mientras que el contorno punteado negro corresponde al marco geométrico de referencia del entorno.

En esta figura se aprecia que la trayectoria recorre una parte importante del circuito, pasando por tramos rectos, curvas amplias y una zona central de mayor complejidad geométrica. Esto confirma que la planeación no produce una simple conexión lineal entre origen y destino, sino una ruta continua físicamente consistente con la topología del mapa. Desde el punto de vista del control, esta curva roja es la referencia nominal que seguiría el vehículo en ausencia de eventos externos como señales, peatones u obstáculos.

Sin embargo, para la lógica de direccionales no basta con conocer la forma global de la trayectoria. Aunque esta curva es continua, la señalización de giro debe decidirse con base en el significado vial de ciertos tramos del camino y no simplemente en la presencia de curvatura. En consecuencia, fue necesario construir una lógica adicional capaz de proyectar reglas de tránsito, definidas originalmente sobre nodos discretos del grafo, sobre la trayectoria continua que realmente sigue el vehículo.

---

### Criterio general para definir las reglas de direccionales

Las reglas de direccionales no se definieron con un criterio geométrico simplista del tipo “si la curva va a la izquierda, entonces prende izquierda” o “si el camino se curva a la derecha, entonces prende derecha”. Ese enfoque habría sido demasiado burdo, ya que una trayectoria suavizada puede presentar curvatura local por razones puramente geométricas sin que ello represente una maniobra vial que deba ser anunciada con una direccional.

Por ejemplo, un vehículo puede recorrer una curva suave simplemente siguiendo la forma natural del carril, sin cambiar de rama ni atravesar una intersección. En ese caso, aunque geométricamente la trayectoria sea curva, vialmente no necesariamente existe una maniobra reglamentaria que requiera señalización. Por el contrario, sí existen transiciones entre nodos del grafo que representan decisiones viales explícitas, tales como:

- incorporarse a una nueva rama del mapa,
- atravesar una intersección,
- abandonar una trayectoria principal para tomar una salida,
- cambiar entre un lazo exterior y uno interior,
- completar un giro prolongado donde la direccional debe mantenerse encendida durante varios subtramos consecutivos.

Por esta razón, las reglas fueron definidas sobre la **topología del mapa**, es decir, sobre las transiciones discretas entre nodos que verdaderamente representan maniobras de tránsito.

---

### Reglas de tránsito para activación de direccionales

Las reglas definidas para el encendido de direccionales fueron las siguientes.

#### Reglas para direccional izquierda

- 7 → 8  
- 8 → 9  
- 15 → AUX  
- AUX → 24  
- 17 → 6  
- 23 → AUX  
- AUX → 32  
- 27 → 7  
- 31 → AUX  
- AUX → 45  
- 44 → AUX  
- AUX → 16  

#### Reglas para direccional derecha

- 9 → 41  
- 13 → 46  
- 15 → 45  
- 17 → 18  
- 23 → 16  
- 26 → 27  
- 27 → 28  
- 31 → 25  
- 39 → 40  
- 40 → 41  
- 41 → 42  
- 44 → 32  
- 45 → 3  

---

### Nodo auxiliar AUX

En estas reglas, el símbolo **AUX** corresponde al **nodo 48**, ubicado en el centro de la intersección principal del mapa. Este nodo no forma parte de la estructura mínima original del grafo, sino que fue introducido como un nodo auxiliar para mejorar la representación geométrica y semántica de ciertos cruces, principalmente los giros izquierdos más complejos.

La importancia de este nodo es considerable. Si una maniobra de cruce izquierdo se representara directamente entre dos nodos extremos, la trayectoria resultante podría verse demasiado abrupta, poco natural o incluso poco representativa de cómo un vehículo realmente atraviesa una intersección. Al forzar el paso de la trayectoria por el nodo auxiliar central, se consigue que la curva se desarrolle de manera más progresiva y que el tramo donde la direccional permanece activa se extienda a lo largo de toda la maniobra, y no únicamente en el instante de conexión entre dos ramas.

En otras palabras, el nodo **AUX = 48** mejora simultáneamente dos aspectos del sistema:

1. la **geometría** del giro, al suavizar cruces complejos,  
2. la **semántica vial** de la señalización, al hacer que la direccional cubra una maniobra más realista.

---

## Justificación topológica y vial de las reglas izquierdas

### 7 → 8 y 8 → 9

Estas dos transiciones fueron clasificadas como una misma maniobra de direccional izquierda porque representan una incorporación continua en la parte superior del mapa. No se trató de una activación puntual sobre un único vértice, sino de una maniobra prolongada que abarca dos subtramos consecutivos. Desde una perspectiva vial, esta decisión es más correcta que prender y apagar la direccional en un solo punto, ya que el vehículo mantiene un cambio sostenido de orientación hasta alinearse con el siguiente tramo principal del circuito.

### 15 → AUX y AUX → 24

Este caso representa uno de los cruces izquierdos más importantes de la intersección central. El vehículo entra a la intersección desde una rama, atraviesa el centro y sale hacia otra rama con un giro claro hacia la izquierda. Aquí el nodo auxiliar es esencial, ya que divide la maniobra en dos fases: aproximación al centro y salida desde el centro hacia la rama objetivo. Esto permite que la direccional permanezca encendida durante toda la travesía de la intersección y no solo en el instante puntual del cruce.

### 17 → 6

Esta transición fue etiquetada como una maniobra de izquierda porque, dentro de la lógica topológica del mapa, representa una incorporación desde una rama interna hacia otra rama principal. Aunque geométricamente la conexión pueda parecer una curva moderada, vialmente implica dejar una trayectoria para incorporarse a otra, lo que justifica la activación de la direccional.

### 23 → AUX y AUX → 32

Este caso es análogo al cruce `15 → AUX → 24`, pero aplicado a otra transición dentro de la intersección central. Nuevamente, el vehículo atraviesa una zona de decisión topológica donde no solo cambia de orientación, sino también de rama de circulación. La división en dos segmentos alrededor del nodo AUX permite mantener la direccional encendida durante toda la maniobra de cruce izquierdo.

### 27 → 7

Esta regla representa una reincorporación desde una trayectoria interna hacia la parte superior o externa del circuito. No se trata simplemente de continuar sobre la misma rama, sino de tomar una conexión distinta dentro del mapa, motivo por el cual se interpretó como una maniobra de izquierda desde el punto de vista vial.

### 31 → AUX y AUX → 45

Este caso corresponde a otro cruce izquierdo a través del centro de la intersección. Al igual que en los casos anteriores, el uso del nodo auxiliar evita una transición abrupta entre ramas lejanas y distribuye la activación de la direccional sobre una porción más extensa y realista de la trayectoria.

### 44 → AUX y AUX → 16

Esta pareja de reglas describe otro cruce izquierdo relevante dentro del mapa. Desde el nodo 44, el vehículo puede entrar al centro de la intersección y salir hacia otra rama, describiendo una maniobra reglamentariamente equivalente a un giro a la izquierda. El uso de AUX permite capturar esa maniobra con mayor fidelidad geométrica.

---

## Justificación topológica y vial de las reglas derechas

### 9 → 41

Esta transición representa una salida desde la parte superior del circuito hacia una rama interna. Aunque la trayectoria suavizada pueda describir este cambio con continuidad, desde la topología del grafo esta conexión constituye una decisión vial concreta: abandonar la trayectoria en la que se venía y tomar otra rama. Por ello se marcó como maniobra de direccional derecha.

### 13 → 46

Esta conexión corresponde a una salida lateral en la zona izquierda del mapa, donde el vehículo deja la rama vertical principal para ingresar a un conector alternativo. Se trata de una maniobra corta, pero claramente significativa desde el punto de vista reglamentario.

### 15 → 45

Esta transición es especialmente interesante porque comparte nodo de origen con la maniobra `15 → AUX → 24`, pero representa una salida distinta. Desde el nodo 15, el vehículo puede optar por dos caminos diferentes dentro de la intersección: uno asociado a un cruce izquierdo y otro asociado a una salida hacia la derecha. Esto demuestra que la lógica de direccionales no depende del nodo aislado, sino de la transición específica entre nodos.

### 17 → 18

Esta transición representa la entrada del vehículo a una rama descendente situada en la parte derecha del mapa. El cambio de orientación y de rama es lo suficientemente claro como para ser interpretado como una maniobra de derecha.

### 23 → 16

Este caso es la alternativa derecha al cruce izquierdo `23 → AUX → 32`. Desde el nodo 23, el vehículo puede dirigirse hacia distintas ramas, y cada una de esas salidas tiene una semántica vial diferente. La transición hacia 16 fue interpretada como una maniobra de derecha.

### 26 → 27 y 27 → 28

Estas dos transiciones consecutivas fueron agrupadas como una misma maniobra prolongada de direccional derecha. La lógica aquí es equivalente a la de los segmentos largos izquierdos: mantener la señal encendida durante todo el desarrollo de la maniobra y no únicamente en uno de sus vértices.

### 31 → 25

Esta conexión representa otra salida desde una rama principal hacia una trayectoria distinta. Se clasificó como derecha porque el vehículo abandona su flujo actual para incorporarse a otra dirección de circulación dentro del mapa.

### 39 → 40, 40 → 41 y 41 → 42

Este conjunto de tres segmentos es uno de los mejores ejemplos de maniobra prolongada. En lugar de una activación puntual, se decidió mantener la direccional derecha encendida a través de tres subtramos consecutivos, de modo que todo el cambio de rama quedara correctamente señalizado. Esto demuestra que el sistema es capaz de representar maniobras largas como entidades viales continuas.

### 44 → 32

Este caso es la alternativa derecha al cruce izquierdo `44 → AUX → 16`. Desde el mismo nodo de origen, existen decisiones viales distintas, y por tanto cada transición debe tener su propia lógica de direccional. Esto refuerza la idea de que las reglas están definidas sobre el grafo dirigido y no únicamente sobre la geometría local.

### 45 → 3

Finalmente, esta transición representa una conexión desde la zona central inferior hacia otra rama del circuito. Se consideró una maniobra de derecha porque el vehículo abandona la trayectoria en la que se encontraba e ingresa a una nueva rama de circulación.

---

## Script para generar los segmentos de direccionales

Una vez definidas las reglas sobre pares de nodos, fue necesario construir un procedimiento que las tradujera a segmentos reales sobre la trayectoria suavizada. El script empleado para ello fue el siguiente:

```matlab
%% =============================
% MAPEO NODOS → INDICES EN TRAYECTORIA
% =============================

num_nodes_path = length(pathNodes_corrected);
node_to_idx = zeros(num_nodes_path,1);

search_start = 1; %  clave: evita ambigüedades
AUX = 48;

for k = 1:num_nodes_path
    
    nodo_id = pathNodes_corrected(k);
    nodo_xy = nodes(nodo_id,:);
    
    min_dist = inf;
    best_idx = search_start;
    
    for i = search_start:length(path_x_smooth)
        
        dx = path_x_smooth(i) - nodo_xy(1);
        dy = path_y_smooth(i) - nodo_xy(2);
        d = dx^2 + dy^2; % sin sqrt (más rápido)
        
        if d < min_dist
            min_dist = d;
            best_idx = i;
        end
    end
    
    node_to_idx(k) = best_idx;
    search_start = best_idx; % solo busca hacia adelante
end

%% =============================
% DEFINIR TUS REGLAS
% =============================

der = [9 41; 13 46; 15 45; 17 18; 23 16; 26 27; 27 28;
       31 25; 39 40; 40 41; 41 42; 44 32; 45 3];

izq = [7 8; 8 9; 15 AUX; AUX 24; 17 6; 23 AUX; AUX 32; 27 7; 31 AUX; AUX 45; 44 AUX; AUX 16];

%% =============================
% CREAR SEGMENTOS
% =============================

segmentos_izq = [];
segmentos_der = [];

for k = 1:length(pathNodes_corrected)-1
    
    n1 = pathNodes_corrected(k);
    n2 = pathNodes_corrected(k+1);
    
    idx1 = node_to_idx(k);
    idx2 = node_to_idx(k+1);
    
    segmento = [min(idx1,idx2), max(idx1,idx2)];
    
    % Verificar si este tramo está en tus reglas
    
    if any(all(izq == [n1 n2],2))
        segmentos_izq = [segmentos_izq; segmento];
    end
    
    if any(all(der == [n1 n2],2))
        segmentos_der = [segmentos_der; segmento];
    end
    
end

%% =============================
% (OPCIONAL) UNIR SEGMENTOS CONTIGUOS
% =============================

merge_segments = @(seg) ...
    cell2mat(arrayfun(@(i) ...
    [seg(i,1), seg(find(seg(:,1)==seg(i,2),1,'first'),2)], ...
    1:size(seg,1)-1, 'UniformOutput', false)');

%% =============================
% GUARDAR
% =============================

save('segmentos_direccionales.mat', 'segmentos_izq', 'segmentos_der');

%% =============================
%  VISUALIZACIÓN 
% =============================

figure; hold on; grid on; axis equal;

h_traj = plot(path_x_smooth, path_y_smooth, 'k');

% IZQUIERDA (verde)
h_izq = [];
for i = 1:size(segmentos_izq,1)
    idx = segmentos_izq(i,1):segmentos_izq(i,2);
    h_izq = plot(path_x_smooth(idx), path_y_smooth(idx), 'g', 'LineWidth', 3);
end

% DERECHA (rojo)
h_der = [];
for i = 1:size(segmentos_der,1)
    idx = segmentos_der(i,1):segmentos_der(i,2);
    h_der = plot(path_x_smooth(idx), path_y_smooth(idx), 'r', 'LineWidth', 3);
end

legend([h_traj, h_izq, h_der], {'Path', ' left turn signal', 'right turn signal'});
````
---
## Explicación detallada del script

### 1. Mapeo de nodos a índices de la trayectoria suavizada

La trayectoria que sigue realmente el vehículo no está compuesta por nodos, sino por miles de puntos interpolados almacenados en `path_x_smooth` y `path_y_smooth`. Por ello, la primera parte del script busca asociar cada nodo de la ruta corregida con un índice real sobre la trayectoria continua.

Si se denota la trayectoria continua por:

$$
\mathcal{P} = {(x_1,y_1), (x_2,y_2), \dots, (x_M,y_M)}
$$

y cada nodo corregido por:

$$
v_k = (x_k^{node}, y_k^{node}),
$$

entonces el índice asociado a cada nodo se calcula como:

$$
i_k^\star = \arg\min_{i \ge i_{k-1}^\star}
\left[(x_i - x_k^{node})^2 + (y_i - y_k^{node})^2\right]
$$

El uso de la distancia cuadrática evita la raíz cuadrada y hace el cálculo más eficiente. Además, la variable `search_start` obliga a que la búsqueda siempre avance hacia adelante, lo que evita ambigüedades en trayectorias donde el camino se aproxima a zonas previamente recorridas.

### 2. Aplicación de reglas sobre transiciones entre nodos

Una vez obtenido el arreglo `node_to_idx`, el script recorre la secuencia `pathNodes_corrected` tomando pares consecutivos ((n_1,n_2)). Para cada transición, verifica si ese par pertenece a la lista `izq` o a la lista `der`.

Si el par pertenece a `izq`, se crea un segmento izquierdo.
Si pertenece a `der`, se crea un segmento derecho.

De esta manera, el algoritmo transforma una regla topológica discreta en un intervalo real sobre la trayectoria continua.

### 3. Construcción de segmentos

Cada tramo queda representado como un intervalo de índices:

$$
I_k = [\min(i_k^\star, i_{k+1}^\star),\ \max(i_k^\star, i_{k+1}^\star)]
$$

Esto significa que la direccional no se activa en un único punto, sino en toda una región continua de la trayectoria. Esta decisión es correcta desde el punto de vista vehicular, porque una direccional debe permanecer encendida durante el desarrollo completo de la maniobra y no solamente al cruzar un vértice del grafo.

### 4. Unión opcional de segmentos contiguos

El script propone una función opcional `merge_segments` para unir segmentos que sean contiguos. Aunque esta función no es estrictamente necesaria para la visualización básica, puede resultar útil si se desea simplificar la representación y agrupar maniobras largas en una sola región continua.

### 5. Guardado y visualización

Los segmentos resultantes se guardan en el archivo `segmentos_direccionales.mat`, lo cual permite reutilizarlos posteriormente en otros módulos del sistema, por ejemplo en el bloque de control de luces. Finalmente, el script genera una figura donde:

* la trayectoria total aparece en negro,
* los segmentos con direccional izquierda aparecen en verde,
* los segmentos con direccional derecha aparecen en rojo.

---

## Figura de seccionamiento de direccionales para el ejemplo nodo 1 al nodo 30

![Seccionamiento de la trayectoria del nodo 1 al nodo 30](/assets/img/DireccionalesNodo1a30.jpeg)

**Figura.** Seccionamiento de la trayectoria correspondiente al ejemplo de planeación entre el **nodo 1** y el **nodo 30**. La ruta completa se muestra en negro, los segmentos donde debe encenderse la direccional izquierda aparecen en verde y los segmentos donde debe encenderse la direccional derecha aparecen en rojo.

## Interpretación  del resultado

La figura de seccionamiento demuestra que la activación de direccionales no fue definida de manera arbitraria ni únicamente a partir de la curvatura visual de la trayectoria. Cada segmento coloreado corresponde a una transición del grafo cuya interpretación vial fue previamente codificada. Esto hace posible que el vehículo combine dos niveles distintos de inteligencia dentro del sistema:

1. **seguimiento geométrico**, basado en la trayectoria suavizada,
2. **comportamiento vial semántico**, basado en reglas topológicas sobre nodos.

Los segmentos verdes representan maniobras donde el vehículo debe anunciar un giro o incorporación a la izquierda, mientras que los segmentos rojos corresponden a maniobras equivalentes hacia la derecha. El hecho de que estas regiones queden localizadas exactamente sobre partes específicas de la trayectoria confirma que el mapeo entre nodos y curva interpolada fue correcto.

Además, el uso del nodo auxiliar **AUX = 48** resulta particularmente valioso en intersecciones complejas, ya que permite modelar giros izquierdos como una secuencia continua y no como una transición brusca entre nodos extremos. En consecuencia, la direccional permanece encendida durante una porción de trayectoria más representativa de la maniobra real.

En conjunto, este procedimiento fortalece considerablemente la arquitectura del proyecto, porque hace que el vehículo no solo siga una ruta de manera correcta, sino que además se comporte como un agente vial más completo, capaz de comunicar sus intenciones de movimiento mediante señales luminosas coherentes con la topología del mapa y con las reglas de tránsito definidas para el entorno.
---
