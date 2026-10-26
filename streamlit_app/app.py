"""
Dashboard de Business Intelligence - Hotel booking demand
Entregable 3 | Inteligencia de Negocios | UPSE

IMPORTANTE: esta app NO lee el CSV. Todos los datos salen de PostgreSQL
mediante las vistas y funciones SQL (sql/05 y sql/06).

Ejecutar:  streamlit run streamlit_app/app.py
"""
import os

import pandas as pd
import psycopg2
import streamlit as st

# ---------------------------------------------------------------------
# Configuración de la conexión (coincide con docker-compose.yml)
# ---------------------------------------------------------------------
DB_CONFIG = {
    "host": os.getenv("PGHOST", "localhost"),
    "port": int(os.getenv("PGPORT", "5433")),
    "dbname": os.getenv("PGDATABASE", "bi_database"),
    "user": os.getenv("PGUSER", "bi_user"),
    "password": os.getenv("PGPASSWORD", "bi_password"),
}

st.set_page_config(page_title="BI Hoteles Portugal", page_icon="🏨", layout="wide")

# ---------------------------------------------------------------------
# Estilo visual (solo apariencia; no cambia ninguna consulta)
# ---------------------------------------------------------------------
COLOR_CITY = "#0f766e"      # City Hotel / color principal
COLOR_RESORT = "#f59e0b"    # Resort Hotel
COLOR_CANCEL = "#be3a4a"    # cancelaciones
COLOR_INGRESO = "#d97706"   # ingresos
HOTEL_COLORS = {"City Hotel": COLOR_CITY, "Resort Hotel": COLOR_RESORT}

st.markdown(
    """
    <style>
    .block-container {padding-top: 1.6rem; max-width: 1300px;}
    .hero {
        background: linear-gradient(120deg, #0f766e 0%, #115e59 55%, #134e4a 100%);
        color: #ffffff; padding: 22px 28px; border-radius: 14px; margin-bottom: 18px;
    }
    .hero h1 {margin: 0; font-size: 1.9rem; color: #ffffff; font-weight: 700;}
    .hero p {margin: 4px 0 0 0; font-size: 0.92rem; color: #d1faf4;}
    [data-testid="stMetric"] {
        background: #ffffff; border: 1px solid #dbe7e5; border-left: 6px solid #0f766e;
        border-radius: 10px; padding: 14px 16px; box-shadow: 0 1px 4px rgba(15, 118, 110, 0.10);
    }
    [data-testid="stMetricLabel"] p {font-size: 0.85rem; color: #52606d;}
    [data-testid="stMetricValue"] {font-size: 1.9rem; font-weight: 700; color: #0f2e2b;}
    h2, h3 {color: #0f2e2b;}
    section[data-testid="stSidebar"] {border-right: 1px solid #d5e4e1;}
    </style>
    """,
    unsafe_allow_html=True,
)


def hero(titulo: str, subtitulo: str):
    """Banner de encabezado de cada sección."""
    st.markdown(f'<div class="hero"><h1>{titulo}</h1><p>{subtitulo}</p></div>',
                unsafe_allow_html=True)


@st.cache_resource
def obtener_conexion():
    """Abre UNA conexión a PostgreSQL y la reutiliza entre ejecuciones."""
    conn = psycopg2.connect(**DB_CONFIG)
    conn.autocommit = True
    return conn


@st.cache_data(ttl=300)
def consultar(sql: str, params: tuple = ()) -> pd.DataFrame:
    """Ejecuta una consulta parametrizada y devuelve un DataFrame."""
    conn = obtener_conexion()
    with conn.cursor() as cur:
        cur.execute(sql, params)
        columnas = [c[0] for c in cur.description]
        filas = cur.fetchall()
    df = pd.DataFrame(filas, columns=columnas)
    for col in df.columns:  # NUMERIC de PostgreSQL llega como Decimal
        if df[col].dtype == object:
            try:
                df[col] = pd.to_numeric(df[col])
            except (ValueError, TypeError):
                pass
    return df


# ---------------------------------------------------------------------
# Filtros (barra lateral) -> se convierten en parámetros de las funciones SQL
# ---------------------------------------------------------------------
def todos_o_none(valor):
    return None if valor == "Todos" else valor


try:
    anios = consultar("SELECT anio FROM fn_lista_anios()")["anio"].tolist()
    hoteles = consultar("SELECT nombre_hotel FROM fn_lista_hoteles()")["nombre_hotel"].tolist()
    segmentos = consultar("SELECT segmento_mercado FROM fn_lista_segmentos()")["segmento_mercado"].tolist()
except psycopg2.OperationalError as e:
    st.error("No se pudo conectar a PostgreSQL. ¿Está corriendo Docker (`docker compose up -d`)?")
    st.code(str(e))
    st.stop()

st.sidebar.title("🏨 BI Hoteles")
pagina = st.sidebar.radio(
    "Sección",
    ["📈 Demanda, precio e ingresos", "❌ Cancelaciones y detalle"],
)
st.sidebar.header("Filtros")
f_anio = todos_o_none(st.sidebar.selectbox("Año de llegada", ["Todos"] + anios))
f_hotel = todos_o_none(st.sidebar.selectbox("Hotel", ["Todos"] + hoteles))
f_segmento = todos_o_none(st.sidebar.selectbox("Segmento de mercado", ["Todos"] + segmentos))

# Los tres filtros viajan SIEMPRE a PostgreSQL en este orden
P = (f_anio, f_hotel, f_segmento)
FILTROS_SQL = "%s::int, %s::text, %s::text"

