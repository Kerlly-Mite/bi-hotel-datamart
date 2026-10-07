"""
Genera las imágenes del entregable (no necesita conexión a la base de datos):
  docs/diagrama_estrella.png   -> modelo dimensional (esquema estrella)
  docs/mockup_dashboard.png    -> boceto del dashboard

Uso (desde la raíz del proyecto):
    python python/02_diagramas.py
"""
from pathlib import Path
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch

RAIZ = Path(__file__).resolve().parent.parent
DOCS = RAIZ / "docs"
DOCS.mkdir(exist_ok=True)

AZUL, AZUL_CLARO = "#1f4e79", "#dce9f5"
NARANJA, NARANJA_CLARO = "#c55a11", "#fbe5d6"
GRIS = "#595959"


def tabla(ax, x, y, w, titulo, filas, color, color_claro, alto_fila=0.26):
    """Dibuja una tabla (caja con título y lista de columnas)."""
    alto = alto_fila * (len(filas) + 1.4)
    ax.add_patch(FancyBboxPatch((x, y - alto), w, alto, boxstyle="round,pad=0.02",
                                fc=color_claro, ec=color, lw=1.6))
    ax.add_patch(FancyBboxPatch((x, y - alto_fila * 1.3), w, alto_fila * 1.3,
                                boxstyle="round,pad=0.02", fc=color, ec=color, lw=1.6))
    ax.text(x + w / 2, y - alto_fila * 0.65, titulo, ha="center", va="center",
            color="white", fontsize=9.5, fontweight="bold")
    for i, f in enumerate(filas):
        ax.text(x + 0.12, y - alto_fila * (1.75 + i), f, ha="left", va="center",
                fontsize=7.6, color="#222222", family="monospace")
    return alto


def diagrama_estrella():
    fig, ax = plt.subplots(figsize=(15, 9.5))
    ax.set_xlim(0, 15)
    ax.set_ylim(0, 9.5)
    ax.axis("off")

    # Tabla de hechos al centro
    hechos = [
        "PK reserva_key",
        "FK fecha_llegada_key", "FK hotel_key", "FK cliente_key", "FK canal_key",
        "FK habitacion_key", "FK condicion_key", "FK estado_key",
        "-- medidas --",
        "es_cancelada", "tiempo_anticipacion", "noches_fin_semana",
        "noches_semana", "noches_totales", "adultos / ninos / bebes",
        "huespedes_totales", "adr", "ingreso_estimado", "cancelaciones_previas",
        "cambios_reserva", "dias_lista_espera", "estacionamientos_requeridos",
        "solicitudes_especiales",
    ]
    tabla(ax, 5.6, 9.0, 3.8, "fact_reservas (HECHOS)", hechos, NARANJA, NARANJA_CLARO, 0.26)

    dims = {
        "dim_fecha": (0.2, 9.2, ["PK fecha_key (AAAAMMDD)", "fecha", "anio", "trimestre", "mes",
                                  "nombre_mes", "semana_anio", "dia_mes", "dia_semana",
                                  "nombre_dia", "es_fin_de_semana"]),
        "dim_hotel": (0.2, 5.0, ["PK hotel_key", "nombre_hotel"]),
        "dim_cliente": (0.2, 3.6, ["PK cliente_key", "pais_codigo", "tipo_cliente",
                                    "es_huesped_recurrente"]),
        "dim_canal": (10.9, 9.2, ["PK canal_key", "segmento_mercado", "canal_distribucion"]),
        "dim_habitacion": (10.9, 7.3, ["PK habitacion_key", "tipo_reservada", "tipo_asignada",
                                        "es_misma_habitacion"]),
        "dim_condicion_reserva": (10.9, 5.3, ["PK condicion_key", "plan_comida", "tipo_deposito"]),
        "dim_estado_reserva": (10.9, 3.5, ["PK estado_key", "estado_reserva"]),
    }
    anchos = {"dim_fecha": 3.6, "dim_hotel": 3.2, "dim_cliente": 3.6, "dim_canal": 3.9,
              "dim_habitacion": 3.9, "dim_condicion_reserva": 3.9, "dim_estado_reserva": 3.9}
    puntos = {}
    for nombre, (x, y, filas) in dims.items():
        w = anchos[nombre]
        alto = tabla(ax, x, y, w, nombre, filas, AZUL, AZUL_CLARO, 0.26)
        puntos[nombre] = (x, y, w, alto)

    # Conexiones (de cada dimensión al borde de la tabla de hechos)
    destinos = {
        "dim_fecha": (5.6, 7.4), "dim_hotel": (5.6, 6.2), "dim_cliente": (5.6, 5.0),
        "dim_canal": (9.4, 7.4), "dim_habitacion": (9.4, 6.6),
        "dim_condicion_reserva": (9.4, 5.8), "dim_estado_reserva": (9.4, 5.0),
    }
    for nombre, (x, y, w, alto) in puntos.items():
        cy = y - alto / 2
        if x < 5:   # dimensiones a la izquierda
            ax.annotate("", xy=destinos[nombre], xytext=(x + w + 0.04, cy),
                        arrowprops=dict(arrowstyle="-|>", color=GRIS, lw=1.2))
        else:       # dimensiones a la derecha
            ax.annotate("", xy=destinos[nombre], xytext=(x - 0.04, cy),
                        arrowprops=dict(arrowstyle="-|>", color=GRIS, lw=1.2))

    ax.text(7.5, 9.35, "Modelo dimensional (esquema estrella) - Reservas de hotel",
            ha="center", fontsize=14, fontweight="bold", color=AZUL)
    ax.text(7.5, 0.35,
            "Granularidad: una fila de fact_reservas = una reserva de hotel (City Hotel o Resort Hotel) "
            "con su fecha de llegada,\nsin importar si terminó en check-out, cancelación o no-show.",
            ha="center", fontsize=10, style="italic", color=GRIS)
    fig.savefig(DOCS / "diagrama_estrella.png", dpi=150, bbox_inches="tight", facecolor="white")
    plt.close(fig)


