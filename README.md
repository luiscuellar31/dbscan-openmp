# DBSCAN OpenMP — Guía de uso

Proyecto de DBSCAN 2D O(N²) con tres ejecutables (serial y dos variantes OpenMP), scripts para generar datos, correr benchmarks y graficar speedups y resultados.

Salidas del algoritmo: CSV `idx,x,y,label` donde `label >= 0` son clusters y `-2` es ruido.

## Requisitos

- CMake ≥ 3.16, compilador C++20 (GCC/Clang/MSVC) con OpenMP.
- macOS: `brew install libomp` (Apple Silicon suele ubicarse en `/opt/homebrew`).
- Python 3 con `numpy`, `pandas`, `matplotlib` para scripts.

## Compilación

```
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j
```

Binarios generados en `build/`:
- `dbscan_serial`
- `dbscan_omp_indivisible`
- `dbscan_omp_cuadrantes`

## Uso rápido (todo en uno)

```
bash scripts/run_all.sh
# o solo para algunos tamaños
bash scripts/run_all.sh 20000 40000 80000 120000
```

El script:
- Genera `data/input/{N}_data.csv` para N ∈ {20000, 40000, 80000, 120000, 140000, 160000, 180000, 200000}
- Compila en Release
- Ejecuta el benchmark (10 repeticiones por combinación) y guarda `results/times.csv`
- Genera gráficas de speedup en `results/plots/` y un resumen en `results/speedup_summary.csv`
Nota: si pasas tamaños como argumentos, solo procesa esos N.

## Ejecutar manualmente

1) Generar datos (opción notebook o snippet)
- Notebook: abre `scripts/DBSCAN_noise.ipynb` y ejecuta la primera celda (crea `data/input/{N}_data.csv`).

2) DBSCAN (serial y OMP)

```
./build/dbscan_serial data/input/4000_data.csv
OMP_NUM_THREADS=4 ./build/dbscan_omp_indivisible data/input/4000_data.csv
OMP_NUM_THREADS=4 ./build/dbscan_omp_cuadrantes data/input/4000_data.csv
```

Si no especificas salida, se deriva automáticamente como `data/output/{N}_results.csv`.

3) Visualizar resultados del clustering

```
python3 scripts/plot_results.py data/input/4000_data.csv
```

Genera `data/output/4000_results.png` coloreando clusters y ruido (-2) en gris.

## CSV personalizado (flujo rápido)

Coloca el archivo CSV en `data/input/extra/` (por ejemplo, `data/input/extra/custom.csv`) o pásalo por argumento, y corre:

```
bash scripts/run_custom.sh data/input/extra/custom.csv 8
# o sin argumentos (toma el CSV más reciente en data/input/extra y detecta hilos)
bash scripts/run_custom.sh
```

El script compila, ejecuta `dbscan_serial`, `dbscan_omp_indivisible` y `dbscan_omp_cuadrantes` sobre ese CSV, 
genera `data/output/<base>_{serial|indivisible|cuadrantes}_results.csv` y sus PNGs correspondientes.

## Benchmark y speedup

1) Asegúrate de tener datasets en `data/input/{N}_data.csv`.
2) Ejecuta el benchmark (10 repeticiones, serial + OMP, hilos {1, V/2, V, 2V}):

```
bash scripts/run_bench.sh
```

3) Graficar speedup:

```
python3 scripts/plot_speedup.py
```

Salidas:
- `results/times.csv` (crudo)
- `results/speedup_summary.csv` (promedios + speedups)
- `results/plots/speedup_N*.png` (incluye línea verde Serial = 1.0)

## Estructura del repositorio

- `src/`: `dbscan_serial.cpp`, `dbscan_omp_indivisible.cpp`, `dbscan_omp_cuadrantes.cpp`
- `scripts/`: `run_all.sh`, `run_bench.sh`, `plot_speedup.py`, `plot_results.py`, `DBSCAN_noise.ipynb`
- `data/`: `input/` (datasets), `output/` (resultados `{N}_results.csv` y PNGs)
- `results/`: `times.csv`, `speedup_summary.csv`, `plots/`
- `docs/`: `code_overview.md`, `eval_experimental.md`, `uso_ia.md`

## Notas

- En macOS (AppleClang), OpenMP se habilita enlazando `libomp` de Homebrew (ya contemplado en CMake). Si tienes Homebrew en `/usr/local` exporta `HOMEBREW_PREFIX=/usr/local` antes de configurar.
- La expansión de clúster (BFS) es secuencial en todas las variantes; el speedup proviene del pre-cálculo paralelo de vecinos.
