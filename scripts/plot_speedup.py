import argparse
import os
from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd


LABELS = {
    "serial": "Serial",
    "omp_indivisible": "OMP Indivisible",
    "omp_cuadrantes": "OMP Cuadrantes",
}


def load_times(csv_path: Path) -> pd.DataFrame:
    if not csv_path.exists():
        raise FileNotFoundError(f"No se encontró {csv_path}")
    df = pd.read_csv(csv_path)
    expected_cols = {"mode", "N", "threads", "run", "seconds"}
    if not expected_cols.issubset(df.columns):
        raise ValueError(f"El CSV debe contener columnas {expected_cols}")
    return df


def compute_summary(df: pd.DataFrame) -> pd.DataFrame:
    grouped = (
        df.groupby(["mode", "N", "threads"], as_index=False)["seconds"]
        .mean()
        .rename(columns={"seconds": "mean_seconds"})
    )

    serial_baseline = (
        grouped[(grouped["mode"] == "serial") & (grouped["threads"] == 1)]
        .set_index("N")["mean_seconds"]
    )

    speedups = []
    for _, row in grouped.iterrows():
        n = row["N"]
        mode = row["mode"]
        mean_time = row["mean_seconds"]
        base = serial_baseline.get(n)
        if base is None or mean_time == 0.0:
            speedup = float("nan")
        else:
            speedup = base / mean_time
        speedups.append(speedup)

    grouped["speedup"] = speedups
    return grouped


def plot_speedups(summary: pd.DataFrame, out_dir: Path) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    Ns = sorted(summary["N"].unique())

    for N in Ns:
        base_row = summary[(summary["N"] == N) & (summary["mode"] == "serial") & (summary["threads"] == 1)]
        if base_row.empty:
            continue

        subset = summary[(summary["N"] == N)].copy()
        if subset.empty:
            continue

        plt.figure(figsize=(8, 5))
        # Línea de referencia Serial en verde (speedup=1.0)
        plt.axhline(1.0, color="green", linestyle="-", linewidth=2, label=LABELS.get("serial", "Serial"))

        # Graficar solo las variantes OMP (no volvemos a trazar serial para evitar duplicar)
        for mode, data in subset.groupby("mode"):
            if mode == "serial":
                continue
            data = data.sort_values("threads")
            plt.plot(
                data["threads"],
                data["speedup"],
                marker="o",
                label=LABELS.get(mode, mode),
            )
        plt.xlabel("Hilos (OMP_NUM_THREADS)")
        plt.ylabel("Speedup (vs serial)")
        plt.title(f"Speedup para N = {N}")
        plt.grid(True, linewidth=0.4, alpha=0.3)
        plt.legend()
        plt.tight_layout()

        out_path = out_dir / f"speedup_N{N}.png"
        plt.savefig(out_path, dpi=200)
        plt.close()


def main() -> None:
    parser = argparse.ArgumentParser(description="Genera gráficas de speedup a partir de results/times.csv")
    parser.add_argument(
        "csv",
        nargs="?",
        default="results/times.csv",
        help="Ruta al CSV de tiempos (por defecto results/times.csv)",
    )
    parser.add_argument(
        "--outdir",
        default="results/plots",
        help="Directorio de salida para las gráficas",
    )
    parser.add_argument(
        "--summary",
        default="results/speedup_summary.csv",
        help="Ruta para guardar tabla con promedios y speedups",
    )
    args = parser.parse_args()

    df = load_times(Path(args.csv))
    summary = compute_summary(df)
    if summary.empty:
        print("Sin datos para graficar. Ejecuta scripts/run_bench.sh primero.")
        return

    summary_path = Path(args.summary)
    summary_path.parent.mkdir(parents=True, exist_ok=True)
    summary.to_csv(summary_path, index=False)

    plot_speedups(summary, Path(args.outdir))
    print(f"Resumen guardado en: {summary_path}")
    print(f"Gráficas en: {os.path.abspath(args.outdir)}")


if __name__ == "__main__":
    main()
