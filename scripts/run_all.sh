#!/usr/bin/env bash
set -euo pipefail

# Pipeline de extremo a extremo:
# 1) Generar datasets en data/input/{N}_data.csv
# 2) Compilar binarios C++
# 3) Ejecutar benchmark (10 repeticiones, serial + variantes OMP)
# 4) Graficar speedups en results/plots/

# Permite pasar Ns como argumentos. Si no se pasan, usa el conjunto por defecto.
if (( $# > 0 )); then
  Ns=("$@")
else
  Ns=(20000 40000 80000 120000 140000 160000 180000 200000)
fi

echo "Ns a procesar: ${Ns[*]}"

echo "[1/4] Generando datasets en data/input/"
mkdir -p data/input data/output results

for N in "${Ns[@]}"; do
    out="data/input/${N}_data.csv"
    python3 - <<PY "$N" "$out"
    import sys, os
    import numpy as np

    N = int(sys.argv[1])
    out = sys.argv[2]
    os.makedirs(os.path.dirname(out), exist_ok=True)

    rng = np.random.default_rng(11)
    K = 4
    centers = rng.uniform(0.2, 0.8, size=(K, 2))
    std = 0.06
    counts = [N // K] * K
    counts[0] += N - sum(counts)

    pts_list = []
    for k in range(K):
        pts = rng.normal(loc=centers[k], scale=std, size=(counts[k], 2))
        pts = np.clip(pts, 0.0, 1.0)
        pts_list.append(pts)

    pts = np.vstack(pts_list)
    pts = np.round(pts, 3)
    np.savetxt(out, pts, delimiter=",", fmt="%.3f")
    print(f"OK -> {out}")
    PY
done

echo "[2/4] Compilando (Release)"
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release -j

echo "[3/4] Ejecutando benchmark"
bash scripts/run_bench.sh

echo "[4/4] Graficando speedups"
python3 scripts/plot_speedup.py

echo "Listo. Revisa: results/times.csv y results/plots/*.png"
