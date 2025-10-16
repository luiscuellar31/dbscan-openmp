/*
  DBSCAN (OpenMP - "indivisible")
  Autor: @luiscuellar31

  Idea:
  - Paralelizamos el bucle exterior que, para cada punto i, precalcula sus vecinos
    y marca si es punto núcleo (esCore). La expansión BFS se mantiene secuencial
    para evitar condiciones de carrera sobre la estructura de etiquetas.

  Entrada / salida:
  - Lee CSV 2D (x,y); escribe idx,x,y,label (ruido = -2)
  - Si no se pasa salida, se deriva de la entrada: _data.csv -> _results.csv

  Uso típico:
    OMP_NUM_THREADS=4 ./dbscan_omp_indivisible data/input/4000_data.csv
*/
#include <iostream>
#include <vector>
#include <queue>
#include <algorithm>
#include <sstream>
#include <fstream>
#include <string>
using namespace std;

// Estructura para representar un punto 2D
struct Point {
    double x, y;
};

// Distancia euclidiana al cuadrado entre dos puntos (evitamos sqrt por rendimiento)
double distancia_euclidiana(Point p1, Point p2) {
    return (p1.x - p2.x) * (p1.x - p2.x) + (p1.y - p2.y) * (p1.y - p2.y);
}

// Devuelve los índices de los vecinos del objeto "idxObj" dentro de un radio "eps"
// La comparación se hace con valores al cuadrado: d^2 <= eps^2
vector<int> vecinosObj(vector<Point> &puntos, int idxObj, double eps) {
    int n = static_cast<int>(puntos.size());
    vector<int> vecinos;
    double eps2 = eps * eps;
    for (int i = 0; i < n; i++) {
        if (idxObj == i) continue;
        if (distancia_euclidiana(puntos[idxObj], puntos[i]) <= eps2) {
            vecinos.push_back(i);
        }
    }
    return vecinos;
}

// DBSCAN (paralelo indivisible)
// -1: no visitado
// -2: ruido
vector<int> dbscan(vector<Point> &puntos, double eps, int minimoPuntos) {
    int n = static_cast<int>(puntos.size());
    vector<int> clusterPertenezco(n, -1);
    vector<vector<int>> vecinosLista(n,vector<int>());
    int clusterID = 0;

    // Precalculo los vecinos y si es core o no (paralelizado en i)
    vector<int> esCore(n, 0);
    #pragma omp parallel for schedule(static)
    for(int i = 0; i < n; i++) {
        vecinosLista[i] = vecinosObj(puntos, i, eps);
        if(vecinosLista[i].size() + 1 >= minimoPuntos) {
            esCore[i] = 1;
        }
    }

    for (int i = 0; i < n; i++) {
        if (clusterPertenezco[i] == -1) {

            if (!esCore[i]) {
                clusterPertenezco[i] = -2; // ruido
            } else {
                clusterPertenezco[i] = clusterID;

                queue<int> q;
                for (auto v : vecinosLista[i]) q.push(v);

                while (!q.empty()) {
                    int nodoAct = q.front(); q.pop();

                    if (clusterPertenezco[nodoAct] < 0) {
                        clusterPertenezco[nodoAct] = clusterID;

                        if (esCore[nodoAct]) {
                            for (auto v : vecinosLista[nodoAct]) {
                                if (clusterPertenezco[v] == -1) {
                                    q.push(v);
                                }
                            }
                        }
                    }
                }
                clusterID++;
            }
        }
    }
    return clusterPertenezco;
}

// Lee un CSV y rellena 'out' con los puntos (x,y)
// Acepta separadores: coma, punto y coma o espacio
// Salta líneas que no se pueden parsear (ej. headers)
bool leer_csv_a_puntos(const string &ruta, vector<Point> &out) {
    ifstream f(ruta);
    if (!f.is_open()) return false;

    string linea;
    while (getline(f, linea)) {
        if (linea.empty()) continue;

        // Normalizar separadores: ; -> , y luego , -> espacio
        for (char &c : linea) if (c == ';') c = ',';
        replace(linea.begin(), linea.end(), ',', ' ');

        stringstream ss(linea);
        double a, b;
        if (!(ss >> a)) continue; // posible header o línea inválida
        if (!(ss >> b)) continue; // no hay segundo número -> saltar
        out.push_back({a, b});
    }
    f.close();
    return true;
}

int main(int argc, char** argv) {
    vector<Point> puntos;

    // Si se pasa ruta por argumento, intentar leer CSV; por defecto usar rutas locales del repo
    string ruta = "data/input/4000_data.csv";
    string ruta_salida;
    if (argc >= 2) ruta = argv[1];
    if (argc >= 3) ruta_salida = argv[2];
    // Derivar salida si no se proporcionó: data/output/{N}_results.csv para entrada {N}_data.csv
    if (ruta_salida.empty()) {
        string fname = ruta;
        size_t slash = fname.find_last_of("/\\");
        if (slash != string::npos) fname = fname.substr(slash + 1);
        string out_name;
        const string suf = "_data.csv";
        if (fname.size() > suf.size() && fname.compare(fname.size() - suf.size(), suf.size(), suf) == 0) {
            string base = fname.substr(0, fname.size() - suf.size());
            out_name = base + "_results.csv";
        } else {
            const string pfx = "points_";
            const string suf2 = ".csv";
            bool has_csv = fname.size() > suf2.size() && fname.rfind(suf2) == fname.size() - suf2.size();
            bool has_pfx = fname.rfind(pfx, 0) == 0;
            if (has_csv && has_pfx) {
                string base = fname.substr(pfx.size(), fname.size() - pfx.size() - suf2.size());
                out_name = base + "_results.csv";
            } else {
                out_name = "resultados.csv";
            }
        }
        ruta_salida = string("data/output/") + out_name;
    }

    if (!leer_csv_a_puntos(ruta, puntos)) {
        cerr << "Error: no se pudo abrir o procesar el archivo CSV: " << ruta << "\n";
        cerr << "Uso: " << argv[0] << " [ruta_csv] [ruta_salida]\n";
        return 1;
    }

    // Ejecutar DBSCAN con parámetros elegidos
    auto etiquetas = dbscan(puntos, 0.05, 10);

    // Imprimir por consola igual que antes
    cout << "LUIS\n";
    for (auto t : etiquetas) cout << t << "\n";

    // Generar CSV de salida: idx,x,y,label
    ofstream fout(ruta_salida);
    if (!fout.is_open()) {
        cerr << "Error: no se pudo crear el archivo de salida: " << ruta_salida << "\n";
        return 1;
    }
    fout << "idx,x,y,label\n";
    for (size_t i = 0; i < puntos.size(); ++i) {
        fout << i << "," << puntos[i].x << "," << puntos[i].y << "," << etiquetas[i] << "\n";
    }
    fout.close();

    return 0;
}
