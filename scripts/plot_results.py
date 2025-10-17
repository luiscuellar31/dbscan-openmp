import os
import sys
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np

# Uso:
#   python3 scripts/plot_results.py [ruta_csv]
# Si no se pasa ruta, intenta:
#   - ./resultados.csv (por defecto de dbscan_serial)
#   - data/output/*.csv (toma el más reciente)

def encontrar_csv_por_defecto() -> str | None:
    out_dir = os.path.join("data", "output")

    # 1) Preferir archivos *_results.csv en data/output
    if os.path.isdir(out_dir):
        candidates = [
            os.path.join(out_dir, f)
            for f in os.listdir(out_dir)
            if f.lower().endswith("_results.csv")
        ]
        if candidates:
            candidates.sort(key=lambda p: os.path.getmtime(p), reverse=True)
            return candidates[0]

    # 2) Compatibilidad con resultados.csv
    preferido = os.path.join("data", "output", "resultados.csv")
    if os.path.exists(preferido):
        return preferido

    # 3) Alternativa: archivo en la raíz (compatibilidad)
    if os.path.exists("resultados.csv"):
        return "resultados.csv"

    # 4) Si no, tomar el CSV más reciente en data/output
    if os.path.isdir(out_dir):
        csvs = [os.path.join(out_dir, f) for f in os.listdir(out_dir) if f.lower().endswith(".csv")]
        if csvs:
            csvs.sort(key=lambda p: os.path.getmtime(p), reverse=True)
            return csvs[0]
    return None


def cargar_xy_labels(df: pd.DataFrame):
    # Detectar columnas x,y,label (dbscan_serial escribe: idx,x,y,label)
    if set(["x", "y", "label"]).issubset(df.columns):
        x = df["x"].to_numpy()
        y = df["y"].to_numpy()
        labels = df["label"].to_numpy()
        return x, y, labels
    # Caso mínimo: al menos 2 columnas numéricas para x,y (sin labels)
    if df.shape[1] >= 2:
        x = df.iloc[:, 0].to_numpy()
        y = df.iloc[:, 1].to_numpy()
        return x, y, None
    raise ValueError("CSV no tiene suficientes columnas para interpretar puntos (>=2)")


def plot_dbscan_points(x, y, labels, titulo_base: str):
    plt.figure(figsize=(8, 6))
    if labels is None:
        plt.scatter(x, y, s=12, c="#1f77b4", alpha=0.9, edgecolors="none")
        plt.title(f"{titulo_base} (sin labels)")
    else:
        labels = np.asarray(labels)
        # Ruido: etiquetas negativas (por convención -2). Clusters >= 0
        noise_mask = labels < 0
        cluster_labels = sorted([int(l) for l in np.unique(labels) if int(l) >= 0])

        # Colormap para clusters
        cmap = plt.get_cmap("tab20")
        colors = {cl: cmap(i % 20) for i, cl in enumerate(cluster_labels)}

        # Dibujar clusters uno por uno para una leyenda clara
        for cl in cluster_labels:
            m = labels == cl
            if np.any(m):
                plt.scatter(x[m], y[m], s=12, c=[colors[cl]], alpha=0.9, edgecolors="none", label=f"Cluster {cl}")

        # Ruido en gris oscuro
        if np.any(noise_mask):
            plt.scatter(x[noise_mask], y[noise_mask], s=10, c="#555555", alpha=0.6, edgecolors="none", label="Ruido (-2)")

        plt.title(f"{titulo_base} (DBSCAN: clusters y ruido)")
        if cluster_labels or np.any(noise_mask):
            plt.legend(loc="best", frameon=True)

    plt.xlabel("X")
    plt.ylabel("Y")
    plt.grid(True, linewidth=0.4, alpha=0.4)
    plt.gca().set_aspect("equal", adjustable="box")
    plt.tight_layout()


def resolver_ruta_csv(arg_path: str | None) -> str:
    # Si no se pasó argumento, buscar por defecto
    if not arg_path:
        ruta = encontrar_csv_por_defecto()
        if not ruta:
            raise FileNotFoundError("No se encontró CSV en data/output/. Genere resultados primero.")
        return ruta

    # Si pasaron un directorio, tomar el más reciente dentro
    if os.path.isdir(arg_path):
        csvs = [os.path.join(arg_path, f) for f in os.listdir(arg_path) if f.lower().endswith('.csv')]
        if not csvs:
            raise FileNotFoundError(f"No hay CSVs en {arg_path}")
        csvs.sort(key=lambda p: os.path.getmtime(p), reverse=True)
        return csvs[0]

    # Si pasaron un archivo de entrada {N}_data.csv, mapear a data/output/{N}_results.csv si existe
    if arg_path.endswith("_data.csv"):
        base = os.path.basename(arg_path)[:-len("_data.csv")]
        candidato = os.path.join("data", "output", f"{base}_results.csv")
        if os.path.exists(candidato):
            return candidato
        raise FileNotFoundError(f"No existe {candidato}. Ejecute el binario C++ para generar resultados.")

    # Si es un CSV cualquiera, devolverlo tal cual
    if os.path.isfile(arg_path):
        return arg_path

    raise FileNotFoundError(f"Ruta no válida: {arg_path}")


def _parse_cli():
    no_show = False
    arg = None
    for a in sys.argv[1:]:
        if a == "--no-show":
            no_show = True
        else:
            arg = a
    return arg, no_show


def main():
    arg, no_show = _parse_cli()
    ruta = resolver_ruta_csv(arg)

    df = pd.read_csv(ruta)
    print("Usando archivo:", ruta)
    print("Columnas detectadas:", list(df.columns))

    x, y, labels = cargar_xy_labels(df)
    base = os.path.splitext(os.path.basename(ruta))[0]
    plot_dbscan_points(x, y, labels, titulo_base=f"Puntos: {base}")

    # Guardar PNG junto al CSV de entrada
    out_png = os.path.join(os.path.dirname(ruta), f"{base}.png")
    plt.savefig(out_png, dpi=200)
    # Mostrar solo en modo interactivo
    if not no_show and os.environ.get("NO_SHOW", "0") != "1":
        plt.show()
    print("PNG guardado en:", out_png)


if __name__ == "__main__":
    main()
