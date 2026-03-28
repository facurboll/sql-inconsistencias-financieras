-- ============================================================
-- PROYECTO: Detección de Inconsistencias Financieras con SQL
-- Autor: Facundo Iván Ramírez Boll
-- Dataset: Superstore Sales (adaptado)
-- Motor: PostgreSQL 15+
-- ============================================================

-- ============================================================
-- SETUP: Crear tabla principal
-- ============================================================

CREATE TABLE IF NOT EXISTS ventas (
    orden_id        VARCHAR(20),
    fecha_orden     DATE,
    fecha_envio     DATE,
    modo_envio      VARCHAR(30),
    cliente_id      VARCHAR(20),
    cliente_nombre  VARCHAR(100),
    segmento        VARCHAR(30),
    ciudad          VARCHAR(80),
    provincia       VARCHAR(80),
    pais            VARCHAR(50),
    categoria       VARCHAR(50),
    subcategoria    VARCHAR(50),
    producto_id     VARCHAR(30),
    producto_nombre VARCHAR(200),
    ventas          NUMERIC(12,2),
    cantidad        INTEGER,
    descuento       NUMERIC(5,4),
    ganancia        NUMERIC(12,2)
);

-- ============================================================
-- NIVEL 1: Exploración inicial y calidad de datos
-- ============================================================

-- 1.1 Vista general del dataset
SELECT
    COUNT(*)                         AS total_registros,
    COUNT(DISTINCT orden_id)         AS ordenes_unicas,
    COUNT(DISTINCT cliente_id)       AS clientes_unicos,
    MIN(fecha_orden)                 AS primer_registro,
    MAX(fecha_orden)                 AS ultimo_registro,
    ROUND(SUM(ventas)::NUMERIC, 2)   AS ventas_totales,
    ROUND(SUM(ganancia)::NUMERIC, 2) AS ganancia_total
FROM ventas;


-- 1.2 Detección de valores nulos por columna
SELECT
    COUNT(*) FILTER (WHERE orden_id IS NULL)        AS nulos_orden_id,
    COUNT(*) FILTER (WHERE fecha_orden IS NULL)     AS nulos_fecha,
    COUNT(*) FILTER (WHERE ventas IS NULL)          AS nulos_ventas,
    COUNT(*) FILTER (WHERE cantidad IS NULL)        AS nulos_cantidad,
    COUNT(*) FILTER (WHERE descuento IS NULL)       AS nulos_descuento,
    COUNT(*) FILTER (WHERE ganancia IS NULL)        AS nulos_ganancia,
    COUNT(*) FILTER (WHERE cliente_id IS NULL)      AS nulos_cliente
FROM ventas;


-- 1.3 Detección de registros duplicados
SELECT
    orden_id,
    producto_id,
    fecha_orden,
    COUNT(*) AS duplicados
FROM ventas
GROUP BY orden_id, producto_id, fecha_orden
HAVING COUNT(*) > 1
ORDER BY duplicados DESC;


-- 1.4 Registros con valores negativos o cero en ventas
SELECT
    orden_id,
    producto_nombre,
    ventas,
    cantidad,
    ganancia,
    fecha_orden
FROM ventas
WHERE ventas <= 0 OR cantidad <= 0
ORDER BY ventas ASC;


-- ============================================================
-- NIVEL 2: Análisis de márgenes y rentabilidad
-- ============================================================

-- 2.1 Margen bruto por categoría con comparación vs promedio general
WITH margenes_categoria AS (
    SELECT
        categoria,
        ROUND(SUM(ventas)::NUMERIC, 2)                              AS ventas_cat,
        ROUND(SUM(ganancia)::NUMERIC, 2)                            AS ganancia_cat,
        ROUND((SUM(ganancia) / NULLIF(SUM(ventas), 0) * 100)::NUMERIC, 2) AS margen_pct
    FROM ventas
    GROUP BY categoria
),
promedio_general AS (
    SELECT ROUND((SUM(ganancia) / NULLIF(SUM(ventas), 0) * 100)::NUMERIC, 2) AS margen_global
    FROM ventas
)
SELECT
    mc.categoria,
    mc.ventas_cat,
    mc.ganancia_cat,
    mc.margen_pct,
    pg.margen_global,
    ROUND((mc.margen_pct - pg.margen_global)::NUMERIC, 2)          AS desvio_vs_global,
    CASE
        WHEN mc.margen_pct < pg.margen_global - 5 THEN '⚠ BAJO'
        WHEN mc.margen_pct > pg.margen_global + 5 THEN '✓ ALTO'
        ELSE '→ NORMAL'
    END AS alerta