def caja(ax, x, y, w, h, texto="", fc="#ffffff", ec="#7f7f7f", fs=9, bold=False, color="#222222"):
    ax.add_patch(FancyBboxPatch((x, y), w, h, boxstyle="round,pad=0.01,rounding_size=0.08",
                                fc=fc, ec=ec, lw=1.2))
    if texto:
        ax.text(x + w / 2, y + h / 2, texto, ha="center", va="center", fontsize=fs,
                fontweight="bold" if bold else "normal", color=color)


def mockup():
    fig, ax = plt.subplots(figsize=(15, 9.5))
    ax.set_xlim(0, 15)
    ax.set_ylim(0, 9.5)
    ax.axis("off")

    # Marco y encabezado
    caja(ax, 0.1, 0.1, 14.8, 9.3, fc="#f7f7f7", ec="#404040")
    caja(ax, 0.1, 8.6, 14.8, 0.8, "Dashboard de Reservas de Hotel  |  Vista: Resumen ejecutivo",
         fc=AZUL, ec=AZUL, fs=14, bold=True, color="white")
    ax.text(14.7, 8.35, "[ Resumen ]   [ Detalle ]", ha="right", fontsize=9, color=GRIS)

    # Filtros
    ax.text(0.4, 8.35, "FILTROS", fontsize=9, fontweight="bold", color=GRIS)
    for i, (et, val) in enumerate([("Año", "Todos  v"), ("Hotel", "Todos  v"),
                                    ("Segmento de mercado", "Todos  v")]):
        x = 1.6 + i * 3.1
        ax.text(x, 8.35, et + ":", fontsize=8.5, color=GRIS)
        caja(ax, x + 0.1 + len(et) * 0.1, 8.15, 1.5, 0.35, val, fc="white", fs=8.5)

    # KPIs
    kpis = [("Tasa de cancelación", "37.26 %", "fn_tasa_cancelacion()"),
            ("ADR (tarifa media por noche)", "$ 102.20", "fn_adr_promedio()"),
            ("Ingresos confirmados", "$ 25.99 M", "fn_ingresos_confirmados()"),
            ("Total de reservas", "118,563", "fn_total_reservas()")]
    for i, (t, v, f) in enumerate(kpis):
        x = 0.4 + i * 3.65
        caja(ax, x, 6.65, 3.45, 1.35, fc="white", ec=NARANJA)
        ax.text(x + 1.72, 7.75, t, ha="center", fontsize=9, color=GRIS)
        ax.text(x + 1.72, 7.25, v, ha="center", fontsize=19, fontweight="bold", color=NARANJA)
        ax.text(x + 1.72, 6.82, f, ha="center", fontsize=7.5, color="#7f7f7f", family="monospace")

    # Gráfico 1: barras reservas por mes + línea tasa
    caja(ax, 0.4, 3.2, 7.2, 3.25, fc="white", ec="#7f7f7f")
    ax.text(0.6, 6.25, "Gráfico 1: Reservas por mes y tasa de cancelación",
            fontsize=9.5, fontweight="bold", color=AZUL)
    import numpy as np
    xs = np.linspace(0.9, 7.2, 12)
    alturas = [0.9, 1.2, 1.4, 1.6, 1.7, 1.8, 2.0, 2.2, 1.7, 1.5, 1.0, 0.9]
    for x, a in zip(xs, alturas):
        ax.add_patch(plt.Rectangle((x - 0.2, 3.75), 0.4, a * 0.85, fc=AZUL_CLARO, ec=AZUL))
    ax.plot(xs, [3.85 + a * 0.9 + 0.25 for a in alturas[::-1]], color=NARANJA, marker="o", ms=3)
    for x, m in zip(xs, ["Ene", "Feb", "Mar", "Abr", "May", "Jun", "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"]):
        ax.text(x, 3.52, m, ha="center", fontsize=7, color=GRIS)
    ax.text(0.6, 3.3, "barras = reservas | línea = % cancelación", ha="left", fontsize=7, color=GRIS)
    ax.text(7.5, 3.3, "fn_reservas_por_mes()", ha="right", fontsize=7.5, color="#7f7f7f", family="monospace")

    # Gráfico 2: barras horizontales cancelación por segmento
    caja(ax, 7.8, 3.2, 6.8, 3.25, fc="white", ec="#7f7f7f")
    ax.text(8.0, 6.25, "Gráfico 2: Tasa de cancelación por segmento de mercado",
            fontsize=9.5, fontweight="bold", color=AZUL)
    segs = [("Groups", 0.69), ("Offline TA/TO", 0.43), ("Online TA", 0.375), ("Corporate", 0.22),
            ("Direct", 0.175)]
    for i, (s, v) in enumerate(segs):
        y = 5.65 - i * 0.43
        ax.text(9.55, y + 0.12, s, ha="right", va="center", fontsize=8, color=GRIS)
        ax.add_patch(plt.Rectangle((9.65, y), v * 4.3, 0.26, fc=NARANJA_CLARO, ec=NARANJA))
        ax.text(9.7 + v * 4.3, y + 0.13, f"{v*100:.0f}%", va="center", fontsize=7.5)
    ax.text(14.5, 3.3, "fn_cancelacion_por_segmento()", ha="right", fontsize=7.5,
            color="#7f7f7f", family="monospace")

    # Tabla de detalle
    caja(ax, 0.4, 0.3, 14.2, 2.7, fc="white", ec="#7f7f7f")
    ax.text(0.6, 2.8, "Tabla de detalle: últimas reservas según los filtros",
            fontsize=9.5, fontweight="bold", color=AZUL)
    cols = ["Fecha llegada", "Hotel", "País", "Segmento", "Noches", "ADR", "Ingreso est.", "Estado"]
    xs_c = [0.7, 2.6, 4.6, 5.7, 7.8, 9.0, 10.3, 12.2]
    for c, x in zip(cols, xs_c):
        ax.text(x, 2.45, c, fontsize=8.5, fontweight="bold", color=AZUL)
    filas = [("2017-08-31", "Resort Hotel", "ESP", "Direct", "2", "184.00", "368.00", "Check-Out"),
             ("2017-08-31", "Resort Hotel", "GBR", "Direct", "7", "187.00", "1,309.00", "Check-Out"),
             ("2017-08-31", "Resort Hotel", "IRL", "Direct", "7", "167.43", "1,172.01", "Check-Out"),
             ("2017-08-31", "City Hotel", "FRA", "Online TA", "3", "142.00", "426.00", "Canceled")]
    for r, fila in enumerate(filas):
        y = 2.1 - r * 0.38
        ax.plot([0.6, 14.4], [y + 0.2, y + 0.2], color="#e0e0e0", lw=0.8)
        for v, x in zip(fila, xs_c):
            ax.text(x, y, v, fontsize=8, color="#222222")
    ax.text(14.4, 0.42, "fn_detalle_reservas()   [paginación: 1 2 3 ...]", ha="right",
            fontsize=7.5, color="#7f7f7f", family="monospace")

    fig.savefig(DOCS / "mockup_dashboard.png", dpi=150, bbox_inches="tight", facecolor="white")
    plt.close(fig)


if __name__ == "__main__":
    diagrama_estrella()
    mockup()
    print("Imágenes generadas en docs/")
