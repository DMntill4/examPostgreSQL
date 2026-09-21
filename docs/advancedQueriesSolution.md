# Solucionario y Guía de Análisis: Consultas SQL Avanzadas (1 a 25)

Este documento contiene la solución explicada y probada de las 25 consultas del nivel avanzado.

---

## 1. Organización con la mayor cantidad de personas registradas
```sql
WITH ranking_personas AS (
    SELECT 
        t.name AS empresa, 
        COUNT(p.id) AS total_personas,
        DENSE_RANK() OVER (ORDER BY COUNT(p.id) DESC) AS puesto
    FROM tenants t
    JOIN persons p ON p.tenant_id = t.id
    GROUP BY t.id, t.name
)
SELECT empresa, total_personas
FROM ranking_personas
WHERE puesto = 1;
```

---

## 2. Organizaciones por encima del promedio general de personas
```sql
WITH conteo_personas AS (
    SELECT 
        t.id AS tenant_id, 
        t.name AS empresa,
        COUNT(p.id) AS total_personas 
    FROM tenants t
    LEFT JOIN persons p ON t.id = p.tenant_id
    GROUP BY t.id, t.name
)
SELECT empresa, total_personas
FROM conteo_personas
WHERE total_personas > (SELECT AVG(total_personas) FROM conteo_personas);
```

---

## 3. Organizaciones con todos los módulos existentes de un sistema SST
```sql
WITH total_modulos_sst AS (
    SELECT COUNT(*) AS total 
    FROM modules m
    JOIN type_system_sst ts ON ts.id = m.type_system_sst_id
    WHERE ts.name = 'SST'
),
modulos_por_empresa AS (
    SELECT 
        t.id AS tenant_id,
        t.name AS empresa,
        COUNT(tm.module_id) AS mis_modulos
    FROM tenants t
    JOIN tenant_modules tm ON tm.tenant_id = t.id
    JOIN modules m ON m.id = tm.module_id
    JOIN type_system_sst ts ON ts.id = m.type_system_sst_id
    WHERE ts.name = 'SST'
    GROUP BY t.id, t.name
)
SELECT empresa, mis_modulos
FROM modulos_por_empresa
WHERE mis_modulos = (SELECT total FROM total_modulos_sst);
```

---

## 4. Organizaciones con módulos configurados pero sin plantillas
```sql
SELECT t.id, t.name AS empresa
FROM tenants t
WHERE EXISTS (
    SELECT 1 FROM tenant_modules tm WHERE tm.tenant_id = t.id
)
AND NOT EXISTS (
    SELECT 1 FROM tenanttemplates tt WHERE tt.tenant_id = t.id
);
```

---

## 5. Organizaciones con plantillas en todas las etapas PHVA
```sql
WITH total_etapas AS (
    SELECT COUNT(*) AS total FROM phva_stages
),
etapas_por_empresa AS (
    SELECT 
        tenant_id, 
        COUNT(DISTINCT phva_stage_id) AS mis_etapas
    FROM tenanttemplates
    GROUP BY tenant_id
)
SELECT t.name AS empresa
FROM etapas_por_empresa epe
JOIN tenants t ON t.id = epe.tenant_id
WHERE epe.mis_etapas = (SELECT total FROM total_etapas);
```

---

## 6. Plantillas por organización discriminadas por etapa PHVA
```sql
SELECT 
    t.name AS empresa,
    ps.name AS etapa_phva,
    COUNT(tt.id) AS total_plantillas
FROM tenants t
CROSS JOIN phva_stages ps
LEFT JOIN tenanttemplates tt 
    ON tt.tenant_id = t.id 
   AND tt.phva_stage_id = ps.id
GROUP BY t.id, t.name, ps.id, ps.name, ps.order_num
ORDER BY t.name, ps.order_num;
```

---

