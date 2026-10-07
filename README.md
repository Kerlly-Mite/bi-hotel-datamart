# Data Mart de Reservas de Hotel — Entregable 2 (Business Intelligence)

Dataset: [Hotel booking demand](https://www.kaggle.com/datasets/jessemostipak/hotel-booking-demand) (Kaggle).
Motor: PostgreSQL 17 en Docker. Modelo: esquema estrella (1 tabla de hechos + 7 dimensiones).

> **Granularidad:** una fila de `fact_reservas` representa **una reserva de hotel** (City Hotel o Resort Hotel) con su fecha de llegada, sin importar si terminó en check-out, cancelación o no-show.

## Estructura del proyecto

```
bi-hotel-datamart/
├── index.html                  # dashboard (mockup interactivo, abrir en el navegador)
├── docker-compose.yml          # PostgreSQL 17 (bi_database / bi_user / bi_password)
├── requirements.txt            # pandas, matplotlib
├── data/
│   ├── raw/hotel_bookings.csv  # dataset original de Kaggle
│   └── processed/              # CSV limpio (se genera, no se sube a GitHub)
├── python/
│   ├── 01_limpieza.py          # limpia el CSV y genera docs/log_limpieza.txt
│   └── 02_diagramas.py         # genera el diagrama estrella y el mockup (PNG)
├── sql/
│   ├── 01_schema.sql                    # staging + dimensiones + hechos (PK, FK)
│   ├── 02_carga_staging.sql             # carga del CSV limpio
│   ├── 03_carga_dimensiones_hechos.sql  # llena dimensiones y hechos
│   ├── 04_validaciones.sql              # consultas de validación
│   └── 05_vistas_funciones.sql          # vistas y funciones para el dashboard
├── scripts/                    # ejecutar_todo.ps1 (Windows) / ejecutar_todo.sh (Mac/Linux)
└── docs/
    ├── ENTREGABLE_2.md         # documento del entregable (modelo, matriz, mockup, evidencias)
    ├── diagrama_estrella.png
    ├── mockup_dashboard.png
    ├── log_limpieza.txt
    └── evidencia_validaciones.txt
```

## Requisitos

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (abierto y corriendo)
- Python 3.10+ con `pip install -r requirements.txt`
- Visual Studio Code (opcional pero recomendado)
- Git

## Ejecución paso a paso

Abre una terminal **en la carpeta del proyecto** (en VS Code: `Terminal > New Terminal`).

### Opción rápida (todo de una vez)

- Windows (PowerShell): `powershell -ExecutionPolicy Bypass -File scripts/ejecutar_todo.ps1`
- Mac / Linux / Git Bash: `bash scripts/ejecutar_todo.sh`

### Opción manual (para entender cada paso)

```bash
# 1. Instalar dependencias y limpiar el dataset
pip install -r requirements.txt
python python/01_limpieza.py

# 2. Levantar PostgreSQL
docker compose up -d

# 3. Crear tablas, cargar y validar (se ejecutan DENTRO del contenedor)
docker exec -i bi-postgres psql -U bi_user -d bi_database -v ON_ERROR_STOP=1 -f /sql/01_schema.sql
docker exec -i bi-postgres psql -U bi_user -d bi_database -v ON_ERROR_STOP=1 -f /sql/02_carga_staging.sql
docker exec -i bi-postgres psql -U bi_user -d bi_database -v ON_ERROR_STOP=1 -f /sql/03_carga_dimensiones_hechos.sql
docker exec -i bi-postgres psql -U bi_user -d bi_database -v ON_ERROR_STOP=1 -f /sql/04_validaciones.sql
docker exec -i bi-postgres psql -U bi_user -d bi_database -v ON_ERROR_STOP=1 -f /sql/05_vistas_funciones.sql

# 4. (Opcional) regenerar las imágenes del diagrama y el mockup
python python/02_diagramas.py
```

Para abrir una consola SQL interactiva:

```bash
docker exec -it bi-postgres psql -U bi_user -d bi_database
```

Para apagar: `docker compose down` (los datos se conservan en el volumen).
Para borrar TODO, datos incluidos: `docker compose down -v`.

## Usar PostgreSQL desde Visual Studio Code

Sí se puede. Instala la extensión **SQLTools** y el driver **SQLTools PostgreSQL/Cockroach Driver** (ambas de Matheus Teixeira), y crea una conexión con:

| Campo | Valor |
|---|---|
| Server / Host | `localhost` |
| Port | `5433` |
| Database | `bi_database` |
| Username | `bi_user` |
| Password | `bi_password` |

También puedes instalar la extensión **Docker** (Microsoft) para ver y controlar el contenedor `bi-postgres`.

## Subir a GitHub

1. Crea un repositorio vacío en github.com (por ejemplo `bi-hotel-datamart`), **sin** README ni .gitignore.
2. En la terminal, dentro de la carpeta del proyecto:

```bash
git init
git add .
git commit -m "Entregable 2: Data Mart de reservas de hotel"
git branch -M main
git remote add origin https://github.com/TU_USUARIO/bi-hotel-datamart.git
git push -u origin main
```

Si GitHub pide autenticación, usa un *Personal Access Token* (Settings > Developer settings > Tokens) como contraseña, o inicia sesión desde VS Code (icono de cuenta abajo a la izquierda).

## Problemas frecuentes

| Problema | Solución |
|---|---|
| `port is already allocated` (5432) | Tienes otro PostgreSQL local usando el puerto. Páralo o cambia `"5432:5432"` por `"5433:5432"` en `docker-compose.yml`. |
| `Cannot connect to the Docker daemon` | Abre Docker Desktop y espera a que diga "running". |
| `No such file: /data/processed/hotel_clean.csv` | Falta ejecutar `python python/01_limpieza.py` antes del paso de carga. |
| Los scripts no encuentran `/sql` o `/data` | Ejecuta `docker compose down` y `docker compose up -d` de nuevo desde la carpeta del proyecto. |


git clone https://github.com/Kerlly-Mite/bi-hotel-datamart.git
cd bi-hotel-datamart
pip install -r requirements.txt
powershell -ExecutionPolicy Bypass -File scripts/ejecutar_todo.ps1
