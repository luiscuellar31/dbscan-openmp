# Uso de IA en el proyecto

Esta entrega utilizó asistencia de IA únicamente para acelerar tareas auxiliares: organización del repositorio, automatización por shell y Python, y generación de CSV/figuras. El algoritmo DBSCAN (versión serial) y las dos variantes OpenMP fueron implementados y verificados manualmente.

## ¿Qué generó la IA?

- Scripts y automatizaciones para manejar el flujo de trabajo:
  - `scripts/run_bench.sh` (rejilla de N e hilos, 10 repeticiones, volcado de tiempos).
  - `scripts/plot_results.py` (visualización de puntos y etiquetas), `scripts/plot_speedup.py` (cálculo y gráficas de speedup).
  - `scripts/run_all.sh` (pipeline de extremo a extremo: generar datasets, compilar, bench y gráficas).
  - Ajustes de rutas en `scripts/DBSCAN_noise.ipynb` para guardar/leer en `data/input` y `data/output`.
- Pequeñas mejoras de documentación y estructura para facilitar el uso (README/docs y convenciones de E/S).

## ¿Qué se validó manualmente?

- Que los scripts no alteran la lógica del algoritmo y producen archivos en las rutas esperadas.
- Que las figuras y resúmenes reflejan los datos de `results/times.csv` y los CSV `{N}_results.csv` generados por los binarios.
- Compilación en Release y ejecución correcta de los tres binarios (serial y dos OMP) en el entorno objetivo.

## Límites y responsabilidad

- La IA no generó el núcleo algorítmico: la lógica de DBSCAN (serial) y las directivas OpenMP fueron desarrolladas y comprobadas manualmente.
- Toda salida asistida por IA (scripts, ajustes de rutas y documentación) fue revisada y, de ser necesario, corregida para adecuarse a los requisitos del curso.

### Referencias de uso responsable de IA generativa

- IEEE Guidelines for Generative AI Usage: guías de transparencia, responsabilidad y documentación del uso de IA generativa.
- Elsevier Generative AI policies: lineamientos sobre declaración del uso, verificación humana y asunción de responsabilidad.

Se declara explícitamente el apoyo de IA generativa para tareas de orquestación y documentación. La responsabilidad por el código, su corrección y la evaluación experimental recae en el autor.