## 7. Pivoting de plantillas PHVA en columnas independientes (Planear, Hacer, Verificar, Actuar)
```sql
SELECT 
    t.name AS empresa,
    COUNT(CASE WHEN tt.phva_stage_id = 1 THEN 1 END) AS planear,
    COUNT(CASE WHEN tt.phva_stage_id = 2 THEN 1 END) AS hacer,
    COUNT(CASE WHEN tt.phva_stage_id = 3 THEN 1 END) AS verificar,
    COUNT(CASE WHEN tt.phva_stage_id = 4 THEN 1 END) AS actuar
FROM tenants t
LEFT JOIN tenanttemplates tt ON tt.tenant_id = t.id
GROUP BY t.id, t.name;
```

---

## 8. Porcentaje que representa cada etapa PHVA sobre el total por empresa
```sql
WITH totales_etapa AS (
    SELECT 
        tenant_id,
        phva_stage_id,
        COUNT(*) AS plantillas_etapa
    FROM tenanttemplates
    GROUP BY tenant_id, phva_stage_id
),
totales_tenant AS (
    SELECT tenant_id, COUNT(*) AS total_global FROM tenanttemplates GROUP BY tenant_id
)
SELECT 
    t.name AS empresa,
    ps.name AS etapa_phva,
    te.plantillas_etapa,
    ROUND((te.plantillas_etapa::NUMERIC / tt.total_global) * 100, 2) AS porcentaje
FROM totales_etapa te
JOIN totales_tenant tt ON tt.tenant_id = te.tenant_id
JOIN tenants t ON t.id = te.tenant_id
JOIN phva_stages ps ON ps.id = te.phva_stage_id;
```

---

## 9. Etapa PHVA con mayor cantidad de plantillas por empresa
```sql
WITH conteo AS (
    SELECT 
        tenant_id, 
        phva_stage_id, 
        COUNT(*) AS total,
        DENSE_RANK() OVER (PARTITION BY tenant_id ORDER BY COUNT(*) DESC) AS posicion
    FROM tenanttemplates
    GROUP BY tenant_id, phva_stage_id
)
SELECT t.name AS empresa, ps.name AS etapa_mayor
FROM conteo c
JOIN tenants t ON t.id = c.tenant_id
JOIN phva_stages ps ON ps.id = c.phva_stage_id
WHERE c.posicion = 1;
```

---

## 10. Porcentaje de documentos finalizados por empresa
```sql
SELECT 
    t.name AS empresa,
    COUNT(tt.id) AS total_documentos,
    COUNT(CASE WHEN ds.code = 'FINALIZADO' THEN 1 END) AS finalizados,
    ROUND((COUNT(CASE WHEN ds.code = 'FINALIZADO' THEN 1 END)::NUMERIC / NULLIF(COUNT(tt.id), 0)) * 100, 2) AS pct_cumplimiento
FROM tenants t
LEFT JOIN tenanttemplates tt ON tt.tenant_id = t.id
LEFT JOIN document_statuses ds ON ds.id = tt.document_status_id
GROUP BY t.id, t.name;
```

---

## 11. Organizaciones con porcentaje de cumplimiento por debajo del promedio
```sql
WITH cumplimiento_empresa AS (
    SELECT 
        t.id AS tenant_id,
        t.name AS empresa,
        COALESCE(ROUND((COUNT(CASE WHEN ds.code = 'FINALIZADO' THEN 1 END)::NUMERIC / NULLIF(COUNT(tt.id), 0)) * 100, 2), 0) AS pct
    FROM tenants t
    LEFT JOIN tenanttemplates tt ON tt.tenant_id = t.id
    LEFT JOIN document_statuses ds ON ds.id = tt.document_status_id
    GROUP BY t.id, t.name
)
SELECT empresa, pct
FROM cumplimiento_empresa
WHERE pct < (SELECT AVG(pct) FROM cumplimiento_empresa);
```

---

