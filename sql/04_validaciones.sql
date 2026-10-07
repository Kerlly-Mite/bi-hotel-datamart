-- =====================================================================
-- 04_validaciones.sql  |  Consultas de validación del Data Mart
-- Cada consulta devuelve una columna "resultado" con OK o ERROR.
-- =====================================================================

-- V1. CANTIDAD DE REGISTROS CARGADOS ----------------------------------
-- V1.1 Staging vs. tabla de hechos (deben ser iguales)
SELECT 'V1.1 staging vs hechos' AS validacion,
       (SELECT COUNT(*) FROM stg_reservas)  AS filas_staging,
       (SELECT COUNT(*) FROM fact_reservas) AS filas_hechos,
       CASE WHEN (SELECT COUNT(*) FROM stg_reservas) = (SELECT COUNT(*) FROM fact_reservas)
            THEN 'OK' ELSE 'ERROR' END AS resultado;

-- V1.2 Filas por tabla del modelo
SELECT 'dim_fecha' AS tabla, COUNT(*) AS filas FROM dim_fecha
UNION ALL SELECT 'dim_hotel', COUNT(*) FROM dim_hotel
UNION ALL SELECT 'dim_cliente', COUNT(*) FROM dim_cliente
UNION ALL SELECT 'dim_canal', COUNT(*) FROM dim_canal
UNION ALL SELECT 'dim_habitacion', COUNT(*) FROM dim_habitacion
UNION ALL SELECT 'dim_condicion_reserva', COUNT(*) FROM dim_condicion_reserva
UNION ALL SELECT 'dim_estado_reserva', COUNT(*) FROM dim_estado_reserva
UNION ALL SELECT 'fact_reservas', COUNT(*) FROM fact_reservas;

-- V2. INTEGRIDAD DE LAS RELACIONES (hechos sin dimensión = huérfanos) --
SELECT 'V2 huérfanos por dimensión' AS validacion,
       COUNT(*) FILTER (WHERE d.fecha_key      IS NULL) AS sin_fecha,
       COUNT(*) FILTER (WHERE h.hotel_key      IS NULL) AS sin_hotel,
       COUNT(*) FILTER (WHERE c.cliente_key    IS NULL) AS sin_cliente,
       COUNT(*) FILTER (WHERE ca.canal_key     IS NULL) AS sin_canal,
       COUNT(*) FILTER (WHERE hb.habitacion_key IS NULL) AS sin_habitacion,
       COUNT(*) FILTER (WHERE co.condicion_key IS NULL) AS sin_condicion,
       COUNT(*) FILTER (WHERE e.estado_key     IS NULL) AS sin_estado,
       CASE WHEN COUNT(*) FILTER (WHERE d.fecha_key IS NULL OR h.hotel_key IS NULL
                                  OR c.cliente_key IS NULL OR ca.canal_key IS NULL
                                  OR hb.habitacion_key IS NULL OR co.condicion_key IS NULL
                                  OR e.estado_key IS NULL) = 0
            THEN 'OK' ELSE 'ERROR' END AS resultado
FROM fact_reservas f
LEFT JOIN dim_fecha             d  ON d.fecha_key       = f.fecha_llegada_key
LEFT JOIN dim_hotel             h  ON h.hotel_key       = f.hotel_key
LEFT JOIN dim_cliente           c  ON c.cliente_key     = f.cliente_key
LEFT JOIN dim_canal             ca ON ca.canal_key      = f.canal_key
LEFT JOIN dim_habitacion        hb ON hb.habitacion_key = f.habitacion_key
LEFT JOIN dim_condicion_reserva co ON co.condicion_key  = f.condicion_key
LEFT JOIN dim_estado_reserva    e  ON e.estado_key      = f.estado_key;

-- V2.2 Dimensiones sin uso (dimensiones que ningún hecho referencia)
SELECT 'V2.2 hoteles sin reservas' AS validacion, COUNT(*) AS cantidad,
       CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'REVISAR' END AS resultado
FROM dim_hotel h LEFT JOIN fact_reservas f ON f.hotel_key = h.hotel_key
WHERE f.reserva_key IS NULL;

