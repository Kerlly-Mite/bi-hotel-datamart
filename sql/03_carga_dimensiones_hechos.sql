-- =====================================================================
-- 03_carga_dimensiones_hechos.sql
-- Llena las dimensiones (con DISTINCT sobre staging) y luego la tabla
-- de hechos, buscando la clave sustituta de cada dimensión con un JOIN.
-- Re-ejecutable: vacía las tablas antes de cargar.
-- =====================================================================

TRUNCATE TABLE fact_reservas, dim_fecha, dim_hotel, dim_cliente, dim_canal,
               dim_habitacion, dim_condicion_reserva, dim_estado_reserva
               RESTART IDENTITY CASCADE;

-- 1) dim_fecha: calendario completo 2015-2017 generado con generate_series
INSERT INTO dim_fecha (fecha_key, fecha, anio, trimestre, mes, nombre_mes,
                       semana_anio, dia_mes, dia_semana, nombre_dia, es_fin_de_semana)
SELECT
    TO_CHAR(d, 'YYYYMMDD')::INTEGER,
    d::DATE,
    EXTRACT(YEAR    FROM d)::SMALLINT,
    EXTRACT(QUARTER FROM d)::SMALLINT,
    EXTRACT(MONTH   FROM d)::SMALLINT,
    (ARRAY['Enero','Febrero','Marzo','Abril','Mayo','Junio','Julio','Agosto',
           'Septiembre','Octubre','Noviembre','Diciembre'])[EXTRACT(MONTH FROM d)::INT],
    EXTRACT(WEEK    FROM d)::SMALLINT,
    EXTRACT(DAY     FROM d)::SMALLINT,
    EXTRACT(ISODOW  FROM d)::SMALLINT,
    (ARRAY['Lunes','Martes','Miércoles','Jueves','Viernes','Sábado','Domingo'])[EXTRACT(ISODOW FROM d)::INT],
    EXTRACT(ISODOW FROM d) IN (6, 7)
FROM generate_series('2015-01-01'::DATE, '2017-12-31'::DATE, INTERVAL '1 day') AS d;

-- 2) Dimensiones descriptivas
INSERT INTO dim_hotel (nombre_hotel)
SELECT DISTINCT hotel FROM stg_reservas ORDER BY hotel;

INSERT INTO dim_cliente (pais_codigo, tipo_cliente, es_huesped_recurrente)
SELECT DISTINCT pais, tipo_cliente, (es_huesped_recurrente = 1)
FROM stg_reservas
ORDER BY 1, 2, 3;

INSERT INTO dim_canal (segmento_mercado, canal_distribucion)
SELECT DISTINCT segmento_mercado, canal_distribucion
FROM stg_reservas
ORDER BY 1, 2;

INSERT INTO dim_habitacion (tipo_reservada, tipo_asignada)
SELECT DISTINCT tipo_hab_reservada, tipo_hab_asignada
FROM stg_reservas
ORDER BY 1, 2;

INSERT INTO dim_condicion_reserva (plan_comida, tipo_deposito)
SELECT DISTINCT plan_comida, tipo_deposito
FROM stg_reservas
ORDER BY 1, 2;

INSERT INTO dim_estado_reserva (estado_reserva)
SELECT DISTINCT estado_reserva FROM stg_reservas ORDER BY 1;

-- 3) Tabla de hechos: una fila por fila de staging (= una reserva)
INSERT INTO fact_reservas (
    fecha_llegada_key, hotel_key, cliente_key, canal_key, habitacion_key,
    condicion_key, estado_key,
    es_cancelada, tiempo_anticipacion, noches_fin_semana, noches_semana,
    noches_totales, adultos, ninos, bebes, huespedes_totales, adr,
    ingreso_estimado, cancelaciones_previas, cambios_reserva,
    dias_lista_espera, estacionamientos_requeridos, solicitudes_especiales
)
SELECT
    TO_CHAR(s.fecha_llegada, 'YYYYMMDD')::INTEGER,
    h.hotel_key,
    c.cliente_key,
    ca.canal_key,
    hb.habitacion_key,
    co.condicion_key,
    e.estado_key,
    s.es_cancelada,
    s.tiempo_anticipacion,
    s.noches_fin_semana,
    s.noches_semana,
    s.noches_fin_semana + s.noches_semana,
    s.adultos,
    s.ninos,
    s.bebes,
    s.adultos + s.ninos + s.bebes,
    s.adr,
    ROUND(s.adr * (s.noches_fin_semana + s.noches_semana), 2),
    s.cancelaciones_previas,
    s.cambios_reserva,
    s.dias_lista_espera,
    s.estacionamientos_requeridos,
    s.solicitudes_especiales
FROM stg_reservas s
JOIN dim_hotel             h  ON h.nombre_hotel = s.hotel
JOIN dim_cliente           c  ON c.pais_codigo = s.pais
                             AND c.tipo_cliente = s.tipo_cliente
                             AND c.es_huesped_recurrente = (s.es_huesped_recurrente = 1)
JOIN dim_canal             ca ON ca.segmento_mercado = s.segmento_mercado
                             AND ca.canal_distribucion = s.canal_distribucion
JOIN dim_habitacion        hb ON hb.tipo_reservada = s.tipo_hab_reservada
                             AND hb.tipo_asignada = s.tipo_hab_asignada
JOIN dim_condicion_reserva co ON co.plan_comida = s.plan_comida
                             AND co.tipo_deposito = s.tipo_deposito
JOIN dim_estado_reserva    e  ON e.estado_reserva = s.estado_reserva;

-- Resumen de la carga
SELECT 'dim_fecha' AS tabla, COUNT(*) AS filas FROM dim_fecha
UNION ALL SELECT 'dim_hotel', COUNT(*) FROM dim_hotel
UNION ALL SELECT 'dim_cliente', COUNT(*) FROM dim_cliente
UNION ALL SELECT 'dim_canal', COUNT(*) FROM dim_canal
UNION ALL SELECT 'dim_habitacion', COUNT(*) FROM dim_habitacion
UNION ALL SELECT 'dim_condicion_reserva', COUNT(*) FROM dim_condicion_reserva
UNION ALL SELECT 'dim_estado_reserva', COUNT(*) FROM dim_estado_reserva
UNION ALL SELECT 'fact_reservas', COUNT(*) FROM fact_reservas;
