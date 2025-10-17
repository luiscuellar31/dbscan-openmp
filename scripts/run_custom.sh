#!/usr/bin/env bash
set -euo pipefail

# Ejecuta el pipeline para un solo CSV personalizado y genera
# únicamente un gráfico de speedup (Serial vs OMP Indivisible y OMP Cuadrantes)
# usando hilos {1, 2, 4, 8, 16}.
#
# Uso:
#   bash scripts/run_custom.sh [ruta_csv]
#
# Si no pasas ruta_csv, toma el CSV más reciente en data/input/extra/*.csv
# Nota: Este script ignora el número de hilos del sistema y SIEMPRE mide 1,2,4,8,16.

detect_hw_threads() {
  if command -v sysctl >/dev/null 2>&1; then
    local value
    value=$(sysctl -n hw.logicalcpu 2>/dev/null || echo "")
    if [[ -n "$value" ]]; then
      echo "$value"; return
    fi
  fi
  if command -v nproc >/dev/null 2>&1; then
    nproc; return
  fi
  echo 4
}

build_dir="build"
csv_in="${1:-}"
# Permitir controlar repeticiones vía variable de entorno (por defecto 1 - modo rápido)
REPEATS="${REPEATS:-1}"

mkdir -p data/input/extra data/output results

if [[ -z "$csv_in" ]]; then
  # Tomar el CSV más reciente en data/input/extra (compatible con bash 3.x en macOS)
  latest=$(ls -1t data/input/extra/*.csv 2>/dev/null | head -n 1)
  if [[ -z "$latest" ]]; then
    echo "No se encontró CSV en data/input/extra/. Pasa la ruta o coloca un archivo ahí." >&2
    exit 1
  fi
  csv_in="$latest"
fi

if [[ ! -f "$csv_in" ]]; then
  echo "CSV no encontrado: $csv_in" >&2
  exit 1
fi

echo "CSV de entrada: $csv_in"

echo "[1/2] Compilando (Release)"
cmake -S . -B "$build_dir" -DCMAKE_BUILD_TYPE=Release >/dev/null
cmake --build "$build_dir" --config Release -j >/dev/null

BIN_SERIAL="$build_dir/dbscan_serial"
BIN_INDIV="$build_dir/dbscan_omp_indivisible"
BIN_CUADS="$build_dir/dbscan_omp_cuadrantes"

for b in "$BIN_SERIAL" "$BIN_INDIV" "$BIN_CUADS"; do
  if [[ ! -x "$b" ]]; then
    echo "No se encontró ejecutable: $b" >&2
    exit 1
  fi
done

# Base de salida
fname=$(basename -- "$csv_in")
base="$fname"
if [[ "$base" == *_data.csv ]]; then
  base="${base%_data.csv}"
elif [[ "$base" == *.csv ]]; then
  base="${base%.csv}"
fi

echo "[2/2] Ejecutando benchmark (1,2,4,8,16) y graficando speedup"

# Función Python para medir tiempo de ejecución
run_timer() {
  local bin_path="$1"; shift
  local omp_threads="$1"; shift
  local export_omp="$1"; shift
  python3 - "$bin_path" "$omp_threads" "$export_omp" "$@" <<'PY'
import os, subprocess, sys, time
bin_path, omp_threads, export_omp, *rest = sys.argv[1:]
env = os.environ.copy()
if export_omp == '1':
    env['OMP_NUM_THREADS'] = omp_threads
start = time.perf_counter()
subprocess.run([bin_path, *rest], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, env=env)
elapsed = time.perf_counter() - start
print(f"{elapsed:.6f}")
PY
}

# Determinar N para el reporte: si el nombre base es numérico lo usamos, si no contamos filas válidas
N="$base"
if ! [[ "$N" =~ ^[0-9]+$ ]]; then
  N=$(python3 - <<PY "$csv_in"
import sys
path=sys.argv[1]
cnt=0
with open(path,'r',encoding='utf-8',errors='ignore') as f:
    for line in f:
        s=line.strip()
        if not s: continue
        s=s.replace(';',',').replace(',', ' ')
        parts=s.split()
        if len(parts)>=2:
            try:
                float(parts[0]); float(parts[1]); cnt+=1
            except: pass
print(cnt)
PY
)
fi

### Registrar tiempos en un CSV dedicado a custom
mkdir -p results
results_csv="results/custom_times.csv"
echo "mode,N,threads,run,seconds" > "$results_csv"

# Lista fija para evaluar escalamiento típico
THREADS_LIST=(1 2 4 8 16)

# Serial (siempre 1 hilo), REPEATS repeticiones
for run in $(seq 1 "$REPEATS"); do
  secs=$(run_timer "$BIN_SERIAL" "1" "0" "$csv_in" "/dev/null")
  printf "serial,%d,%d,%d,%.6f\n" "$N" 1 "$run" "$secs" >> "$results_csv"
done

# OMP: indivisible y cuadrantes, por lista de hilos, REPEATS repeticiones
for mode in omp_indivisible omp_cuadrantes; do
  bin_path="$BIN_INDIV"
  [[ "$mode" == "omp_cuadrantes" ]] && bin_path="$BIN_CUADS"
  for th in "${THREADS_LIST[@]}"; do
    for run in $(seq 1 "$REPEATS"); do
      # No se requiere generar CSVs de resultados de clustering; solo medir tiempo.
      secs=$(run_timer "$bin_path" "$th" "1" "$csv_in" "/dev/null")
      printf "%s,%d,%d,%d,%.6f\n" "$mode" "$N" "$th" "$run" "$secs" >> "$results_csv"
    done
  done
done

# Graficar speedup SOLO basado en el CSV custom
if python3 scripts/plot_speedup.py "$results_csv" --outdir results/plots/extra --summary results/custom_speedup_summary.csv; then
  echo "Gráfico de speedup generado en: results/plots/extra/ (archivo speedup_N${N}.png)"
else
  echo "Error al generar el gráfico de speedup (ver mensaje anterior)." >&2
fi

echo "Listo. CSV de tiempos: $results_csv"
