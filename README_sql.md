# 🔍 Detección de Inconsistencias Financieras con SQL

![PostgreSQL](https://img.shields.io/badge/PostgreSQL-15+-336791?logo=postgresql&logoColor=white)
![Python](https://img.shields.io/badge/Python-3.9+-blue?logo=python&logoColor=white)
![SQL](https://img.shields.io/badge/SQL-Advanced-orange)
![License](https://img.shields.io/badge/License-MIT-green)
![Status](https://img.shields.io/badge/Status-Complete-brightgreen)

> **Domain:** Financial Data Analytics | Audit | Anomaly Detection  
> **Tech Stack:** PostgreSQL · CTEs · Window Functions · Python (dataset generation)

---

## ¿De qué trata este proyecto?

Este proyecto replica el tipo de análisis que realicé durante mi experiencia como **Auditor Junior en PwC** y como **Analista Comercial en Smart Home**: detectar desvíos, inconsistencias y anomalías en datos financieros usando SQL puro.

El dataset simula las ventas de una empresa multirrubro (tecnología, mobiliario y librería) con **5.000 transacciones** que incluyen anomalías inyectadas intencionalmente para demostrar técnicas reales de detección.

---

## 📁 Estructura del proyecto

```
sql-inconsistencias-financieras/
│
├── analysis.sql            # 370 líneas de queries organizados por nivel
├── generate_dataset.py     # Script Python para generar el dataset sintético
├── superstore_ventas.csv   # Dataset generado (5.000 registros)
└── README.md
```

---

## 🧱 Niveles de análisis

### Nivel 1 — Exploración y calidad de datos
- Vista general: totales, períodos, unicidad
- Detección de **valores nulos** por columna con `FILTER (WHERE ...)`
- Identificación de **registros duplicados**
- Registros con **valores negativos o cero** en ventas

### Nivel 2 — Márgenes y rentabilidad
- Margen bruto por categoría vs. **promedio general** con alertas automáticas (`CASE WHEN`)
- Productos con **pérdida consistente** en 3+ órdenes (`HAVING COUNT FILTER`)
- Impacto del descuento por **tramos** sobre el margen neto

### Nivel 3 — Window Functions avanzadas
- **Ranking** de productos por ganancia dentro de cada categoría (`RANK`, `PARTITION BY`)
- Detección de **outliers estadísticos** por método IQR (`PERCENTILE_CONT`)
- Evolución mensual con **variación MoM** (`LAG`, `DATE_TRUNC`, acumulado)
- Clientes con comportamiento de compra **anómalo** (descuentos altos + pérdidas)

### Nivel 4 — CTEs encadenadas — reporte ejecutivo
- Reporte consolidado por categoría con diagnóstico automático
- Participación porcentual en ventas y ganancia total
- Clasificación semáforo: `✅ Rentable` / `⚠ Alerta` / `🔴 Revisión urgente`

---

## 💡 Técnicas SQL aplicadas

| Técnica | Uso en este proyecto |
|---|---|
| `WITH` (CTEs encadenadas) | Modularizar cálculos complejos en pasos legibles |
| `RANK() OVER (PARTITION BY)` | Ranking de productos dentro de cada categoría |
| `LAG()` | Variación MoM de ventas y ganancia |
| `SUM() OVER()` | Acumulados históricos y participación % |
| `PERCENTILE_CONT()` | Cálculo de Q1/Q3 para detección de outliers IQR |
| `FILTER (WHERE ...)` | Conteo condicional sin subqueries |
| `NULLIF()` | Evitar división por cero en cálculos de margen |
| `DATE_TRUNC` / `TO_CHAR` | Agrupación y formateo de fechas |
| `CASE WHEN` | Clasificación semáforo automática |

---

## 🔬 Ejemplo de código — Outliers por IQR

```sql
-- Detección de outliers de margen por subcategoría (método IQR)
WITH stats AS (
    SELECT
        subcategoria,
        ROUND((ganancia / NULLIF(ventas, 0) * 100)::NUMERIC, 2) AS margen_pct,
        PERCENTILE_CONT(0.25) WITHIN GROUP (
            ORDER BY ganancia / NULLIF(ventas, 0) * 100
        ) OVER (PARTITION BY subcategoria) AS q1,
        PERCENTILE_CONT(0.75) WITHIN GROUP (
            ORDER BY ganancia / NULLIF(ventas, 0) * 100
        ) OVER (PARTITION BY subcategoria) AS q3,
        orden_id,
        producto_nombre,
        ventas,
        ganancia
    FROM ventas
),
iqr_calc AS (
    SELECT *,
        ROUND((q3 - q1)::NUMERIC, 2)                    AS iqr,
        ROUND((q1 - 1.5 * (q3 - q1))::NUMERIC, 2)       AS limite_inferior,
        ROUND((q3 + 1.5 * (q3 - q1))::NUMERIC, 2)       AS limite_superior
    FROM stats
)
SELECT
    orden_id,
    subcategoria,
    producto_nombre,
    margen_pct,
    limite_inferior,
    limite_superior,
    CASE
        WHEN margen_pct < limite_inferior THEN '🔴 OUTLIER BAJO'
        WHEN margen_pct > limite_superior THEN '🟡 OUTLIER ALTO'
    END AS tipo_outlier
FROM iqr_calc
WHERE margen_pct < limite_inferior OR margen_pct > limite_superior
ORDER BY subcategoria, margen_pct ASC;
```

---

## 📊 Hallazgos principales

| Hallazgo | Detalle |
|---|---|
| Categoría con menor margen | Tecnología (~12%) vs. promedio general (~28%) |
| Productos en pérdida consistente | 18 productos con 3+ ventas en negativo |
| Tramo de descuento crítico | Descuentos >50% generan pérdida en el 94% de los casos |
| Clientes de alto riesgo | 23 clientes con descuento promedio >40% y ganancia negativa |

> *Los valores exactos varían con cada generación del dataset (seed aleatorio).*

---

## 🚀 Cómo ejecutarlo

### Requisitos
- PostgreSQL 15+
- Python 3.9+ con `pandas`, `numpy`, `faker`

### Paso a paso

```bash
# 1. Clonar el repositorio
git clone https://github.com/facurboll/sql-inconsistencias-financieras.git
cd sql-inconsistencias-financieras

# 2. Instalar dependencias Python
pip install pandas numpy faker

# 3. Generar el dataset
python generate_dataset.py

# 4. Crear la base de datos
psql -U postgres -c "CREATE DATABASE portfolio_sql;"

# 5. Crear la tabla e importar el CSV
psql -U postgres -d portfolio_sql -c "
CREATE TABLE IF NOT EXISTS ventas (
    orden_id VARCHAR(20), fecha_orden DATE, fecha_envio DATE,
    modo_envio VARCHAR(30), cliente_id VARCHAR(20), cliente_nombre VARCHAR(100),
    segmento VARCHAR(30), ciudad VARCHAR(80), provincia VARCHAR(80), pais VARCHAR(50),
    categoria VARCHAR(50), subcategoria VARCHAR(50), producto_id VARCHAR(30),
    producto_nombre VARCHAR(200), ventas NUMERIC(12,2), cantidad INTEGER,
    descuento NUMERIC(5,4), ganancia NUMERIC(12,2)
);"

psql -U postgres -d portfolio_sql -c "\COPY ventas FROM 'superstore_ventas.csv' CSV HEADER;"

# 6. Ejecutar el análisis
psql -U postgres -d portfolio_sql -f analysis.sql
```

---

## 🔗 Conexión con experiencia profesional

Las técnicas aplicadas en este proyecto reflejan directamente tareas reales:

- **PwC (Auditor Junior):** detección de desvíos e inconsistencias en datos financieros, validación de bases de datos críticas
- **Smart Home (Analista Comercial):** seguimiento de márgenes, análisis de rentabilidad por producto y categoría

---

## 👤 Autor

**Facundo Iván Ramírez Boll**  
Contador Público | Analista de Datos 🇦🇷  
[![LinkedIn](https://img.shields.io/badge/LinkedIn-Connect-blue?logo=linkedin)](https://www.linkedin.com/in/facundo-ramirez-boll-37849a227)
[![GitHub](https://img.shields.io/badge/GitHub-facurboll-black?logo=github)](https://github.com/facurboll)

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
