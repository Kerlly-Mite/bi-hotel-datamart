-- =====================================================================
-- 05_vistas_funciones.sql  |  Objetos SQL que alimentan el dashboard
--
-- Filtros comunes (todos opcionales: NULL = "todos"):
--   p_anio      -> año de llegada (2015, 2016, 2017)
--   p_hotel     -> 'City Hotel' o 'Resort Hotel'
--   p_segmento  -> segmento de mercado (Online TA, Direct, Groups, ...)
--
-- Definiciones de KPI:
--   Tasa de cancelación  = reservas canceladas / total de reservas * 100
--   ADR (tarifa media)   = ingresos confirmados / noches vendidas (solo es_cancelada = 0)
--   Ingresos confirmados = SUM(adr * noches) de reservas NO canceladas
-- =====================================================================

-- ---------------------------------------------------------------------
-- VISTAS
-- ---------------------------------------------------------------------

-- Vista de detalle: la tabla de hechos "aplanada" con sus dimensiones
CREATE OR REPLACE VIEW vw_reservas_detalle AS
SELECT
    f.reserva_key,
    d.fecha                AS fecha_llegada,
    d.anio, d.trimestre, d.mes, d.nombre_mes, d.es_fin_de_semana,
    h.nombre_hotel         AS hotel,
    c.pais_codigo          AS pais,
    c.tipo_cliente,
    c.es_huesped_recurrente,
    ca.segmento_mercado,
    ca.canal_distribucion,
    hb.tipo_reservada      AS hab_reservada,
    hb.tipo_asignada       AS hab_asignada,
    co.plan_comida,
    co.tipo_deposito,
    e.estado_reserva,
    f.es_cancelada,
    f.tiempo_anticipacion,
    f.noches_totales,
    f.huespedes_totales,
    f.adr,
    f.ingreso_estimado,
    f.solicitudes_especiales
FROM fact_reservas f
JOIN dim_fecha             d  ON d.fecha_key       = f.fecha_llegada_key
JOIN dim_hotel             h  ON h.hotel_key       = f.hotel_key
JOIN dim_cliente           c  ON c.cliente_key     = f.cliente_key
JOIN dim_canal             ca ON ca.canal_key      = f.canal_key
JOIN dim_habitacion        hb ON hb.habitacion_key = f.habitacion_key
JOIN dim_condicion_reserva co ON co.condicion_key  = f.condicion_key
JOIN dim_estado_reserva    e  ON e.estado_key      = f.estado_key;

-- Vista de KPI por mes y hotel
CREATE OR REPLACE VIEW vw_kpi_mensual AS
SELECT
    anio,
    mes,
    nombre_mes,
    hotel,
    COUNT(*)                                                           AS reservas,
    SUM(es_cancelada)                                                  AS canceladas,
    ROUND(100.0 * SUM(es_cancelada) / COUNT(*), 2)                     AS tasa_cancelacion_pct,
    SUM(noches_totales) FILTER (WHERE es_cancelada = 0)                AS noches_vendidas,
    ROUND(SUM(ingreso_estimado) FILTER (WHERE es_cancelada = 0)
          / NULLIF(SUM(noches_totales) FILTER (WHERE es_cancelada = 0), 0), 2) AS adr,
    SUM(ingreso_estimado) FILTER (WHERE es_cancelada = 0)              AS ingresos_confirmados
FROM vw_reservas_detalle
GROUP BY anio, mes, nombre_mes, hotel;

-- ---------------------------------------------------------------------
-- FUNCIONES ESCALARES (tarjetas de KPI)
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fn_total_reservas(
    p_anio INT DEFAULT NULL, p_hotel TEXT DEFAULT NULL, p_segmento TEXT DEFAULT NULL)
RETURNS BIGINT LANGUAGE sql STABLE AS $$
    SELECT COUNT(*)
    FROM vw_reservas_detalle
    WHERE (p_anio IS NULL     OR anio = p_anio)
      AND (p_hotel IS NULL    OR hotel = p_hotel)
      AND (p_segmento IS NULL OR segmento_mercado = p_segmento);
$$;

CREATE OR REPLACE FUNCTION fn_tasa_cancelacion(
    p_anio INT DEFAULT NULL, p_hotel TEXT DEFAULT NULL, p_segmento TEXT DEFAULT NULL)
RETURNS NUMERIC LANGUAGE sql STABLE AS $$
    SELECT ROUND(100.0 * SUM(es_cancelada) / NULLIF(COUNT(*), 0), 2)
    FROM vw_reservas_detalle
    WHERE (p_anio IS NULL     OR anio = p_anio)
      AND (p_hotel IS NULL    OR hotel = p_hotel)
      AND (p_segmento IS NULL OR segmento_mercado = p_segmento);
$$;

CREATE OR REPLACE FUNCTION fn_adr_promedio(
    p_anio INT DEFAULT NULL, p_hotel TEXT DEFAULT NULL, p_segmento TEXT DEFAULT NULL)
RETURNS NUMERIC LANGUAGE sql STABLE AS $$
    SELECT ROUND(SUM(ingreso_estimado) / NULLIF(SUM(noches_totales), 0), 2)
    FROM vw_reservas_detalle
    WHERE es_cancelada = 0
      AND (p_anio IS NULL     OR anio = p_anio)
      AND (p_hotel IS NULL    OR hotel = p_hotel)
      AND (p_segmento IS NULL OR segmento_mercado = p_segmento);