st.sidebar.caption(
    "Datos: Hotel booking demand (Kaggle), jul 2015 - ago 2017. "
    "2015 y 2017 son años parciales: compara mes contra mes."
)


def kpi_escalar(funcion: str):
    """Llama a una función escalar de PostgreSQL con los filtros activos."""
    df = consultar(f"SELECT {funcion}({FILTROS_SQL}) AS valor", P)
    valor = df["valor"].iloc[0]
    return None if pd.isna(valor) else float(valor)


def fmt(valor, prefijo="", sufijo="", decimales=2):
    if valor is None:
        return "—"
    return f"{prefijo}{valor:,.{decimales}f}{sufijo}"


# =====================================================================
# SECCIÓN 1: Demanda, precio e ingresos  (P1 y P3)
# =====================================================================
if pagina.startswith("📈"):
    hero("Demanda, precio e ingresos",
         "P1: ¿cómo cambian demanda y precio a lo largo del año? · "
         "P3: ¿cuánto ingreso generan y qué países aportan más?")

    # --- KPI (3 principales + total de reservas como contexto) ---
    c1, c2, c3, c4 = st.columns(4)
    c1.metric("ADR promedio (ponderado)", fmt(kpi_escalar("fn_adr_promedio")),
              help="Ingreso de reservas no canceladas / noches vendidas")
    c2.metric("Tasa de cancelación", fmt(kpi_escalar("fn_tasa_cancelacion"), sufijo=" %"),
              help="Reservas canceladas / total de reservas")
    c3.metric("Ingresos confirmados", fmt(kpi_escalar("fn_ingresos_confirmados"), decimales=0),
              help="Suma de ADR x noches de reservas no canceladas (moneda no indicada)")
    c4.metric("Total de reservas", fmt(kpi_escalar("fn_total_reservas"), decimales=0))

    st.divider()

    # --- Gráfico 1: ADR por mes y hotel (P1) ---
    mensual = consultar(f"SELECT * FROM fn_adr_ingresos_por_mes({FILTROS_SQL})", P)
    st.subheader("ADR por mes y hotel")
    if mensual.empty:
        st.info("No hay datos para la combinación de filtros elegida.")
    else:
        mensual["periodo"] = (mensual["anio"].astype(str) + "-"
                              + mensual["mes"].astype(str).str.zfill(2))
        pivot_adr = mensual.pivot_table(index="periodo", columns="hotel",
                                        values="adr", aggfunc="mean").sort_index()
        st.line_chart(pivot_adr, color=[HOTEL_COLORS.get(c, COLOR_CITY) for c in pivot_adr.columns])

        st.subheader("Reservas por mes y hotel")
        pivot_res = mensual.pivot_table(index="periodo", columns="hotel",
                                        values="reservas", aggfunc="sum").sort_index()
        st.bar_chart(pivot_res, color=[HOTEL_COLORS.get(c, COLOR_CITY) for c in pivot_res.columns])

    # --- Gráfico 2: ingresos por país (P3) ---
    st.subheader("Top 10 países por ingresos confirmados")
    paises = consultar(f"SELECT * FROM fn_ingresos_por_pais({FILTROS_SQL}, 10)", P)
    if paises.empty:
        st.info("No hay datos para la combinación de filtros elegida.")
    else:
        st.bar_chart(paises.set_index("pais")["ingresos_confirmados"], color=COLOR_INGRESO)

# =====================================================================
# SECCIÓN 2: Cancelaciones y detalle  (P2)
# =====================================================================
else:
    hero("Cancelaciones y detalle de reservas",
         "P2: ¿qué segmentos, canales y tipos de depósito concentran más cancelaciones?")

    k1, k2, k3 = st.columns(3)
    k1.metric("Tasa de cancelación", fmt(kpi_escalar("fn_tasa_cancelacion"), sufijo=" %"))
    k2.metric("Total de reservas", fmt(kpi_escalar("fn_total_reservas"), decimales=0))
    k3.metric("Ingresos confirmados", fmt(kpi_escalar("fn_ingresos_confirmados"), decimales=0))

    st.divider()
    col_a, col_b = st.columns(2)

    with col_a:
        st.subheader("Cancelación por segmento (%)")
        # fn_cancelacion_por_segmento solo recibe año y hotel (no segmento)
        seg = consultar("SELECT * FROM fn_cancelacion_por_segmento(%s::int, %s::text)",
                        (f_anio, f_hotel))
        if f_segmento:
            seg = seg[seg["segmento_mercado"] == f_segmento]
        if seg.empty:
            st.info("Sin datos para estos filtros.")
        else:
            st.bar_chart(seg.set_index("segmento_mercado")["tasa_cancelacion_pct"], color=COLOR_CANCEL)

    with col_b:
        st.subheader("Cancelación por tipo de depósito (%)")
        dep = consultar(f"SELECT * FROM fn_cancelacion_por_deposito({FILTROS_SQL})", P)
        if dep.empty:
            st.info("Sin datos para estos filtros.")
        else:
            st.bar_chart(dep.set_index("tipo_deposito")["tasa_cancelacion_pct"], color=COLOR_CANCEL)

    st.subheader("Cancelación por canal de distribución")
    canal = consultar(f"SELECT * FROM fn_cancelacion_por_canal({FILTROS_SQL})", P)
    st.dataframe(canal, use_container_width=True, hide_index=True)

    st.subheader("Detalle de reservas")
    limite = st.slider("Filas a mostrar", 10, 500, 100, step=10)
    detalle = consultar(f"SELECT * FROM fn_detalle_reservas({FILTROS_SQL}, %s::int)", P + (limite,))
    st.dataframe(detalle, use_container_width=True, hide_index=True)
