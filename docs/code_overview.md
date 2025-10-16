# Visión general del diseño y del código

El proyecto implementa un DBSCAN O(N²) sencillo sobre datos 2D, usando distancia euclidiana al cuadrado para evitar `sqrt`. Produce un CSV `idx,x,y,label` donde `label >= 0` son clusters y `-2` es ruido.

Se incluyen tres ejecutables:

1. `dbscan_serial` — implementación serial de referencia.
2. `dbscan_omp_indivisible` — paralelización sobre el índice externo (pre-cálculo de vecinos y máscara de núcleos).
3. `dbscan_omp_cuadrantes` — mismo esquema que la anterior pero usando `schedule(static)` pensado para 4 hilos (cuadrantes lógicos).

## Algoritmo base (serial)

- Para cada punto `i`, se buscan vecinos `j` con `distancia_sq(i,j) <= eps²`.
- Si `|vecinos(i)| + 1 >= minPts`, `i` es “core”; se expande el clúster con una cola (BFS) añadiendo vecinos de puntos “core”.
- La expansión BFS se mantiene secuencial en todas las variantes para evitar carreras en `clusterPertenezco` y la cola.

## Distancia euclidiana al cuadrado

- Se calcula como `(dx*dx + dy*dy)` y se compara contra `eps*eps` en las tres variantes.
- Evita la operación `sqrt`, conservando equivalencia de comparación y mejorando el rendimiento.

## Paralelización OpenMP

- `omp_indivisible`: `#pragma omp parallel for schedule(static)` sobre el bucle exterior que precalcula `vecinosLista[i]` y `esCore[i]`. La búsqueda de vecinos por punto es secuencial para cada `i` (evita paralelismo anidado y locks). Es una línea base clara y portable.
- `omp_cuadrantes`: mismo patrón con `schedule(static)` y recomendación de `OMP_NUM_THREADS=4` para emular “cuadrantes” lógicos (bloques contiguos de índices). En la práctica, con `V` hilos modernos, su rendimiento es similar a `indivisible`.
- La expansión BFS permanece secuencial en ambas (evita carreras en `clusterPertenezco` y la cola), por lo que el speedup viene principalmente del pre-cálculo de vecinos.

### Tabla comparativa (estrategias)

| Variante              | Paralelismo principal                         | Scheduling         | Escrituras compartidas | Pros                                                     | Contras                                     |
|-----------------------|-----------------------------------------------|--------------------|-------------------------|----------------------------------------------------------|---------------------------------------------|
| Serial                | Ninguno                                       | —                  | No                      | Referencia simple y determinista                         | O(N²) sin paralelismo                       |
| OMP indivisible       | `for i in [0..N)` (vecinosLista + esCore)     | `static`           | No (cada `i` es propio) | Fácil, buen balance si costo por `i` es similar          | BFS secuencial limita speedup global        |
| OMP por cuadrantes    | Igual que indivisible (bloques contiguos)     | `static` (bloques) | No (cada `i` es propio) | Mejor localidad al repartir por bloques contiguos (4 “Q”)| Beneficio depende del patrón de datos       |


## Organización del repositorio

- `src/dbscan_serial.cpp`, `src/dbscan_omp_indivisible.cpp`, `src/dbscan_omp_cuadrantes.cpp` — implementaciones.
- `scripts/run_bench.sh` — compila, recorre N y hilos, promedia 10 corridas y guarda `results/times.csv`.
- `scripts/plot_speedup.py` — genera gráficos de speedup por N usando `results/times.csv`.
- `scripts/DBSCAN_noise.ipynb` — genera puntos en `data/input/{N}_data.csv` y permite visualizar resultados desde `data/output/`.
- `docs/eval_experimental.md` — guía de experimento y reporte.
- `docs/uso_ia.md` — política de uso responsable de IA.

### Parámetros y convenciones de E/S

- Entrada por defecto: `data/input/{N}_data.csv`.
- Salida auto-derivada si no se especifica: `data/output/{N}_results.csv` (derivada del nombre de entrada) o `data/output/resultados.csv` como fallback.
- Formato de salida: `idx,x,y,label` con `label = -2` para ruido.
