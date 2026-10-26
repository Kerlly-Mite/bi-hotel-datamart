# Matriz de trazabilidad (Entregable 3)

Cada componente de la aplicación Streamlit (`streamlit_app/app.py`) se enlaza con la
pregunta de negocio que responde, los filtros que lo afectan, las tablas del modelo
estrella de donde salen los datos y el objeto SQL que lo calcula.

**Filtros de la aplicación (barra lateral):** Año de llegada (`dim_fecha`),
Hotel (`dim_hotel`) y Segmento de mercado (`dim_canal`).

**Preguntas de negocio:** P1 demanda y precio por mes y hotel · P2 cancelaciones por
segmento, canal y depósito · P3 ingresos por país y segmento.

## Sección 1: Demanda, precio e ingresos

| Componente | Pregunta / KPI | Filtros | Datos utilizados | Vista / Función SQL |
|---|---|---|---|---|
| KPI ADR promedio (ponderado) | P1 · KPI 1 | Año, Hotel, Segmento | `fact_reservas` (`ingreso_estimado`, `noches_totales`) + `dim_fecha`, `dim_hotel`, `dim_canal` | `fn_adr_promedio()` sobre `vw_reservas_detalle` |
| KPI Tasa de cancelación | P2 · KPI 2 | Año, Hotel, Segmento | `fact_reservas` (`es_cancelada`) + `dim_fecha`, `dim_hotel`, `dim_canal` | `fn_tasa_cancelacion()` |
| KPI Ingresos confirmados | P3 · KPI 3 | Año, Hotel, Segmento | `fact_reservas` (`ingreso_estimado`, `es_cancelada`) + dimensiones | `fn_ingresos_confirmados()` |
| KPI Total de reservas (contexto) | Apoyo a P1 y P2 | Año, Hotel, Segmento | `fact_reservas` + dimensiones | `fn_total_reservas()` |
| Gráfico de líneas: ADR por mes y hotel | P1 | Año, Hotel, Segmento | `fact_reservas` + `dim_fecha`, `dim_hotel`, `dim_canal` | `fn_adr_ingresos_por_mes()` (columna `adr`) |
| Gráfico de barras: reservas por mes y hotel | P1 | Año, Hotel, Segmento | `fact_reservas` + `dim_fecha`, `dim_hotel`, `dim_canal` | `fn_adr_ingresos_por_mes()` (columna `reservas`) |
| Gráfico de barras: Top 10 países por ingresos confirmados | P3 | Año, Hotel, Segmento | `fact_reservas` + `dim_cliente` (`pais_codigo`), `dim_fecha`, `dim_hotel`, `dim_canal` | `fn_ingresos_por_pais()` |

## Sección 2: Cancelaciones y detalle

| Componente | Pregunta / KPI | Filtros | Datos utilizados | Vista / Función SQL |
|---|---|---|---|---|
| KPI Tasa de cancelación / Total de reservas / Ingresos confirmados | P2 · KPI 2 (y KPI 3 de contexto) | Año, Hotel, Segmento | `fact_reservas` + dimensiones | `fn_tasa_cancelacion()`, `fn_total_reservas()`, `fn_ingresos_confirmados()` |
| Gráfico de barras: cancelación por segmento (%) | P2 | Año, Hotel (el segmento se aplica sobre el resultado) | `fact_reservas` + `dim_canal` (`segmento_mercado`), `dim_fecha`, `dim_hotel` | `fn_cancelacion_por_segmento()` |
| Gráfico de barras: cancelación por tipo de depósito (%) | P2 | Año, Hotel, Segmento | `fact_reservas` + `dim_condicion_reserva` (`tipo_deposito`) + dimensiones | `fn_cancelacion_por_deposito()` |
| Tabla: cancelación por canal de distribución | P2 | Año, Hotel, Segmento | `fact_reservas` + `dim_canal` (`canal_distribucion`) + dimensiones | `fn_cancelacion_por_canal()` |
| Tabla de detalle de reservas | Detalle detrás de los KPI | Año, Hotel, Segmento, número de filas | `fact_reservas` + todas las dimensiones | `fn_detalle_reservas()` sobre `vw_reservas_detalle` |

## Objetos de apoyo a los filtros

| Elemento | Datos utilizados | Función SQL |
|---|---|---|
| Selector Año | `dim_fecha` + `fact_reservas` | `fn_lista_anios()` |
| Selector Hotel | `dim_hotel` | `fn_lista_hoteles()` |
| Selector Segmento | `dim_canal` | `fn_lista_segmentos()` |

## Cómo se comprobó que la traza es real

- Las funciones de la sección 1 y 2 se ejecutaron en PostgreSQL y devolvieron los
  valores esperados calculados de forma independiente con pandas sobre `hotel_clean.csv`
  (por ejemplo, Non Refund: 14.586 reservas y 14.493 canceladas; ADR 2016 City Hotel: 104,79).
- Los KPI de la aplicación coinciden con las validaciones del Entregable 2
  (118.563 reservas, ADR 102,20, ingresos confirmados 25.986.976).
