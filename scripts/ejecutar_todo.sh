#!/usr/bin/env bash
# Ejecuta todo el pipeline (Mac / Linux / Git Bash). Correr desde la raíz del proyecto.
set -e
python python/01_limpieza.py
docker compose up -d
echo "Esperando a que PostgreSQL arranque..."
until docker exec bi-postgres pg_isready -U bi_user -d bi_database >/dev/null 2>&1; do sleep 1; done
for f in 01_schema 02_carga_staging 03_carga_dimensiones_hechos 04_validaciones 05_vistas_funciones; do
  echo "=== Ejecutando sql/$f.sql ==="
  docker exec -i bi-postgres psql -U bi_user -d bi_database -v ON_ERROR_STOP=1 -f /sql/$f.sql
done
echo "Listo. Conexión: localhost:5433 / bi_database / bi_user / bi_password"
