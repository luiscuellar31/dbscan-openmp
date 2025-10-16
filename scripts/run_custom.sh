#!/usr/bin/env bash
set -euo pipefail

# Ejecuta el pipeline para un solo CSV personalizado:
# - Compila (Release)
# - Corre serial y las dos variantes OMP sobre el CSV
# - Genera plots de los resultados
#
# Uso:
#   bash scripts/run_custom.sh [ruta_csv] [hilos]
#
# Si no pasas ruta_csv, toma el CSV más reciente en data/input/extra/*.csv
# Si no pasas hilos, detecta el número de lógicos del sistema.

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
threads="${2:-}"

mkdir -p data/input/extra data/output results

if [[ -z "$csv_in" ]]; then
  # Tomar el CSV más reciente en data/input/extra
  mapfile -t csvs < <(ls -1t data/input/extra/*.csv 2>/dev/null || true)
  if (( ${#csvs[@]} == 0 )); then
    echo "No se encontró CSV en data/input/extra/. Pasa la ruta o coloca un archivo ahí." >&2
    exit 1
  fi
  csv_in="${csvs[0]}"
fi

if [[ ! -f "$csv_in" ]]; then
  echo "CSV no encontrado: $csv_in" >&2
  exit 1
fi

if [[ -z "$threads" ]]; then
  threads=$(detect_hw_threads)
fi

echo "CSV de entrada: $csv_in"
echo "Hilos OMP: $threads"

echo "[1/3] Compilando (Release)"
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

out_serial="data/output/${base}_serial_results.csv"
out_indiv="data/output/${base}_indivisible_results.csv"
out_cuads="data/output/${base}_cuadrantes_results.csv"

echo "[2/3] Ejecutando DBSCAN (serial y OMP)"
"$BIN_SERIAL" "$csv_in" "$out_serial"
OMP_NUM_THREADS="$threads" "$BIN_INDIV" "$csv_in" "$out_indiv"
OMP_NUM_THREADS="$threads" "$BIN_CUADS" "$csv_in" "$out_cuads"

echo "[3/3] Graficando resultados"
python3 scripts/plot_results.py "$out_serial" || true
python3 scripts/plot_results.py "$out_indiv" || true
python3 scripts/plot_results.py "$out_cuads" || true

echo "Listo. Archivos generados:"
printf " - %s\n" "$out_serial" "$out_indiv" "$out_cuads"
echo "PNGs junto a cada CSV."

