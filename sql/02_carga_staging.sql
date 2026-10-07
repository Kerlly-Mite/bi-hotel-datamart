-- =====================================================================
-- 02_carga_staging.sql  |  Carga del CSV limpio a la tabla de staging
-- Se ejecuta con psql DENTRO del contenedor (la carpeta ./data está
-- montada en /data). \copy es un comando de psql, no SQL estándar.
-- =====================================================================

TRUNCATE TABLE stg_reservas;

\copy stg_reservas FROM '/data/processed/hotel_clean.csv' WITH (FORMAT csv, HEADER true)

SELECT COUNT(*) AS filas_en_staging FROM stg_reservas;
