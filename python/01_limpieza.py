"""
Entregable 2 - Data Mart de reservas de hotel
Paso 1: limpieza y transformación del dataset original (Kaggle: Hotel booking demand).

Entrada : data/raw/hotel_bookings.csv
Salida  : data/processed/hotel_clean.csv   (listo para cargar a PostgreSQL)
          docs/log_limpieza.txt            (evidencia de las transformaciones)

Uso (desde la raíz del proyecto):
    python python/01_limpieza.py
"""
from pathlib import Path
import pandas as pd

RAIZ = Path(__file__).resolve().parent.parent
ENTRADA = RAIZ / "data" / "raw" / "hotel_bookings.csv"
SALIDA = RAIZ / "data" / "processed" / "hotel_clean.csv"
LOG = RAIZ / "docs" / "log_limpieza.txt"

lineas = []


def log(texto=""):
    print(texto)
    lineas.append(texto)


def main():
    df = pd.read_csv(ENTRADA)  # la cadena "NULL" ya se lee como valor nulo
    n0 = len(df)
    log("=== LOG DE LIMPIEZA - hotel_bookings.csv ===")
    log(f"Filas originales: {n0:,}  |  Columnas originales: {df.shape[1]}")
    log()

    # 1. Columnas con demasiados nulos: se descartan
    log("[1] Columnas descartadas")
    for col in ["company", "agent"]:
        pct = df[col].isna().mean() * 100
        log(f"    - {col}: {pct:.1f}% de nulos -> columna eliminada")
    df = df.drop(columns=["company", "agent"])
    log()

    # 2. Nulos en columnas que se conservan
    log("[2] Tratamiento de valores nulos")
    n_ch = df["children"].isna().sum()
    df["children"] = df["children"].fillna(0).astype(int)
    log(f"    - children: {n_ch} nulos -> 0")
    n_pa = df["country"].isna().sum()
    df["country"] = df["country"].fillna("UNK")
    log(f"    - country: {n_pa} nulos -> 'UNK' (desconocido)")
    log()

    # 3. Categorías 'Undefined'
    log("[3] Categorías 'Undefined'")
    n_meal = (df["meal"] == "Undefined").sum()
    df["meal"] = df["meal"].replace("Undefined", "SC")  # según la documentación Undefined = SC
    log(f"    - meal: {n_meal:,} 'Undefined' -> 'SC' (sin plan de comida)")
    for col in ["market_segment", "distribution_channel"]:
        n = (df[col] == "Undefined").sum()
        df[col] = df[col].replace("Undefined", "Unknown")
        log(f"    - {col}: {n} 'Undefined' -> 'Unknown'")
    log()

    # 4. Filas inválidas
    log("[4] Filas inválidas eliminadas")
    huespedes = df["adults"] + df["children"] + df["babies"]
    noches = df["stays_in_weekend_nights"] + df["stays_in_week_nights"]
    m_huesp = huespedes == 0
    m_noches = noches == 0
    m_adr_neg = df["adr"] < 0
    m_adr_out = df["adr"] > 1000
    log(f"    - Reservas con 0 huéspedes: {m_huesp.sum()}")
    log(f"    - Reservas con 0 noches: {m_noches.sum()}")
    log(f"    - ADR negativo: {m_adr_neg.sum()}")
    log(f"    - ADR atípico (> 1000): {m_adr_out.sum()}")
    invalidas = m_huesp | m_noches | m_adr_neg | m_adr_out
    df = df[~invalidas].copy()
    log(f"    Total eliminadas (sin doble conteo): {invalidas.sum():,}")
    log()

    # 5. Fecha de llegada (año + mes en texto + día -> DATE)
    log("[5] Construcción de la fecha de llegada")
    meses = {m: i for i, m in enumerate(
        ["January", "February", "March", "April", "May", "June", "July",
         "August", "September", "October", "November", "December"], start=1)}
    df["fecha_llegada"] = pd.to_datetime(
        dict(year=df["arrival_date_year"],
             month=df["arrival_date_month"].map(meses),
             day=df["arrival_date_day_of_month"])
    ).dt.strftime("%Y-%m-%d")
    log("    - arrival_date_year/month/day_of_month -> fecha_llegada (YYYY-MM-DD)")
    log(f"    - Rango: {df['fecha_llegada'].min()} a {df['fecha_llegada'].max()}")
    log()

    # 6. Duplicados
    dup = df.duplicated().sum()
    log("[6] Filas duplicadas")
    log(f"    - {dup:,} filas idénticas. NO se eliminan: el dataset no tiene un ID de reserva,")
    log("      así que no se puede distinguir un duplicado real de dos reservas distintas")
    log("      con las mismas características (ej. una familia que reserva 2 habitaciones iguales).")
    log()

    # 7. Renombrar columnas a español (nombres finales del staging)
    renombrar = {
        "hotel": "hotel",
        "is_canceled": "es_cancelada",
        "lead_time": "tiempo_anticipacion",
        "stays_in_weekend_nights": "noches_fin_semana",
        "stays_in_week_nights": "noches_semana",
        "adults": "adultos",
        "children": "ninos",
        "babies": "bebes",
        "meal": "plan_comida",
        "country": "pais",
        "market_segment": "segmento_mercado",
        "distribution_channel": "canal_distribucion",
        "is_repeated_guest": "es_huesped_recurrente",
        "previous_cancellations": "cancelaciones_previas",
        "previous_bookings_not_canceled": "reservas_previas_no_canceladas",
        "reserved_room_type": "tipo_hab_reservada",
        "assigned_room_type": "tipo_hab_asignada",
        "booking_changes": "cambios_reserva",
        "deposit_type": "tipo_deposito",
        "days_in_waiting_list": "dias_lista_espera",
        "customer_type": "tipo_cliente",
        "adr": "adr",
        "required_car_parking_spaces": "estacionamientos_requeridos",
        "total_of_special_requests": "solicitudes_especiales",
        "reservation_status": "estado_reserva",
        "reservation_status_date": "fecha_estado_reserva",
    }
    df = df.rename(columns=renombrar)
    orden = ["hotel", "es_cancelada", "tiempo_anticipacion", "fecha_llegada",
             "noches_fin_semana", "noches_semana", "adultos", "ninos", "bebes",
             "plan_comida", "pais", "segmento_mercado", "canal_distribucion",
             "es_huesped_recurrente", "cancelaciones_previas",
             "reservas_previas_no_canceladas", "tipo_hab_reservada",
             "tipo_hab_asignada", "cambios_reserva", "tipo_deposito",
             "dias_lista_espera", "tipo_cliente", "adr",
             "estacionamientos_requeridos", "solicitudes_especiales",
             "estado_reserva", "fecha_estado_reserva"]
    df = df[orden]
    log("[7] Columnas renombradas a español y reordenadas")
    log()

    SALIDA.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(SALIDA, index=False)
    log("=== RESUMEN ===")
    log(f"Filas originales : {n0:,}")
    log(f"Filas finales    : {len(df):,}  ({n0 - len(df):,} eliminadas, {(n0 - len(df)) / n0 * 100:.2f}%)")
    log(f"Columnas finales : {df.shape[1]}")
    log(f"Archivo generado : {SALIDA.relative_to(RAIZ)}")

    LOG.parent.mkdir(parents=True, exist_ok=True)
    LOG.write_text("\n".join(lineas), encoding="utf-8")


if __name__ == "__main__":
    main()