FROM margenes_categoria mc, promedio_general pg
ORDER BY mc.margen_pct ASC;


-- 2.2 Productos con pérdida consistente (ganancia negativa en 3+ órdenes)
SELECT
    producto_id,
    producto_nombre,
    categoria,
    subcategoria,
    COUNT(*)                                                        AS total_ventas,
    COUNT(*) FILTER (WHERE ganancia < 0)                            AS ventas_con_perdida,
    ROUND(AVG(ganancia)::NUMERIC, 2)                                AS ganancia_promedio,
    ROUND(SUM(ganancia)::NUMERIC, 2)                                AS perdida_acumulada,
    ROUND((SUM(ganancia) / NULLIF(SUM(ventas), 0) * 100)::NUMERIC, 2) AS margen_pct
FROM ventas
GROUP BY producto_id, producto_nombre, categoria, subcategoria
HAVING COUNT(*) FILTER (WHERE ganancia < 0) >= 3
   AND SUM(ganancia) < 0
ORDER BY perdida_acumulada ASC
LIMIT 20;


-- 2.3 Impacto del descuento en el margen (análisis por tramo)
SELECT
    CASE
        WHEN descuento = 0          THEN '0% — Sin descuento'
        WHEN descuento <= 0.10      THEN '1–10%'
        WHEN descuento <= 0.20      THEN '11–20%'
        WHEN descuento <= 0.30      THEN '21–30%'
        WHEN descuento <= 0.50      THEN '31–50%'
        ELSE '> 50% — Descuento extremo'
    END                                                             AS tramo_descuento,
    COUNT(*)                                                        AS cantidad_registros,
    ROUND(AVG(ventas)::NUMERIC, 2)                                  AS venta_promedio,
    ROUND(AVG(ganancia)::NUMERIC, 2)                                AS ganancia_promedio,
    ROUND((SUM(ganancia) / NULLIF(SUM(ventas), 0) * 100)::NUMERIC, 2) AS margen_pct,
    COUNT(*) FILTER (WHERE ganancia < 0)                            AS ventas_con_perdida
FROM ventas
GROUP BY tramo_descuento
ORDER BY
    CASE tramo_descuento
        WHEN '0% — Sin descuento'    THEN 1
        WHEN '1–10%'                 THEN 2
        WHEN '11–20%'                THEN 3
        WHEN '21–30%'                THEN 4
        WHEN '31–50%'                THEN 5
        ELSE 6
    END;


-- ============================================================
-- NIVEL 3: Window Functions — análisis avanzado
-- ============================================================

-- 3.1 Ranking de productos por ganancia dentro de cada categoría
SELECT
    categoria,
    subcategoria,
    producto_nombre,
    ROUND(SUM(ganancia)::NUMERIC, 2)                               AS ganancia_total,
    ROUND(SUM(ventas)::NUMERIC, 2)                                 AS ventas_total,
    RANK() OVER (
        PARTITION BY categoria
        ORDER BY SUM(ganancia) DESC
    )                                                              AS rank_ganancia,
    ROUND(
        SUM(SUM(ganancia)) OVER (PARTITION BY categoria)::NUMERIC
    , 2)                                                           AS ganancia_categoria_total,
    ROUND(
        (SUM(ganancia) / NULLIF(SUM(SUM(ganancia)) OVER (PARTITION BY categoria), 0) * 100)::NUMERIC
    , 2)                                                           AS pct_sobre_categoria
