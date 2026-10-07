-- =====================================================================
-- 01_schema.sql  |  Data Mart de reservas de hotel (modelo estrella)
-- Crea: tabla de staging, 7 dimensiones y 1 tabla de hechos.
-- Es re-ejecutable: borra y vuelve a crear todo.
--
-- GRANULARIDAD de fact_reservas:
--   Una fila representa UNA RESERVA de hotel (City Hotel o Resort Hotel),
--   con su fecha de llegada, sin importar si terminó en check-out,
--   cancelación o no-show.
-- =====================================================================

DROP VIEW  IF EXISTS vw_reservas_detalle CASCADE;
DROP VIEW  IF EXISTS vw_kpi_mensual CASCADE;
DROP TABLE IF EXISTS fact_reservas        CASCADE;
DROP TABLE IF EXISTS dim_fecha            CASCADE;
DROP TABLE IF EXISTS dim_hotel            CASCADE;
DROP TABLE IF EXISTS dim_cliente          CASCADE;
DROP TABLE IF EXISTS dim_canal            CASCADE;
DROP TABLE IF EXISTS dim_habitacion       CASCADE;
DROP TABLE IF EXISTS dim_condicion_reserva CASCADE;
DROP TABLE IF EXISTS dim_estado_reserva   CASCADE;
DROP TABLE IF EXISTS stg_reservas         CASCADE;

-- ---------------------------------------------------------------------
-- STAGING: copia 1 a 1 del CSV limpio (data/processed/hotel_clean.csv)
-- ---------------------------------------------------------------------
CREATE TABLE stg_reservas (
    hotel                          VARCHAR(20),
    es_cancelada                   SMALLINT,
    tiempo_anticipacion            INTEGER,
    fecha_llegada                  DATE,
    noches_fin_semana              INTEGER,
    noches_semana                  INTEGER,
    adultos                        INTEGER,
    ninos                          INTEGER,
    bebes                          INTEGER,
    plan_comida                    VARCHAR(10),
    pais                           VARCHAR(10),
    segmento_mercado               VARCHAR(30),
    canal_distribucion             VARCHAR(30),
    es_huesped_recurrente          SMALLINT,
    cancelaciones_previas          INTEGER,
    reservas_previas_no_canceladas INTEGER,
    tipo_hab_reservada             VARCHAR(5),
    tipo_hab_asignada              VARCHAR(5),
    cambios_reserva                INTEGER,
    tipo_deposito                  VARCHAR(20),
    dias_lista_espera              INTEGER,
    tipo_cliente                   VARCHAR(30),
    adr                            NUMERIC(10,2),
    estacionamientos_requeridos    INTEGER,
    solicitudes_especiales         INTEGER,
    estado_reserva                 VARCHAR(20),
    fecha_estado_reserva           DATE
);

-- ---------------------------------------------------------------------
-- DIMENSIONES
-- ---------------------------------------------------------------------

-- Dimensión de tiempo (fecha de llegada). Clave inteligente AAAAMMDD.
CREATE TABLE dim_fecha (
    fecha_key        INTEGER      PRIMARY KEY,          -- ej. 20160715
    fecha            DATE         NOT NULL UNIQUE,
    anio             SMALLINT     NOT NULL,
    trimestre        SMALLINT     NOT NULL CHECK (trimestre BETWEEN 1 AND 4),
    mes              SMALLINT     NOT NULL CHECK (mes BETWEEN 1 AND 12),
    nombre_mes       VARCHAR(12)  NOT NULL,
    semana_anio      SMALLINT     NOT NULL,
    dia_mes          SMALLINT     NOT NULL,
    dia_semana       SMALLINT     NOT NULL CHECK (dia_semana BETWEEN 1 AND 7), -- 1=lunes
    nombre_dia       VARCHAR(12)  NOT NULL,
    es_fin_de_semana BOOLEAN      NOT NULL
);

CREATE TABLE dim_hotel (
    hotel_key    SERIAL      PRIMARY KEY,
    nombre_hotel VARCHAR(20) NOT NULL UNIQUE
);

CREATE TABLE dim_cliente (
    cliente_key           SERIAL      PRIMARY KEY,
    pais_codigo           VARCHAR(10) NOT NULL,     -- ISO 3166 (UNK = desconocido)
    tipo_cliente          VARCHAR(30) NOT NULL,
    es_huesped_recurrente BOOLEAN     NOT NULL,
    UNIQUE (pais_codigo, tipo_cliente, es_huesped_recurrente)
);

