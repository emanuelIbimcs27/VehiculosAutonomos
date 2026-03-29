---
layout: default
title: CPS IoT Competition 2026
nav_order: 4
has_children: true
permalink: /CPS/
---

# Metodología de Diseño y Validación del Algoritmo de Self-Driving para la CPS IoT Competition 2026

## Introducción

El desarrollo presentado en esta sección corresponde al diseño, integración y validación de un algoritmo de conducción autónoma implementado para el entorno virtual de **Quanser City** utilizando el **QCar 2 virtual** dentro de **QLabs**, con una arquitectura principal desarrollada en **MATLAB/Simulink**. La solución fue concebida para la **CPS IoT Self-Driving Competition 2026**, tomando como base el entorno de competencia y extendiéndolo con módulos propios de planeación, percepción visual, estimación de profundidad, lógica reglamentaria y evasión de obstáculos.

Desde una perspectiva de ingeniería de sistemas autónomos, el vehículo no fue tratado como un simple bloque de seguimiento de trayectoria, sino como una arquitectura jerárquica compuesta por varias capas funcionales. En primer lugar, fue necesario definir la parametrización del vehículo virtual y las condiciones temporales de operación de cada subsistema. Posteriormente, se diseñó una estrategia de planeación global de trayectoria basada en grafos dirigidos y penalizaciones viales. Sobre esta base se incorporó un sistema de percepción visual basado en una red neuronal entrenada específicamente para detectar objetos presentes en el entorno de Quanser City. Finalmente, se añadieron módulos de interpretación espacial y toma de decisiones para que el vehículo pudiera reaccionar frente a señales y obstáculos.

Una de las contribuciones más importantes del proyecto fue el diseño de un pipeline híbrido entre Simulink y Python. Simulink se utilizó como núcleo de integración y control, mientras que Python funcionó como servicio externo de inferencia para la red neuronal exportada a ONNX. Gracias a esta estrategia, el sistema pudo recibir imágenes desde el entorno virtual, detectar objetos de interés, estimar sus distancias y modificar en tiempo real la velocidad y la dirección del vehículo.

---

## Arquitectura general de la solución

La solución implementada se estructuró en varios niveles funcionales que trabajan de manera coordinada. En el primer nivel se ubica la **parametrización del vehículo**, donde se definen tiempos de muestreo, ganancias de control, configuraciones del entorno y parámetros geométricos. En el segundo nivel se encuentra la **planeación global**, encargada de calcular una trayectoria óptima entre un nodo inicial y un nodo objetivo sobre el mapa de competencia. En el tercer nivel se ubica la **percepción visual**, implementada con una red neuronal YOLOv8 entrenada para reconocer objetos del escenario. En el cuarto nivel se incluye la **estimación de profundidad**, cuyo objetivo es transformar cada detección bidimensional en una detección con significado espacial. Finalmente, en el quinto nivel se encuentra la **toma de decisiones**, donde se implementan reglas de comportamiento frente a señales y obstáculos.

Esta arquitectura puede representarse conceptualmente como una tubería de procesamiento:

$$
\text{Mapa} \rightarrow \text{Planeación} \rightarrow \text{Percepción} \rightarrow \text{Profundidad} \rightarrow \text{Decisión} \rightarrow \text{Control}
$$

Desde el punto de vista de navegación autónoma, esta descomposición es importante porque separa claramente tres preguntas fundamentales del problema. La planeación responde **por dónde debe ir el vehículo**. La percepción responde **qué hay en el entorno**. La lógica de decisión responde **qué debe hacer el vehículo ante lo que percibe**. Esta estructura modular facilita la validación individual de cada componente y fortalece la robustez global del sistema.

