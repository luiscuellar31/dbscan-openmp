#!/usr/bin/env bash
set -euo pipefail

build_dir="${1:-build}"

mkdir -p "$build_dir" data/output results

cmake -S . -B "$build_dir" -DCMAKE_BUILD_TYPE=Release
cmake --build "$build_dir" --config Release -j

detect_bin() {
    local name="$1"
    if [[ -x "${build_dir}/${name}" ]]; then
        printf "%s/%s" "${build_dir}" "${name}"
    elif [[ -x "${build_dir}/Release/${name}" ]]; then
        printf "%s/Release/%s" "${build_dir}" "${name}"
    else
        echo "No se encontró el binario ${name} dentro de ${build_dir}. Ejecuta la compilación primero." >&2
        exit 1
    fi
}

BIN_SERIAL=$(detect_bin "dbscan_serial")
BIN_INDIV=$(detect_bin "dbscan_omp_indivisible")
BIN_CUADS=$(detect_bin "dbscan_omp_cuadrantes")

# Descubrir Ns desde data/input/*_data.csv si existen; si no, usar lista por defecto
if compgen -G "data/input/*_data.csv" >/dev/null 2>&1; then
    Ns=()
    for f in data/input/*_data.csv; do
        b=$(basename "$f")
        n=${b%%_*}
        if [[ "$n" =~ ^[0-9]+$ ]]; then
            Ns+=("$n")
        fi
    done
    # Ordenar y deduplicar
    IFS=$'\n' Ns=($(printf "%s\n" "${Ns[@]}" | sort -n | uniq)); IFS=' '
else
    Ns=(20000 40000 80000 120000 140000 160000 180000 200000)
fi

detect_hw_threads() {
    if command -v sysctl >/dev/null 2>&1; then
        local value
        value=$(sysctl -n hw.logicalcpu 2>/dev/null || echo "")
        if [[ -n "$value" ]]; then
            echo "$value"
            return
        fi
    fi
    if command -v nproc >/dev/null 2>&1; then
        nproc
    else
        echo 4
    fi
}

logical=$(detect_hw_threads)
half=$(( logical / 2 ))
if (( half < 1 )); then
    half=1
fi
double=$(( logical * 2 ))

THREADS_LIST=(1 "${half}" "${logical}" "${double}")

uniq_threads=()
for t in "${THREADS_LIST[@]}"; do
    skip=false
    if (( ${#uniq_threads[@]} )); then
        for seen in "${uniq_threads[@]}"; do
            if [[ "$t" -eq "$seen" ]]; then
                skip=true
                break
            fi
        done
    fi
    if ! $skip; then
        uniq_threads+=("$t")
    fi
done
THREADS_LIST=("${uniq_threads[@]}")

results_csv="results/times.csv"
echo "mode,N,threads,run,seconds" > "$results_csv"

run_python_timer() {
    local bin_path="$1"
    local in_csv="$2"
    local out_csv="$3"
    local threads="$4"
    local export_threads="$5"
    python3 - "$bin_path" "$in_csv" "$out_csv" "$threads" "$export_threads" <<'PY'
    import os
    import subprocess
    import sys
    import time

    bin_path, in_csv, out_csv, threads, export_threads = sys.argv[1:]

    cmd = [bin_path, in_csv, out_csv]
    env = os.environ.copy()
    if export_threads == "1":
        env["OMP_NUM_THREADS"] = threads

    start = time.perf_counter()
    subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, env=env)
    elapsed = time.perf_counter() - start
    print(f"{elapsed:.6f}")
PY
}

for N in "${Ns[@]}"; do
    in_csv="data/input/${N}_data.csv"
    if [[ ! -f "$in_csv" ]]; then
        echo "Aviso: no existe ${in_csv}, se omite N=${N}" >&2
        continue
    fi

    for run in {1..10}; do
        out_csv="data/output/serial_${N}_run${run}.csv"
        secs=$(run_python_timer "$BIN_SERIAL" "$in_csv" "$out_csv" "1" "0")
        printf "serial,%d,%d,%d,%.6f\n" "$N" 1 "$run" "$secs" >> "$results_csv"
    done

    for mode in "omp_indivisible" "omp_cuadrantes"; do
        if [[ "$mode" == "omp_indivisible" ]]; then
            bin_path="$BIN_INDIV"
        else
            bin_path="$BIN_CUADS"
        fi

        for threads in "${THREADS_LIST[@]}"; do
            for run in {1..10}; do
                out_csv="data/output/${mode}_${N}_${threads}_run${run}.csv"
                secs=$(run_python_timer "$bin_path" "$in_csv" "$out_csv" "$threads" "1")
                printf "%s,%d,%d,%d,%.6f\n" "$mode" "$N" "$threads" "$run" "$secs" >> "$results_csv"
            done
        done
    done
done

echo "Listo -> $results_csv"