CREATE TABLE dim_canal (
    canal_key          SERIAL      PRIMARY KEY,
    segmento_mercado   VARCHAR(30) NOT NULL,
    canal_distribucion VARCHAR(30) NOT NULL,
    UNIQUE (segmento_mercado, canal_distribucion)
);

CREATE TABLE dim_habitacion (
    habitacion_key     SERIAL     PRIMARY KEY,
    tipo_reservada     VARCHAR(5) NOT NULL,
    tipo_asignada      VARCHAR(5) NOT NULL,
    es_misma_habitacion BOOLEAN GENERATED ALWAYS AS (tipo_reservada = tipo_asignada) STORED,
    UNIQUE (tipo_reservada, tipo_asignada)
);

CREATE TABLE dim_condicion_reserva (
    condicion_key SERIAL      PRIMARY KEY,
    plan_comida   VARCHAR(10) NOT NULL,   -- BB, HB, FB, SC
    tipo_deposito VARCHAR(20) NOT NULL,   -- No Deposit, Non Refund, Refundable
    UNIQUE (plan_comida, tipo_deposito)
);

CREATE TABLE dim_estado_reserva (
    estado_key     SERIAL      PRIMARY KEY,
    estado_reserva VARCHAR(20) NOT NULL UNIQUE   -- Check-Out, Canceled, No-Show
);

-- ---------------------------------------------------------------------
-- TABLA DE HECHOS
-- ---------------------------------------------------------------------
CREATE TABLE fact_reservas (
    reserva_key        BIGSERIAL PRIMARY KEY,

    -- Claves foráneas hacia las dimensiones
    fecha_llegada_key  INTEGER NOT NULL REFERENCES dim_fecha(fecha_key),
    hotel_key          INTEGER NOT NULL REFERENCES dim_hotel(hotel_key),
    cliente_key        INTEGER NOT NULL REFERENCES dim_cliente(cliente_key),
    canal_key          INTEGER NOT NULL REFERENCES dim_canal(canal_key),
    habitacion_key     INTEGER NOT NULL REFERENCES dim_habitacion(habitacion_key),
    condicion_key      INTEGER NOT NULL REFERENCES dim_condicion_reserva(condicion_key),
    estado_key         INTEGER NOT NULL REFERENCES dim_estado_reserva(estado_key),

    -- Medidas
    es_cancelada                SMALLINT      NOT NULL CHECK (es_cancelada IN (0,1)),
    tiempo_anticipacion         INTEGER       NOT NULL CHECK (tiempo_anticipacion >= 0),
    noches_fin_semana           INTEGER       NOT NULL CHECK (noches_fin_semana >= 0),
    noches_semana               INTEGER       NOT NULL CHECK (noches_semana >= 0),
    noches_totales              INTEGER       NOT NULL CHECK (noches_totales > 0),
    adultos                     INTEGER       NOT NULL CHECK (adultos >= 0),
    ninos                       INTEGER       NOT NULL CHECK (ninos >= 0),
    bebes                       INTEGER       NOT NULL CHECK (bebes >= 0),
    huespedes_totales           INTEGER       NOT NULL CHECK (huespedes_totales > 0),
    adr                         NUMERIC(10,2) NOT NULL CHECK (adr >= 0),
    ingreso_estimado            NUMERIC(12,2) NOT NULL CHECK (ingreso_estimado >= 0), -- adr * noches_totales
    cancelaciones_previas       INTEGER       NOT NULL DEFAULT 0,
    cambios_reserva             INTEGER       NOT NULL DEFAULT 0,
    dias_lista_espera           INTEGER       NOT NULL DEFAULT 0,
    estacionamientos_requeridos INTEGER       NOT NULL DEFAULT 0,
    solicitudes_especiales      INTEGER       NOT NULL DEFAULT 0
);

-- Índices sobre las claves foráneas (aceleran los filtros del dashboard)
CREATE INDEX ix_fact_fecha      ON fact_reservas (fecha_llegada_key);
CREATE INDEX ix_fact_hotel      ON fact_reservas (hotel_key);
CREATE INDEX ix_fact_cliente    ON fact_reservas (cliente_key);
CREATE INDEX ix_fact_canal      ON fact_reservas (canal_key);
CREATE INDEX ix_fact_habitacion ON fact_reservas (habitacion_key);
CREATE INDEX ix_fact_condicion  ON fact_reservas (condicion_key);
CREATE INDEX ix_fact_estado     ON fact_reservas (estado_key);