$$;

CREATE OR REPLACE FUNCTION fn_ingresos_confirmados(
    p_anio INT DEFAULT NULL, p_hotel TEXT DEFAULT NULL, p_segmento TEXT DEFAULT NULL)
RETURNS NUMERIC LANGUAGE sql STABLE AS $$
    SELECT COALESCE(SUM(ingreso_estimado), 0)
    FROM vw_reservas_detalle
    WHERE es_cancelada = 0
      AND (p_anio IS NULL     OR anio = p_anio)
      AND (p_hotel IS NULL    OR hotel = p_hotel)
      AND (p_segmento IS NULL OR segmento_mercado = p_segmento);
$$;

-- ---------------------------------------------------------------------
-- FUNCIONES DE TABLA (gráficos y componente de detalle)
-- ---------------------------------------------------------------------

-- Gráfico 1: reservas y tasa de cancelación por mes (línea / barras)
CREATE OR REPLACE FUNCTION fn_reservas_por_mes(
    p_anio INT DEFAULT NULL, p_hotel TEXT DEFAULT NULL, p_segmento TEXT DEFAULT NULL)
RETURNS TABLE (anio SMALLINT, mes SMALLINT, nombre_mes VARCHAR, reservas BIGINT,
               canceladas BIGINT, tasa_cancelacion_pct NUMERIC)
LANGUAGE sql STABLE AS $$
    SELECT v.anio, v.mes, v.nombre_mes,
           COUNT(*),
           SUM(v.es_cancelada)::BIGINT,
           ROUND(100.0 * SUM(v.es_cancelada) / COUNT(*), 2)
    FROM vw_reservas_detalle v
    WHERE (p_anio IS NULL     OR v.anio = p_anio)
      AND (p_hotel IS NULL    OR v.hotel = p_hotel)
      AND (p_segmento IS NULL OR v.segmento_mercado = p_segmento)
    GROUP BY v.anio, v.mes, v.nombre_mes
    ORDER BY v.anio, v.mes;
$$;

-- Gráfico 2: cancelación e ingresos por segmento de mercado (barras)
CREATE OR REPLACE FUNCTION fn_cancelacion_por_segmento(
    p_anio INT DEFAULT NULL, p_hotel TEXT DEFAULT NULL)
RETURNS TABLE (segmento_mercado VARCHAR, reservas BIGINT, canceladas BIGINT,
               tasa_cancelacion_pct NUMERIC, ingresos_confirmados NUMERIC)
LANGUAGE sql STABLE AS $$
    SELECT v.segmento_mercado,
           COUNT(*),
           SUM(v.es_cancelada)::BIGINT,
           ROUND(100.0 * SUM(v.es_cancelada) / COUNT(*), 2),
           COALESCE(SUM(v.ingreso_estimado) FILTER (WHERE v.es_cancelada = 0), 0)
    FROM vw_reservas_detalle v
    WHERE (p_anio IS NULL  OR v.anio = p_anio)
      AND (p_hotel IS NULL OR v.hotel = p_hotel)
    GROUP BY v.segmento_mercado
    ORDER BY COUNT(*) DESC;
$$;

-- Componente de detalle: tabla de reservas con filtros y límite
CREATE OR REPLACE FUNCTION fn_detalle_reservas(
    p_anio INT DEFAULT NULL, p_hotel TEXT DEFAULT NULL, p_segmento TEXT DEFAULT NULL,
    p_limite INT DEFAULT 100)
RETURNS TABLE (fecha_llegada DATE, hotel VARCHAR, pais VARCHAR, segmento_mercado VARCHAR,
               noches_totales INT, adr NUMERIC, ingreso_estimado NUMERIC, estado_reserva VARCHAR)
LANGUAGE sql STABLE AS $$
    SELECT v.fecha_llegada, v.hotel, v.pais, v.segmento_mercado,
           v.noches_totales, v.adr, v.ingreso_estimado, v.estado_reserva
    FROM vw_reservas_detalle v
    WHERE (p_anio IS NULL     OR v.anio = p_anio)
      AND (p_hotel IS NULL    OR v.hotel = p_hotel)
      AND (p_segmento IS NULL OR v.segmento_mercado = p_segmento)
    ORDER BY v.fecha_llegada DESC, v.reserva_key
    LIMIT p_limite;
$$;

-- Filtro: lista de segmentos disponibles para el selector del dashboard
CREATE OR REPLACE FUNCTION fn_lista_segmentos()
RETURNS TABLE (segmento_mercado VARCHAR) LANGUAGE sql STABLE AS $$
    SELECT DISTINCT segmento_mercado FROM dim_canal ORDER BY 1;
$$;

-- ---------------------------------------------------------------------
-- PRUEBAS RÁPIDAS (descomenta para probar)
-- ---------------------------------------------------------------------
-- SELECT fn_total_reservas();
-- SELECT fn_tasa_cancelacion(2016, 'City Hotel');
-- SELECT fn_adr_promedio(NULL, 'Resort Hotel');
-- SELECT fn_ingresos_confirmados(2017);
-- SELECT * FROM fn_reservas_por_mes(2016);
-- SELECT * FROM fn_cancelacion_por_segmento(NULL, 'City Hotel');
-- SELECT * FROM fn_detalle_reservas(2017, 'Resort Hotel', 'Direct', 10);
-- SELECT * FROM vw_kpi_mensual ORDER BY anio, mes, hotel;
