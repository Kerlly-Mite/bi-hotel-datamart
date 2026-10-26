# Mi primer dashboard: Business Intelligence de reservas de hotel (Entregable 3)

**Universidad Estatal Península de Santa Elena (UPSE)** · Inteligencia de Negocios · 6/1 · 2026-2
**Estudiante:** Kerlly Belinda Mite Chalén · **Docente:** Ing. Anthony Pachay Espinoza, MSc.

Solución analítica de extremo a extremo: **CSV de Kaggle → Python (limpieza) → PostgreSQL (modelo estrella) → vistas y funciones SQL → Streamlit (dashboard)**.

- **Dataset:** [Hotel booking demand](https://www.kaggle.com/datasets/jessemostipak/hotel-booking-demand) (Kaggle, Jesse Mostipak): 119.390 reservas de un hotel urbano (City Hotel) y un hotel vacacional (Resort Hotel) de Portugal, jul 2015 a ago 2017.
- **Modelo:** esquema estrella en PostgreSQL 17 (Docker): 1 tabla de hechos + 7 dimensiones.
- **Granularidad:** una fila de `fact_reservas` representa **una reserva de hotel** con su fecha de llegada, sin importar si terminó en check-out, cancelación o no-show.
- **Restricción cumplida:** la aplicación Streamlit **no lee el CSV**; todos los datos salen de PostgreSQL mediante vistas y funciones SQL.

## Estructura del proyecto

```
bi-hotel-datamart/
├── docker-compose.yml          # PostgreSQL 17 (puerto 5433)
├── requirements.txt            # dependencias de limpieza (pandas, matplotlib)
├── data/raw/hotel_bookings.csv # dataset original de Kaggle
├── data/processed/             # CSV limpio (se genera; no se sube a GitHub)
├── python/
│   ├── 01_limpieza.py          # limpieza y transformación (genera docs/log_limpieza.txt)
│   └── 02_diagramas.py         # diagrama estrella y mockup del Entregable 2
├── sql/
│   ├── 01_schema.sql                    # staging, dimensiones y hechos (PK, FK, CHECK)
│   ├── 02_carga_staging.sql             # carga del CSV limpio
│   ├── 03_carga_dimensiones_hechos.sql  # llena dimensiones y hechos
│   ├── 04_validaciones.sql              # consultas de validación
│   ├── 05_vistas_funciones.sql          # vistas y funciones base
│   └── 06_funciones_entregable3.sql     # funciones para P1, P2, P3 y filtros
├── streamlit_app/
│   ├── app.py                  # dashboard (2 secciones, 4 KPI, 3 filtros, gráficos y tabla)
│   └── requirements.txt        # streamlit, psycopg2-binary, pandas
├── scripts/                    # ejecutar_todo.ps1 (Windows) / ejecutar_todo.sh
├── mockup/                     # mockup_e3.html (mockup final)
└── docs/                       # documento final, matriz de trazabilidad, mockups, evidencias
```

## Requisitos

- Docker Desktop (abierto y corriendo)
- Python 3.10 o superior
- Git

## Cómo ejecutar el proyecto (paso a paso)

Abre una terminal **en la carpeta del proyecto**.

### 1. Preparar el entorno de Python (recomendado)

```bash
python -m venv .venv
.venv\Scripts\activate          # Windows (en Mac/Linux: source .venv/bin/activate)
pip install -r requirements.txt
pip install -r streamlit_app/requirements.txt
```

### 2. Construir la base de datos

**Opción rápida** (limpieza, Docker y todos los scripts SQL, incluido el 06):

- Windows (PowerShell): `powershell -ExecutionPolicy Bypass -File scripts/ejecutar_todo.ps1`
- Mac / Linux / Git Bash: `bash scripts/ejecutar_todo.sh`

**Opción manual:**

```bash
python python/01_limpieza.py
docker compose up -d
docker exec -i bi-postgres psql -U bi_user -d bi_database -v ON_ERROR_STOP=1 -f /sql/01_schema.sql
docker exec -i bi-postgres psql -U bi_user -d bi_database -v ON_ERROR_STOP=1 -f /sql/02_carga_staging.sql
docker exec -i bi-postgres psql -U bi_user -d bi_database -v ON_ERROR_STOP=1 -f /sql/03_carga_dimensiones_hechos.sql
docker exec -i bi-postgres psql -U bi_user -d bi_database -v ON_ERROR_STOP=1 -f /sql/04_validaciones.sql
docker exec -i bi-postgres psql -U bi_user -d bi_database -v ON_ERROR_STOP=1 -f /sql/05_vistas_funciones.sql
docker exec -i bi-postgres psql -U bi_user -d bi_database -v ON_ERROR_STOP=1 -f /sql/06_funciones_entregable3.sql
```

### 3. Abrir el dashboard

```bash
streamlit run streamlit_app/app.py
```

Se abre en `http://localhost:8501` (o el puerto siguiente si está ocupado).

## Conexión a PostgreSQL

| Campo | Valor |
|---|---|
| Host | `localhost` |
| Puerto | `5433` |
| Base de datos | `bi_database` |
| Usuario | `bi_user` |
| Contraseña | `bi_password` |

La app usa estos valores por defecto. Puedes cambiarlos con las variables de entorno `PGHOST`, `PGPORT`, `PGDATABASE`, `PGUSER` y `PGPASSWORD`.

## Qué incluye el dashboard

| Sección | Contenido | Pregunta |
|---|---|---|
| Demanda, precio e ingresos | KPI (ADR, tasa de cancelación, ingresos, total de reservas), ADR por mes y hotel, reservas por mes, top 10 países por ingresos | P1 y P3 |
| Cancelaciones y detalle | Cancelación por segmento, por tipo de depósito y por canal; tabla de detalle de reservas | P2 |

**Filtros (afectan a todas las consultas):** Año de llegada, Hotel y Segmento de mercado.

## Comprobaciones rápidas

```bash
docker exec -i bi-postgres psql -U bi_user -d bi_database -c "SELECT * FROM fn_cancelacion_por_deposito();"
docker exec -i bi-postgres psql -U bi_user -d bi_database -c "SELECT fn_adr_promedio(2016, 'City Hotel');"
```

Valores esperados: Non Refund con 14.586 reservas y 14.493 canceladas (99,36 %); ADR 2016 de City Hotel: 104,79. Totales generales: 118.563 reservas, ADR 102,20, ingresos confirmados 25.986.976.

## Documentación

- `docs/matriz_trazabilidad_E3.md`: componente → pregunta/KPI → filtros → datos → función SQL.
- `docs/mockup_seccion1.png` y `docs/mockup_seccion2.png`: mockup final.
- `docs/diagrama_estrella.png`, `docs/log_limpieza.txt`, `docs/evidencia_validaciones.txt`: modelo, limpieza y validaciones.

## Problemas frecuentes

| Problema | Solución |
|---|---|
| `port is already allocated` | Otro servicio usa el puerto. Cambia el puerto izquierdo en `docker-compose.yml` (por ejemplo `"5433:5432"`) y el valor `PGPORT`. |
| `Cannot connect to the Docker daemon` | Abre Docker Desktop y espera a que esté en "running". |
| La app muestra "No se pudo conectar a PostgreSQL" | Ejecuta `docker compose up -d` y comprueba el puerto 5433. |
| `No such file: /data/processed/hotel_clean.csv` | Falta ejecutar `python python/01_limpieza.py` antes de la carga. |
| La app arranca en el puerto 8502 | Hay otra instancia abierta en el 8501. Ciérrala con `Ctrl + C`. |
