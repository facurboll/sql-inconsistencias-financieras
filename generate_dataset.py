"""
Generador de dataset: Superstore Sales (adaptado)
Proyecto: Detección de Inconsistencias Financieras con SQL
Autor: Facundo Iván Ramírez Boll

Uso:
    pip install pandas numpy faker
    python generate_dataset.py

Genera: superstore_ventas.csv (5000 registros aprox.)
Luego importar con:
    \COPY ventas FROM 'superstore_ventas.csv' CSV HEADER;
"""

import pandas as pd
import numpy as np
from faker import Faker
import random
from datetime import date, timedelta

fake = Faker('es_AR')
random.seed(42)
np.random.seed(42)

# ── Catálogo de productos ─────────────────────────────────────────────────────

PRODUCTOS = {
    "Tecnología": {
        "Teléfonos":     [("TEC-PH-001","iPhone 14 Pro"),("TEC-PH-002","Samsung Galaxy S23"),
                          ("TEC-PH-003","Motorola Edge 40"),("TEC-PH-004","Xiaomi 13T")],
        "Computadoras":  [("TEC-CO-001","MacBook Air M2"),("TEC-CO-002","Dell XPS 15"),
                          ("TEC-CO-003","HP Pavilion 15"),("TEC-CO-004","Lenovo ThinkPad E15")],
        "Accesorios":    [("TEC-AC-001","Auriculares Sony WH-1000XM5"),("TEC-AC-002","Mouse Logitech MX Master"),
                          ("TEC-AC-003","Teclado Mecánico Redragon"),("TEC-AC-004","Monitor LG 27\"")],
    },
    "Mobiliario": {
        "Sillas":        [("MOB-SI-001","Silla Ergonómica Herman Miller"),("MOB-SI-002","Silla Ejecutiva OFX"),
                          ("MOB-SI-003","Silla Gamer DXRacer"),("MOB-SI-004","Silla de Escritorio Basic")],
        "Mesas":         [("MOB-ME-001","Mesa de Reuniones 180cm"),("MOB-ME-002","Escritorio Standing Desk"),
                          ("MOB-ME-003","Mesa Auxiliar Nórdica"),("MOB-ME-004","Escritorio L-Shape")],
        "Almacenamiento":[("MOB-AL-001","Estantería Metálica 5 Niveles"),("MOB-AL-002","Archivero 4 Cajones"),
                          ("MOB-AL-003","Biblioteca Modular"),("MOB-AL-004","Lockers Oficina x4")],
    },
    "Librería": {
        "Papel":         [("LIB-PA-001","Resma A4 500 hojas"),("LIB-PA-002","Papel Fotográfico A4"),
                          ("LIB-PA-003","Carpetas Archivadoras x10"),("LIB-PA-004","Blocks de Notas x5")],
        "Aglutinantes":  [("LIB-AG-001","Biblioratos x12"),("LIB-AG-002","Separadores Plásticos"),
                          ("LIB-AG-003","Clips y Broches Surtidos"),("LIB-AG-004","Ganchos para Colgar")],
        "Escritura":     [("LIB-ES-001","Lapiceras Bic x50"),("LIB-ES-002","Marcadores Permanentes x12"),
                          ("LIB-ES-003","Resaltadores Surtidos x6"),("LIB-ES-004","Corrector Líquido x6")],
    },
}

CIUDADES = [
    ("Buenos Aires","Buenos Aires"),("Córdoba","Córdoba"),("Rosario","Santa Fe"),
    ("Mendoza","Mendoza"),("Tucumán","Tucumán"),("La Plata","Buenos Aires"),
    ("Mar del Plata","Buenos Aires"),("Salta","Salta"),("Santa Fe","Santa Fe"),
    ("Corrientes","Corrientes"),("Resistencia","Chaco"),("Posadas","Misiones"),
    ("Neuquén","Neuquén"),("Bahía Blanca","Buenos Aires"),("San Juan","San Juan"),
]

SEGMENTOS      = ["Consumidor", "Corporativo", "Gobierno"]
MODOS_ENVIO    = ["Primera Clase", "Segunda Clase", "Estándar", "Mismo Día"]

# ── Precios base por subcategoría ─────────────────────────────────────────────

PRECIO_BASE = {
    "Teléfonos":600,"Computadoras":1200,"Accesorios":150,
    "Sillas":400,"Mesas":500,"Almacenamiento":300,
    "Papel":30,"Aglutinantes":25,"Escritura":20,
}

MARGEN_BASE = {
    "Teléfonos":0.20,"Computadoras":0.18,"Accesorios":0.30,
    "Sillas":0.35,"Mesas":0.32,"Almacenamiento":0.28,
    "Papel":0.40,"Aglutinantes":0.45,"Escritura":0.50,
}