## 12. Clasificación del cumplimiento en Bajo, Medio y Alto con CASE
```sql
WITH cumplimiento AS (
    SELECT 
        t.name AS empresa,
        COALESCE(ROUND((COUNT(CASE WHEN ds.code = 'FINALIZADO' THEN 1 END)::NUMERIC / NULLIF(COUNT(tt.id), 0)) * 100, 2), 0) AS pct
    FROM tenants t
    LEFT JOIN tenanttemplates tt ON tt.tenant_id = t.id
    LEFT JOIN document_statuses ds ON ds.id = tt.document_status_id
    GROUP BY t.id, t.name
)
SELECT 
    empresa, 
    pct AS porcentaje,
    CASE 
        WHEN pct < 50 THEN 'Bajo'
        WHEN pct BETWEEN 50 AND 80 THEN 'Medio'
        ELSE 'Alto'
    END AS categoria_cumplimiento
FROM cumplimiento;
```

---

## 13. Ranking de organizaciones por porcentaje de cumplimiento documental
```sql
WITH cumplimiento AS (
    SELECT 
        t.name AS empresa,
        COALESCE(ROUND((COUNT(CASE WHEN ds.code = 'FINALIZADO' THEN 1 END)::NUMERIC / NULLIF(COUNT(tt.id), 0)) * 100, 2), 0) AS pct
    FROM tenants t
    LEFT JOIN tenanttemplates tt ON tt.tenant_id = t.id
    LEFT JOIN document_statuses ds ON ds.id = tt.document_status_id
    GROUP BY t.id, t.name
)
SELECT 
    empresa, 
    pct,
    DENSE_RANK() OVER (ORDER BY pct DESC) AS ranking_posicion
FROM cumplimiento;
```

---

## 14. Porcentaje de cumplimiento y diferencia respecto al promedio general
```sql
WITH cumplimiento AS (
    SELECT 
        t.name AS empresa,
        COALESCE(ROUND((COUNT(CASE WHEN ds.code = 'FINALIZADO' THEN 1 END)::NUMERIC / NULLIF(COUNT(tt.id), 0)) * 100, 2), 0) AS pct
    FROM tenants t
    LEFT JOIN tenanttemplates tt ON tt.tenant_id = t.id
    LEFT JOIN document_statuses ds ON ds.id = tt.document_status_id
    GROUP BY t.id, t.name
)
SELECT 
    empresa,
    pct,
    ROUND(AVG(pct) OVER (), 2) AS promedio_general,
    ROUND(pct - AVG(pct) OVER (), 2) AS diferencia
FROM cumplimiento;
```

---

## 15. Cantidad acumulada de documentos finalizados con Window Function
```sql
SELECT 
    t.name AS empresa,
    tt.assigned_at::DATE AS fecha_asig,
    COUNT(*) OVER (PARTITION BY t.id ORDER BY tt.assigned_at) AS acumulado_documentos
FROM tenants t
JOIN tenanttemplates tt ON tt.tenant_id = t.id
JOIN document_statuses ds ON ds.id = tt.document_status_id
WHERE ds.code = 'FINALIZADO';
```

---

## 16. Organizaciones en la misma ciudad con diferente tamaño empresarial
```sql
SELECT 
    t1.name AS empresa_1, ts1.name AS tamano_1,
    t2.name AS empresa_2, ts2.name AS tamano_2,
    c.name AS ciudad
FROM tenants t1
JOIN tenants t2 ON t1.city_id = t2.city_id AND t1.id < t2.id
JOIN tenant_sizes ts1 ON ts1.id = t1.tenant_size_id
JOIN tenant_sizes ts2 ON ts2.id = t2.tenant_size_id
JOIN cities c ON c.id = t1.city_id
WHERE t1.tenant_size_id <> t2.tenant_size_id;
```

---

