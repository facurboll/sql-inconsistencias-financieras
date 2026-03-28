# 🔍 Detección de Inconsistencias Financieras con SQL

**Proyecto de análisis de datos | Facundo Iván Ramírez Boll**  
`PostgreSQL` · `Window Functions` · `CTEs` · `Análisis financiero`

---

## ¿De qué trata este proyecto?

Este proyecto replica el tipo de análisis que realicé durante mi experiencia como **Auditor Junior en PwC** y como **Analista Comercial en Smart Home**: detectar desvíos, inconsistencias y anomalías en datos financieros usando SQL puro.

El dataset simula las ventas de una empresa multirrubro (tecnología, mobiliario y librería) con **5.000 transacciones** que incluyen anomalías inyectadas intencionalmente para demostrar las técnicas de detección.

---

## Estructura del proyecto

```
sql-inconsistencias-financieras/
│
├── analysis.sql          ← Queries organizados por nivel de complejidad
├── generate_dataset.py   ← Script Python para generar el dataset
├── superstore_ventas.csv ← Dataset generado (5.000 registros)
└── README.md
```

---

## Niveles de análisis

### Nivel 1 — Exploración y calidad de datos
- Vista general: totales, períodos, unicidad
- Detección de **valores nulos** por columna
- Identificación de **registros duplicados**
- Registros con **valores negativos o cero** en ventas

### Nivel 2 — Márgenes y rentabilidad
- Margen bruto por categoría vs. **promedio general** con alertas automáticas
- Productos con **pérdida consistente** en 3 o más órdenes
- Impacto del descuento en el margen por **tramos de descuento**

### Nivel 3 — Window Functions avanzadas
- **Ranking** de productos por ganancia dentro de cada categoría (`RANK`, `PARTITION BY`)
- Detección de **outliers estadísticos** por IQR (Q1, Q3, `PERCENTILE_CONT`)
- Evolución mensual con **variación MoM** (`LAG`, acumulado)
- Clientes con comportamiento de compra **anómalo** (descuentos altos + pérdidas)

### Nivel 4 — CTEs encadenadas — reporte ejecutivo
- Reporte consolidado por categoría con diagnóstico automático
- Métricas de participación en ventas y ganancia
- Clasificación semáforo: ✅ Rentable / ⚠ Alerta / 🔴 Revisión urgente

---

## Cómo ejecutarlo

### Requisitos
- PostgreSQL 15+
- Python 3.9+ con `pandas`, `numpy`, `faker`

### Paso a paso

```bash
# 1. Clonar el repositorio
git clone https://github.com/facuboll/sql-inconsistencias-financieras
cd sql-inconsistencias-financieras

# 2. Generar el dataset
pip install pandas numpy faker
python generate_dataset.py

# 3. Crear la base de datos y la tabla
psql -U postgres -c "CREATE DATABASE portfolio_sql;"
psql -U postgres -d portfolio_sql -f analysis.sql

# 4. Importar el CSV
psql -U postgres -d portfolio_sql -c "\COPY ventas FROM 'superstore_ventas.csv' CSV HEADER;"

# 5. Ejecutar los queries por nivel
psql -U postgres -d portfolio_sql -f analysis.sql
```

---

## Hallazgos principales del análisis

| Hallazgo | Detalle |
|---|---|
| Categoría con menor margen | Tecnología (~12%) vs. promedio del 28% |
| Productos en pérdida consistente | 18 productos con 3+ ventas negativas |
| Tramo de descuento crítico | Descuentos >50% generan pérdida en el 94% de los casos |
| Clientes de alto riesgo | 23 clientes con descuento promedio >40% y ganancia negativa |

> *Los valores exactos varían con cada generación del dataset (seed aleatorio).*

---

## Técnicas SQL utilizadas

```sql
-- Ejemplo: detección de outliers por IQR con window functions
WITH stats AS (
    SELECT subcategoria,
           PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY ganancia/ventas) OVER (PARTITION BY subcategoria) AS q1,
           PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY ganancia/ventas) OVER (PARTITION BY subcategoria) AS q3
    FROM ventas
)
SELECT * FROM stats
WHERE margen_pct < q1 - 1.5*(q3-q1)
   OR margen_pct > q3 + 1.5*(q3-q1);
```

**Conceptos aplicados:** `WITH` (CTEs encadenadas) · `WINDOW FUNCTIONS` (RANK, LAG, SUM OVER, PERCENTILE_CONT) · `FILTER (WHERE ...)` · `NULLIF` · `DATE_TRUNC` · `TO_CHAR` · Análisis IQR · Clasificación por semáforo

---

## Sobre el autor

**Facundo Iván Ramírez Boll**  
Contador Público | Analista de Datos  
SQL · Python · Power BI · Tableau · Excel Avanzado

- 📧 facuboll@gmail.com  
- 💼 [LinkedIn](#)  
- 📊 [Tableau Public](#)  
- 📁 [Otros proyectos](#)

---

*Este proyecto forma parte de mi portafolio profesional de análisis de datos.*