FROM ventas
GROUP BY categoria, subcategoria, producto_nombre
ORDER BY categoria, rank_ganancia;


-- 3.2 Detección de outliers de margen por subcategoría (>1.5 IQR)
WITH stats AS (
    SELECT
        subcategoria,
        ROUND((ganancia / NULLIF(ventas, 0) * 100)::NUMERIC, 2)    AS margen_pct,
        PERCENTILE_CONT(0.25) WITHIN GROUP (
            ORDER BY ganancia / NULLIF(ventas, 0) * 100
        ) OVER (PARTITION BY subcategoria)                          AS q1,
        PERCENTILE_CONT(0.75) WITHIN GROUP (
            ORDER BY ganancia / NULLIF(ventas, 0) * 100
        ) OVER (PARTITION BY subcategoria)                          AS q3,
        orden_id,
        producto_nombre,
        ventas,
        ganancia
    FROM ventas
),
iqr_calc AS (
    SELECT *,
        ROUND((q3 - q1)::NUMERIC, 2)                               AS iqr,
        ROUND((q1 - 1.5 * (q3 - q1))::NUMERIC, 2)                 AS limite_inferior,
        ROUND((q3 + 1.5 * (q3 - q1))::NUMERIC, 2)                 AS limite_superior
    FROM stats
)
SELECT
    orden_id,
    subcategoria,
    producto_nombre,
    margen_pct,
    limite_inferior,
    limite_superior,
    iqr,
    CASE
        WHEN margen_pct < limite_inferior THEN '🔴 OUTLIER BAJO'
        WHEN margen_pct > limite_superior THEN '🟡 OUTLIER ALTO'
    END AS tipo_outlier,
    ROUND(ventas::NUMERIC, 2) AS ventas,
    ROUND(ganancia::NUMERIC, 2) AS ganancia
FROM iqr_calc
WHERE margen_pct < limite_inferior OR margen_pct > limite_superior
ORDER BY subcategoria, margen_pct ASC;


-- 3.3 Evolución mensual de ventas y ganancia con variación MoM
WITH mensual AS (
    SELECT
        DATE_TRUNC('month', fecha_orden)                           AS mes,
        ROUND(SUM(ventas)::NUMERIC, 2)                             AS ventas_mes,
        ROUND(SUM(ganancia)::NUMERIC, 2)                           AS ganancia_mes,
        COUNT(DISTINCT orden_id)                                   AS ordenes
    FROM ventas
    GROUP BY DATE_TRUNC('month', fecha_orden)
)
SELECT
    TO_CHAR(mes, 'YYYY-MM')                                        AS periodo,
    ventas_mes,
    ganancia_mes,
    ordenes,
    ROUND(
        (ventas_mes - LAG(ventas_mes) OVER (ORDER BY mes))
        / NULLIF(LAG(ventas_mes) OVER (ORDER BY mes), 0) * 100
    ::NUMERIC, 2)                                                  AS variacion_ventas_pct,
    ROUND(
        (ganancia_mes - LAG(ganancia_mes) OVER (ORDER BY mes))
        / NULLIF(LAG(ganancia_mes) OVER (ORDER BY mes), 0) * 100
    ::NUMERIC, 2)                                                  AS variacion_ganancia_pct,
    ROUND(
        SUM(ventas_mes) OVER (ORDER BY mes)::NUMERIC, 2
    )                                                              AS ventas_acumuladas
FROM mensual
ORDER BY mes;