## 17. Personas cuyo cargo supera el promedio de ocupación de su empresa
```sql
WITH ocupacion_cargos AS (
    SELECT 
        tenant_id, position_id, COUNT(*) AS personas_cargo
    FROM persons
    WHERE position_id IS NOT NULL
    GROUP BY tenant_id, position_id
),
promedio_por_tenant AS (
    SELECT tenant_id, AVG(personas_cargo) AS promedio_ocupacion
    FROM ocupacion_cargos
    GROUP BY tenant_id
)
SELECT 
    p.first_name || ' ' || p.last_name AS persona,
    pos.description AS cargo,
    oc.personas_cargo,
    ROUND(pt.promedio_ocupacion, 2) AS promedio_empresa
FROM persons p
JOIN ocupacion_cargos oc ON oc.tenant_id = p.tenant_id AND oc.position_id = p.position_id
JOIN promedio_por_tenant pt ON pt.tenant_id = p.tenant_id
JOIN positions pos ON pos.id = p.position_id
WHERE oc.personas_cargo > pt.promedio_ocupacion;
```

---

## 18. CTE para calcular personas por empresa y filtrar superiores al promedio
```sql
WITH personas_tenant AS (
    SELECT tenant_id, COUNT(*) AS total_personas
    FROM persons
    GROUP BY tenant_id
)
SELECT t.name AS empresa, pt.total_personas
FROM personas_tenant pt
JOIN tenants t ON t.id = pt.tenant_id
WHERE pt.total_personas > (SELECT AVG(total_personas) FROM personas_tenant);
```

---

## 19. CTE consolidado de Módulos, Plantillas y Personas por organización
```sql
WITH modulos_cnt AS (
    SELECT tenant_id, COUNT(*) AS total_modulos FROM tenant_modules GROUP BY tenant_id
),
plantillas_cnt AS (
    SELECT tenant_id, COUNT(*) AS total_plantillas FROM tenanttemplates GROUP BY tenant_id
),
personas_cnt AS (
    SELECT tenant_id, COUNT(*) AS total_personas FROM persons GROUP BY tenant_id
)
SELECT 
    t.name AS empresa,
    COALESCE(mc.total_modulos, 0) AS modulos,
    COALESCE(plc.total_plantillas, 0) AS plantillas,
    COALESCE(prc.total_personas, 0) AS personas
FROM tenants t
LEFT JOIN modulos_cnt mc ON mc.tenant_id = t.id
LEFT JOIN plantillas_cnt plc ON plc.tenant_id = t.id
LEFT JOIN personas_cnt prc ON prc.tenant_id = t.id;
```

---

## 20. Organizaciones faltantes de alguna etapa PHVA en sus plantillas
```sql
WITH etapas_totales AS (
    SELECT COUNT(*) AS total FROM phva_stages
),
etapas_tenant AS (
    SELECT tenant_id, COUNT(DISTINCT phva_stage_id) AS etapas_config
    FROM tenanttemplates
    GROUP BY tenant_id
)
SELECT t.name AS empresa_incompleta
FROM tenants t
LEFT JOIN etapas_tenant et ON et.tenant_id = t.id
WHERE COALESCE(et.etapas_config, 0) < (SELECT total FROM etapas_totales);
```

---

## 21. Última fecha de actualización registrada por empresa
```sql
SELECT 
    t.name AS empresa,
    MAX(tt.updated_at) AS ultima_actualizacion
FROM tenants t
JOIN tenanttemplates tt ON tt.tenant_id = t.id
GROUP BY t.id, t.name;
```

---

## 22. Organizaciones con registros documentales pendientes
```sql
SELECT DISTINCT t.name AS empresa_con_pendientes
FROM tenants t
JOIN tenanttemplates tt ON tt.tenant_id = t.id
JOIN document_statuses ds ON ds.id = tt.document_status_id
WHERE ds.code = 'PENDIENTE';
```

---

