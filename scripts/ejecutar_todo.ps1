# Ejecuta todo el pipeline (Windows PowerShell). Correr desde la raíz del proyecto.
$ErrorActionPreference = "Stop"
python python/01_limpieza.py
docker compose up -d
Write-Host "Esperando a que PostgreSQL arranque..."
do { Start-Sleep -Seconds 1; docker exec bi-postgres pg_isready -U bi_user -d bi_database *> $null } until ($LASTEXITCODE -eq 0)
foreach ($f in "01_schema","02_carga_staging","03_carga_dimensiones_hechos","04_validaciones","05_vistas_funciones") {
    Write-Host "=== Ejecutando sql/$f.sql ==="
    docker exec -i bi-postgres psql -U bi_user -d bi_database -v ON_ERROR_STOP=1 -f /sql/$f.sql
    if ($LASTEXITCODE -ne 0) { throw "Falló $f.sql" }
}
Write-Host "Listo. Conexión: localhost:5433 / bi_database / bi_user / bi_password"