-- V3. VALORES NULOS RELEVANTES ----------------------------------------
SELECT 'V3 nulos en claves y medidas' AS validacion,
       COUNT(*) FILTER (WHERE fecha_llegada_key IS NULL OR hotel_key IS NULL
                         OR cliente_key IS NULL OR canal_key IS NULL
                         OR habitacion_key IS NULL OR condicion_key IS NULL
                         OR estado_key IS NULL)           AS nulos_en_claves,
       COUNT(*) FILTER (WHERE adr IS NULL OR noches_totales IS NULL
                         OR ingreso_estimado IS NULL
                         OR es_cancelada IS NULL)         AS nulos_en_medidas,
       CASE WHEN COUNT(*) FILTER (WHERE fecha_llegada_key IS NULL OR hotel_key IS NULL
                         OR cliente_key IS NULL OR canal_key IS NULL
                         OR habitacion_key IS NULL OR condicion_key IS NULL
                         OR estado_key IS NULL OR adr IS NULL OR noches_totales IS NULL
                         OR ingreso_estimado IS NULL OR es_cancelada IS NULL) = 0
            THEN 'OK' ELSE 'ERROR' END AS resultado
FROM fact_reservas;

-- V4. TOTALES / MEDIDAS PRINCIPALES (staging vs hechos) ----------------
SELECT 'V4.1 noches totales' AS validacion,
       (SELECT SUM(noches_fin_semana + noches_semana) FROM stg_reservas) AS total_staging,
       (SELECT SUM(noches_totales) FROM fact_reservas)                   AS total_hechos,
       CASE WHEN (SELECT SUM(noches_fin_semana + noches_semana) FROM stg_reservas)
               = (SELECT SUM(noches_totales) FROM fact_reservas)
            THEN 'OK' ELSE 'ERROR' END AS resultado;

SELECT 'V4.2 reservas canceladas' AS validacion,
       (SELECT SUM(es_cancelada) FROM stg_reservas) AS total_staging,
       (SELECT SUM(es_cancelada) FROM fact_reservas) AS total_hechos,
       CASE WHEN (SELECT SUM(es_cancelada) FROM stg_reservas)
               = (SELECT SUM(es_cancelada) FROM fact_reservas)
            THEN 'OK' ELSE 'ERROR' END AS resultado;

SELECT 'V4.3 ingreso estimado' AS validacion,
       (SELECT ROUND(SUM(adr * (noches_fin_semana + noches_semana)), 2) FROM stg_reservas) AS total_staging,
       (SELECT SUM(ingreso_estimado) FROM fact_reservas)                                   AS total_hechos,
       CASE WHEN (SELECT ROUND(SUM(adr * (noches_fin_semana + noches_semana)), 2) FROM stg_reservas)
               = (SELECT SUM(ingreso_estimado) FROM fact_reservas)
            THEN 'OK' ELSE 'REVISAR (diferencia por redondeo por fila)' END AS resultado;

-- V4.4 Medidas principales (para el informe)
SELECT COUNT(*)                                         AS total_reservas,
       SUM(es_cancelada)                                AS canceladas,
       ROUND(100.0 * SUM(es_cancelada) / COUNT(*), 2)   AS tasa_cancelacion_pct,
       SUM(noches_totales)                              AS noches_totales,
       ROUND(AVG(adr), 2)                               AS adr_promedio_simple,
       SUM(ingreso_estimado) FILTER (WHERE es_cancelada = 0) AS ingresos_confirmados
FROM fact_reservas;

-- V4.5 Coherencia: estado 'Canceled' o 'No-Show' debe coincidir con es_cancelada = 1
SELECT 'V4.5 estado vs es_cancelada' AS validacion, COUNT(*) AS inconsistencias,
       CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'ERROR' END AS resultado
FROM fact_reservas f
JOIN dim_estado_reserva e ON e.estado_key = f.estado_key
WHERE (e.estado_reserva = 'Check-Out' AND f.es_cancelada = 1)
   OR (e.estado_reserva <> 'Check-Out' AND f.es_cancelada = 0);