-- 3.4 Clientes con comportamiento de compra anómalo
--     (descuentos promedio muy altos o ratio pérdida/ganancia elevado)
WITH cliente_stats AS (
    SELECT
        cliente_id,
        cliente_nombre,
        segmento,
        COUNT(DISTINCT orden_id)                                   AS total_ordenes,
        ROUND(SUM(ventas)::NUMERIC, 2)                             AS ventas_totales,
        ROUND(SUM(ganancia)::NUMERIC, 2)                           AS ganancia_total,
        ROUND(AVG(descuento) * 100::NUMERIC, 2)                    AS descuento_promedio_pct,
        COUNT(*) FILTER (WHERE ganancia < 0)                       AS items_con_perdida,
        COUNT(*)                                                   AS total_items
    FROM ventas
    GROUP BY cliente_id, cliente_nombre, segmento
    HAVING COUNT(DISTINCT orden_id) >= 3
),
percentiles AS (
    SELECT
        PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY descuento_promedio_pct) AS p90_descuento,
        PERCENTILE_CONT(0.10) WITHIN GROUP (ORDER BY ganancia_total)         AS p10_ganancia
    FROM cliente_stats
)
SELECT
    cs.cliente_id,
    cs.cliente_nombre,
    cs.segmento,
    cs.total_ordenes,
    cs.ventas_totales,
    cs.ganancia_total,
    cs.descuento_promedio_pct,
    ROUND((cs.items_con_perdida::NUMERIC / cs.total_items * 100), 2) AS pct_items_perdida,
    CASE
        WHEN cs.descuento_promedio_pct > p.p90_descuento
         AND cs.ganancia_total < 0                               THEN '🔴 ALTO RIESGO'
        WHEN cs.descuento_promedio_pct > p.p90_descuento         THEN '🟠 DESCUENTO ALTO'
        WHEN cs.ganancia_total < p.p10_ganancia                  THEN '🟡 BAJA RENTABILIDAD'
        ELSE '✓ NORMAL'
    END AS clasificacion
FROM cliente_stats cs, percentiles p
WHERE cs.descuento_promedio_pct > p.p90_descuento
   OR cs.ganancia_total < p.p10_ganancia
ORDER BY cs.ganancia_total ASC;


-- ============================================================
-- NIVEL 4: CTEs encadenadas — reporte ejecutivo final
-- ============================================================

-- 4.1 Reporte ejecutivo consolidado por categoría
WITH base AS (
    SELECT
        categoria,
        subcategoria,
        ventas,
        ganancia,
        descuento,
        cantidad,
        fecha_orden
    FROM ventas
),
metricas AS (
    SELECT
        categoria,
        COUNT(*)                                                   AS registros,
        ROUND(SUM(ventas)::NUMERIC, 2)                             AS ventas_total,
        ROUND(SUM(ganancia)::NUMERIC, 2)                           AS ganancia_total,
        ROUND(AVG(descuento) * 100::NUMERIC, 2)                    AS desc_promedio_pct,
        COUNT(*) FILTER (WHERE ganancia < 0)                       AS items_perdida,
        ROUND((SUM(ganancia) / NULLIF(SUM(ventas),0)*100)::NUMERIC, 2) AS margen_pct
    FROM base
    GROUP BY categoria
),
ranking AS (
    SELECT *,
        RANK() OVER (ORDER BY ganancia_total DESC)                 AS rank_ganancia,
        RANK() OVER (ORDER BY margen_pct DESC)                     AS rank_margen,
        ROUND(
            ventas_total / SUM(ventas_total) OVER () * 100
        ::NUMERIC, 2)                                              AS pct_ventas_total,
        ROUND(
            ganancia_total / NULLIF(SUM(ganancia_total) OVER (), 0) * 100
        ::NUMERIC, 2)                                              AS pct_ganancia_total
    FROM metricas
)
SELECT
    categoria,
    registros,
    ventas_total,
    ganancia_total,
    margen_pct,
    desc_promedio_pct,
    items_perdida,
    pct_ventas_total        AS "% ventas",
    pct_ganancia_total      AS "% ganancia",
    rank_ganancia,
    rank_margen,
    CASE
        WHEN margen_pct >= 15 AND desc_promedio_pct < 20 THEN '✅ Rentable y sano'
        WHEN margen_pct >= 15 AND desc_promedio_pct >= 20 THEN '⚠ Rentable pero con descuentos altos'
        WHEN margen_pct < 0                               THEN '🔴 Pérdida — requiere revisión urgente'
        ELSE '🟡 Margen bajo — monitorear'
    END                                                            AS diagnostico
FROM ranking
ORDER BY rank_ganancia;