def generar_fecha(inicio=date(2021,1,1), fin=date(2024,12,31)):
    delta = (fin - inicio).days
    return inicio + timedelta(days=random.randint(0, delta))


def generar_orden_id(n):
    return f"ORD-{2021 + n // 500}-{str(n).zfill(5)}"


def construir_registro(n, inyectar_anomalia=False):
    cat = random.choice(list(PRODUCTOS.keys()))
    subcat = random.choice(list(PRODUCTOS[cat].keys()))
    prod_id, prod_nombre = random.choice(PRODUCTOS[cat][subcat])
    ciudad, provincia = random.choice(CIUDADES)
    segmento = random.choices(SEGMENTOS, weights=[50,35,15])[0]
    modo = random.choices(MODOS_ENVIO, weights=[25,30,35,10])[0]

    precio_base = PRECIO_BASE[subcat]
    precio = round(precio_base * random.uniform(0.8, 1.5), 2)
    cantidad = random.randint(1, 10)
    ventas = round(precio * cantidad, 2)

    margen_base = MARGEN_BASE[subcat]

    # Inyectar anomalías para que los queries las detecten
    if inyectar_anomalia:
        tipo = random.choice(["descuento_extremo","perdida_directa","margen_negativo"])
        if tipo == "descuento_extremo":
            descuento = round(random.uniform(0.55, 0.85), 4)
        elif tipo == "perdida_directa":
            descuento = round(random.uniform(0.0, 0.2), 4)
            margen_base = random.uniform(-0.30, -0.05)
        else:
            descuento = round(random.uniform(0.3, 0.5), 4)
            margen_base = random.uniform(-0.15, 0.0)
    else:
        descuento = round(random.choices(
            [0, 0.05, 0.10, 0.15, 0.20, 0.30, 0.40, 0.50],
            weights=[30, 20, 20, 10, 10, 5, 3, 2]
        )[0], 4)

    ventas_netas = round(ventas * (1 - descuento), 2)
    ganancia = round(ventas_netas * margen_base * random.uniform(0.85, 1.15), 2)

    fecha_orden = generar_fecha()
    dias_envio  = {"Primera Clase":2,"Segunda Clase":5,"Estándar":7,"Mismo Día":0}[modo]
    fecha_envio = fecha_orden + timedelta(days=dias_envio + random.randint(0,1))

    cliente_id  = f"CLI-{random.randint(1000,9999)}"
    orden_id    = generar_orden_id(n)

    return {
        "orden_id":       orden_id,
        "fecha_orden":    fecha_orden,
        "fecha_envio":    fecha_envio,
        "modo_envio":     modo,
        "cliente_id":     cliente_id,
        "cliente_nombre": fake.name(),
        "segmento":       segmento,
        "ciudad":         ciudad,
        "provincia":      provincia,
        "pais":           "Argentina",
        "categoria":      cat,
        "subcategoria":   subcat,
        "producto_id":    prod_id,
        "producto_nombre":prod_nombre,
        "ventas":         ventas_netas,
        "cantidad":       cantidad,
        "descuento":      descuento,
        "ganancia":       ganancia,
    }


def main():
    N_TOTAL    = 5000
    N_ANOMALAS = 450   # ~9% de anomalías — realista para auditoría

    print(f"Generando {N_TOTAL} registros ({N_ANOMALAS} con anomalías)...")

    registros = []
    indices_anomalos = set(random.sample(range(N_TOTAL), N_ANOMALAS))

    for i in range(N_TOTAL):
        registros.append(construir_registro(i, inyectar_anomalia=(i in indices_anomalos)))

    df = pd.DataFrame(registros)

    # Ordenar por fecha
    df = df.sort_values("fecha_orden").reset_index(drop=True)

    # Guardar CSV
    df.to_csv("superstore_ventas.csv", index=False, date_format="%Y-%m-%d")

    # Resumen
    print("\n✅ Dataset generado: superstore_ventas.csv")
    print(f"   Total registros : {len(df):,}")
    print(f"   Período         : {df['fecha_orden'].min()} → {df['fecha_orden'].max()}")
    print(f"   Ventas totales  : ${df['ventas'].sum():,.2f}")
    print(f"   Ganancia total  : ${df['ganancia'].sum():,.2f}")
    print(f"   Registros con pérdida: {(df['ganancia'] < 0).sum():,} ({(df['ganancia']<0).mean()*100:.1f}%)")
    print("\nPróximo paso:")
    print("  1. Abrí psql y creá la tabla con el script analysis.sql")
    print("  2. Importá el CSV: \\COPY ventas FROM 'superstore_ventas.csv' CSV HEADER;")
    print("  3. Ejecutá los queries por nivel (1 → 4)")


if __name__ == "__main__":
    main()
