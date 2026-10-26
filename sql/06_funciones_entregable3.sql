-- =====================================================================
-- 06_funciones_entregable3.sql  |  Funciones nuevas para el Entregable 3
-- Ejecutar DESPUES de 05_vistas_funciones.sql. Es re-ejecutable.
--
-- Filtros (todos opcionales, NULL = "todos"):
--   p_anio, p_hotel, p_segmento
--
-- Cubren las preguntas de negocio:
--   P1 (demanda y precio por mes y hotel)   -> fn_adr_ingresos_por_mes
--   P2 (cancelación por tipo de depósito)   -> fn_cancelacion_por_deposito
--   P2 (cancelación por canal)              -> fn_cancelacion_por_canal
--   P3 (ingreso por país)                   -> fn_ingresos_por_pais
--   Filtros del dashboard                   -> fn_lista_hoteles, fn_lista_anios
-- =====================================================================

-- P1: reservas, ADR e ingresos por año/mes/hotel (gráfico de líneas)
CREATE OR REPLACE FUNCTION fn_adr_ingresos_por_mes(
    p_anio INT DEFAULT NULL, p_hotel TEXT DEFAULT NULL, p_segmento TEXT DEFAULT NULL)
RETURNS TABLE (anio SMALLINT, mes SMALLINT, nombre_mes VARCHAR, hotel VARCHAR,
               reservas BIGINT, noches_vendidas BIGINT, adr NUMERIC,
               ingresos_confirmados NUMERIC)
LANGUAGE sql STABLE AS $$
    SELECT v.anio, v.mes, v.nombre_mes, v.hotel,
           COUNT(*),
           COALESCE(SUM(v.noches_totales) FILTER (WHERE v.es_cancelada = 0), 0)::BIGINT,
           ROUND(SUM(v.ingreso_estimado) FILTER (WHERE v.es_cancelada = 0)
                 / NULLIF(SUM(v.noches_totales) FILTER (WHERE v.es_cancelada = 0), 0), 2),
           COALESCE(SUM(v.ingreso_estimado) FILTER (WHERE v.es_cancelada = 0), 0)
    FROM vw_reservas_detalle v
    WHERE (p_anio IS NULL     OR v.anio = p_anio)
      AND (p_hotel IS NULL    OR v.hotel = p_hotel)
      AND (p_segmento IS NULL OR v.segmento_mercado = p_segmento)
    GROUP BY v.anio, v.mes, v.nombre_mes, v.hotel
    ORDER BY v.anio, v.mes, v.hotel;
$$;

-- P2: cancelación por tipo de depósito
CREATE OR REPLACE FUNCTION fn_cancelacion_por_deposito(
    p_anio INT DEFAULT NULL, p_hotel TEXT DEFAULT NULL, p_segmento TEXT DEFAULT NULL)
RETURNS TABLE (tipo_deposito VARCHAR, reservas BIGINT, canceladas BIGINT,
               tasa_cancelacion_pct NUMERIC)
LANGUAGE sql STABLE AS $$
    SELECT v.tipo_deposito,
           COUNT(*),
           SUM(v.es_cancelada)::BIGINT,
           ROUND(100.0 * SUM(v.es_cancelada) / COUNT(*), 2)
    FROM vw_reservas_detalle v
    WHERE (p_anio IS NULL     OR v.anio = p_anio)
      AND (p_hotel IS NULL    OR v.hotel = p_hotel)
      AND (p_segmento IS NULL OR v.segmento_mercado = p_segmento)
    GROUP BY v.tipo_deposito
    ORDER BY COUNT(*) DESC;
$$;

-- P2: cancelación por canal de distribución
CREATE OR REPLACE FUNCTION fn_cancelacion_por_canal(
    p_anio INT DEFAULT NULL, p_hotel TEXT DEFAULT NULL, p_segmento TEXT DEFAULT NULL)
RETURNS TABLE (canal_distribucion VARCHAR, reservas BIGINT, canceladas BIGINT,
               tasa_cancelacion_pct NUMERIC)
LANGUAGE sql STABLE AS $$
    SELECT v.canal_distribucion,
           COUNT(*),
           SUM(v.es_cancelada)::BIGINT,
           ROUND(100.0 * SUM(v.es_cancelada) / COUNT(*), 2)
    FROM vw_reservas_detalle v
    WHERE (p_anio IS NULL     OR v.anio = p_anio)
      AND (p_hotel IS NULL    OR v.hotel = p_hotel)
      AND (p_segmento IS NULL OR v.segmento_mercado = p_segmento)
    GROUP BY v.canal_distribucion
    ORDER BY COUNT(*) DESC;
$$;

-- P3: ingresos confirmados por país (top N)
CREATE OR REPLACE FUNCTION fn_ingresos_por_pais(
    p_anio INT DEFAULT NULL, p_hotel TEXT DEFAULT NULL, p_segmento TEXT DEFAULT NULL,
    p_top INT DEFAULT 10)
RETURNS TABLE (pais VARCHAR, reservas BIGINT, ingresos_confirmados NUMERIC)
LANGUAGE sql STABLE AS $$
    SELECT v.pais,
           COUNT(*),
           COALESCE(SUM(v.ingreso_estimado) FILTER (WHERE v.es_cancelada = 0), 0)
    FROM vw_reservas_detalle v
    WHERE (p_anio IS NULL     OR v.anio = p_anio)
      AND (p_hotel IS NULL    OR v.hotel = p_hotel)
      AND (p_segmento IS NULL OR v.segmento_mercado = p_segmento)
    GROUP BY v.pais
    ORDER BY 3 DESC
    LIMIT p_top;
$$;

-- Listas para los selectores (filtros) del dashboard
CREATE OR REPLACE FUNCTION fn_lista_hoteles()
RETURNS TABLE (nombre_hotel VARCHAR) LANGUAGE sql STABLE AS $$
    SELECT nombre_hotel FROM dim_hotel ORDER BY 1;
$$;

CREATE OR REPLACE FUNCTION fn_lista_anios()
RETURNS TABLE (anio SMALLINT) LANGUAGE sql STABLE AS $$
    SELECT DISTINCT d.anio
    FROM dim_fecha d
    JOIN fact_reservas f ON f.fecha_llegada_key = d.fecha_key
    ORDER BY 1;
$$;

-- ---------------------------------------------------------------------
-- PRUEBAS RÁPIDAS (valores esperados calculados con pandas sobre hotel_clean.csv)
-- ---------------------------------------------------------------------
-- SELECT * FROM fn_cancelacion_por_deposito();
--   Non Refund  -> 14586 reservas, 14493 canceladas (99.36 %)
--   No Deposit  -> 103815 reservas, 29646 canceladas (28.56 %)
--   Refundable  -> 162 reservas, 36 canceladas (22.22 %)
-- SELECT * FROM fn_ingresos_por_pais();
--   1.º PRT 5,540,431.72 | 2.º GBR 4,110,896.61 | 3.º FRA 3,098,418.27
-- SELECT SUM(ingresos_confirmados) FROM fn_adr_ingresos_por_mes(2016, 'City Hotel');
-- SELECT fn_adr_promedio(2016, 'City Hotel');   -- esperado 104.79