## 23. Informe consolidado de estado documental por organización
```sql
SELECT 
    t.name AS empresa,
    COUNT(tt.id) AS total_documentos,
    COUNT(CASE WHEN ds.code = 'FINALIZADO' THEN 1 END) AS finalizados,
    COUNT(CASE WHEN ds.code = 'BORRADOR' THEN 1 END) AS borrador,
    COUNT(CASE WHEN ds.code = 'NO_INICIADO' THEN 1 END) AS no_iniciados,
    COUNT(CASE WHEN ds.code = 'PENDIENTE' THEN 1 END) AS pendientes,
    COALESCE(ROUND((COUNT(CASE WHEN ds.code = 'FINALIZADO' THEN 1 END)::NUMERIC / NULLIF(COUNT(tt.id), 0)) * 100, 2), 0) AS pct_cumplimiento
FROM tenants t
LEFT JOIN tenanttemplates tt ON tt.tenant_id = t.id
LEFT JOIN document_statuses ds ON ds.id = tt.document_status_id
GROUP BY t.id, t.name;
```

---

## 24. Comparativa de porcentaje de cumplimiento SST vs PESV por organización
```sql
WITH cumplimiento_sistema AS (
    SELECT 
        tt.tenant_id,
        sys.name AS sistema,
        COALESCE(ROUND((COUNT(CASE WHEN ds.code = 'FINALIZADO' THEN 1 END)::NUMERIC / NULLIF(COUNT(tt.id), 0)) * 100, 2), 0) AS pct
    FROM tenanttemplates tt
    JOIN type_system_sst sys ON sys.id = tt.type_system_sst_id
    JOIN document_statuses ds ON ds.id = tt.document_status_id
    GROUP BY tt.tenant_id, sys.name
),
pivot AS (
    SELECT 
        tenant_id,
        MAX(CASE WHEN sistema = 'SST' THEN pct ELSE 0 END) AS pct_sst,
        MAX(CASE WHEN sistema = 'PESV' THEN pct ELSE 0 END) AS pct_pesv
    FROM cumplimiento_sistema
    GROUP BY tenant_id
)
SELECT 
    t.name AS empresa,
    p.pct_sst,
    p.pct_pesv,
    ABS(p.pct_sst - p.pct_pesv) AS diferencia
FROM pivot p
JOIN tenants t ON t.id = p.tenant_id
WHERE ABS(p.pct_sst - p.pct_pesv) > 10;
```

---

## 25. Vista consolidada de personas, módulos, plantillas y sistemas por empresa
```sql
CREATE OR REPLACE VIEW sst.vw_tenant_summary_consolidated AS
WITH modulos_cnt AS (
    SELECT tenant_id, COUNT(*) AS total_modulos FROM tenant_modules GROUP BY tenant_id
),
plantillas_cnt AS (
    SELECT tenant_id, COUNT(*) AS total_plantillas FROM tenanttemplates GROUP BY tenant_id
),
personas_cnt AS (
    SELECT tenant_id, COUNT(*) AS total_personas FROM persons GROUP BY tenant_id
),
sistemas_cnt AS (
    SELECT tenant_id, COUNT(*) AS total_sistemas FROM tenantsystems WHERE is_active = TRUE GROUP BY tenant_id
)
SELECT 
    t.id AS tenant_id,
    t.name AS empresa,
    COALESCE(prc.total_personas, 0) AS personas,
    COALESCE(mc.total_modulos, 0) AS modulos,
    COALESCE(plc.total_plantillas, 0) AS plantillas,
    COALESCE(sc.total_sistemas, 0) AS sistemas_habilitados
FROM sst.tenants t
LEFT JOIN personas_cnt prc ON prc.tenant_id = t.id
LEFT JOIN modulos_cnt mc ON mc.tenant_id = t.id
LEFT JOIN plantillas_cnt plc ON plc.tenant_id = t.id
LEFT JOIN sistemas_cnt sc ON sc.tenant_id = t.id;
```
