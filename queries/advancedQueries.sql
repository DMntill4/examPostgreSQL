SET search_path TO sst, public;

-- 1. Organización con mayor cantidad de personas registradas
SELECT t.name AS empresa, COUNT(p.id) AS total_personas
FROM tenants t
JOIN persons p ON p.tenant_id = t.id
GROUP BY t.id, t.name
ORDER BY total_personas DESC
LIMIT 1;

-- 2. Organizaciones por encima del promedio general de personas
WITH personas_tenant AS (
    SELECT tenant_id, COUNT(*) AS total
    FROM persons GROUP BY tenant_id
)
SELECT t.name AS empresa, pt.total AS total_personas
FROM personas_tenant pt
JOIN tenants t ON t.id = pt.tenant_id
WHERE pt.total > (SELECT AVG(total) FROM personas_tenant);

-- 3. Organizaciones con todos los módulos existentes para un sistema SST
SELECT t.name AS empresa
FROM tenant_modules tm
JOIN tenants t ON t.id = tm.tenant_id
JOIN modules m ON m.id = tm.module_id
JOIN type_system_sst ts ON ts.id = m.type_system_sst_id
WHERE ts.name = 'SST'
GROUP BY t.id, t.name
HAVING COUNT(tm.module_id) = (
    SELECT COUNT(*) FROM modules m2 
    JOIN type_system_sst ts2 ON ts2.id = m2.type_system_sst_id 
    WHERE ts2.name = 'SST'
);

-- 4. Organizaciones con módulos configurados pero sin plantillas
SELECT t.id, t.name AS empresa
FROM tenants t
WHERE EXISTS (SELECT 1 FROM tenant_modules tm WHERE tm.tenant_id = t.id)
  AND NOT EXISTS (SELECT 1 FROM tenanttemplates tt WHERE tt.tenant_id = t.id);

-- 5. Organizaciones con plantillas asociadas a todas las etapas PHVA
SELECT t.name AS empresa
FROM tenanttemplates tt
JOIN tenants t ON t.id = tt.tenant_id
GROUP BY t.id, t.name
HAVING COUNT(DISTINCT tt.phva_stage_id) = (SELECT COUNT(*) FROM phva_stages);

-- 6. Cantidad de plantillas asignadas discriminadas por etapa PHVA
SELECT t.name AS empresa, ps.name AS etapa_phva, COUNT(tt.id) AS total_plantillas
FROM tenanttemplates tt
JOIN tenants t ON t.id = tt.tenant_id
JOIN phva_stages ps ON ps.id = tt.phva_stage_id
GROUP BY t.id, t.name, ps.id, ps.name, ps.order_num
ORDER BY t.name, ps.order_num;

-- 7. Pivoting de plantillas por etapa PHVA en columnas independientes
SELECT t.name AS empresa,
    COUNT(CASE WHEN tt.phva_stage_id = 1 THEN 1 END) AS planear,
    COUNT(CASE WHEN tt.phva_stage_id = 2 THEN 1 END) AS hacer,
    COUNT(CASE WHEN tt.phva_stage_id = 3 THEN 1 END) AS verificar,
    COUNT(CASE WHEN tt.phva_stage_id = 4 THEN 1 END) AS actuar
FROM tenants t
LEFT JOIN tenanttemplates tt ON tt.tenant_id = t.id
GROUP BY t.id, t.name;

-- 8. Porcentaje de cada etapa PHVA sobre el total de la empresa
SELECT 
    t.name AS empresa,
    ps.name AS etapa_phva,
    COUNT(tt.id) AS plantillas_etapa,
    ROUND((COUNT(tt.id)::NUMERIC / NULLIF(SUM(COUNT(tt.id)) OVER (PARTITION BY t.id), 0)) * 100, 2) AS porcentaje
FROM tenanttemplates tt
JOIN tenants t ON t.id = tt.tenant_id
JOIN phva_stages ps ON ps.id = tt.phva_stage_id
GROUP BY t.id, t.name, ps.id, ps.name, ps.order_num
ORDER BY t.name, ps.order_num;

-- 9. Etapa PHVA con mayor cantidad de plantillas por empresa
WITH conteo AS (
    SELECT tenant_id, phva_stage_id, COUNT(*) AS total,
           DENSE_RANK() OVER (PARTITION BY tenant_id ORDER BY COUNT(*) DESC) AS posicion
    FROM tenanttemplates GROUP BY tenant_id, phva_stage_id
)
SELECT t.name AS empresa, ps.name AS etapa_mayor FROM conteo c
JOIN tenants t ON t.id = c.tenant_id
JOIN phva_stages ps ON ps.id = c.phva_stage_id
WHERE c.posicion = 1;

-- 10. Porcentaje de documentos finalizados frente al total por empresa
SELECT t.name AS empresa, COUNT(tt.id) AS total_documentos,
    COUNT(CASE WHEN ds.code = 'FINALIZADO' THEN 1 END) AS finalizados,
    ROUND((COUNT(CASE WHEN ds.code = 'FINALIZADO' THEN 1 END)::NUMERIC / NULLIF(COUNT(tt.id), 0)) * 100, 2) AS pct_cumplimiento
FROM tenants t
LEFT JOIN tenanttemplates tt ON tt.tenant_id = t.id
LEFT JOIN document_statuses ds ON ds.id = tt.document_status_id
GROUP BY t.id, t.name;

-- 11. Organizaciones con porcentaje de cumplimiento por debajo del promedio general
WITH cumplimiento_empresa AS (
    SELECT t.id AS tenant_id, t.name AS empresa,
        COALESCE(ROUND((COUNT(CASE WHEN ds.code = 'FINALIZADO' THEN 1 END)::NUMERIC / NULLIF(COUNT(tt.id), 0)) * 100, 2), 0) AS pct
    FROM tenants t
    LEFT JOIN tenanttemplates tt ON tt.tenant_id = t.id
    LEFT JOIN document_statuses ds ON ds.id = tt.document_status_id
    GROUP BY t.id, t.name
)
SELECT empresa, pct FROM cumplimiento_empresa
WHERE pct < (SELECT AVG(pct) FROM cumplimiento_empresa);

-- 12. Clasificación de cumplimiento en Bajo, Medio y Alto
SELECT t.name AS empresa,
    COALESCE(ROUND((COUNT(CASE WHEN ds.code = 'FINALIZADO' THEN 1 END)::NUMERIC / NULLIF(COUNT(tt.id), 0)) * 100, 2), 0) AS porcentaje,
    CASE 
        WHEN COALESCE(ROUND((COUNT(CASE WHEN ds.code = 'FINALIZADO' THEN 1 END)::NUMERIC / NULLIF(COUNT(tt.id), 0)) * 100, 2), 0) < 50 THEN 'Bajo'
        WHEN COALESCE(ROUND((COUNT(CASE WHEN ds.code = 'FINALIZADO' THEN 1 END)::NUMERIC / NULLIF(COUNT(tt.id), 0)) * 100, 2), 0) BETWEEN 50 AND 80 THEN 'Medio'
        ELSE 'Alto' 
    END AS categoria_cumplimiento
FROM tenants t
LEFT JOIN tenanttemplates tt ON tt.tenant_id = t.id
LEFT JOIN document_statuses ds ON ds.id = tt.document_status_id
GROUP BY t.id, t.name;

-- 13. Ranking de organizaciones por porcentaje de cumplimiento
WITH cumplimiento AS (
    SELECT t.name AS empresa,
        COALESCE(ROUND((COUNT(CASE WHEN ds.code = 'FINALIZADO' THEN 1 END)::NUMERIC / NULLIF(COUNT(tt.id), 0)) * 100, 2), 0) AS pct
    FROM tenants t
    LEFT JOIN tenanttemplates tt ON tt.tenant_id = t.id
    LEFT JOIN document_statuses ds ON ds.id = tt.document_status_id
    GROUP BY t.id, t.name
)
SELECT empresa, pct, DENSE_RANK() OVER (ORDER BY pct DESC) AS ranking_posicion
FROM cumplimiento;

-- 14. Porcentaje de cumplimiento y diferencia respecto al promedio general
WITH cumplimiento AS (
    SELECT t.name AS empresa,
        COALESCE(ROUND((COUNT(CASE WHEN ds.code = 'FINALIZADO' THEN 1 END)::NUMERIC / NULLIF(COUNT(tt.id), 0)) * 100, 2), 0) AS pct
    FROM tenants t
    LEFT JOIN tenanttemplates tt ON tt.tenant_id = t.id
    LEFT JOIN document_statuses ds ON ds.id = tt.document_status_id
    GROUP BY t.id, t.name
)
SELECT empresa, pct, ROUND(AVG(pct) OVER (), 2) AS promedio_general,
    ROUND(pct - AVG(pct) OVER (), 2) AS diferencia
FROM cumplimiento;

-- 15. Cantidad acumulada de documentos finalizados por organización
SELECT t.name AS empresa, tt.assigned_at::DATE AS fecha_asig,
    COUNT(*) OVER (PARTITION BY t.id ORDER BY tt.assigned_at) AS acumulado_documentos
FROM tenants t
JOIN tenanttemplates tt ON tt.tenant_id = t.id
JOIN document_statuses ds ON ds.id = tt.document_status_id
WHERE ds.code = 'FINALIZADO';

-- 16. Organizaciones en la misma ciudad con diferente tamaño
SELECT t1.name AS empresa_1, ts1.name AS tamano_1, t2.name AS empresa_2, ts2.name AS tamano_2, c.name AS ciudad
FROM tenants t1
JOIN tenants t2 ON t1.city_id = t2.city_id AND t1.id < t2.id
JOIN tenant_sizes ts1 ON ts1.id = t1.tenant_size_id
JOIN tenant_sizes ts2 ON ts2.id = t2.tenant_size_id
JOIN cities c ON c.id = t1.city_id
WHERE t1.tenant_size_id <> t2.tenant_size_id;

-- 17. Personas cuyo cargo supera el promedio de ocupación de su empresa
WITH ocupacion AS (
    SELECT tenant_id, position_id, COUNT(*) AS personas_cargo
    FROM persons WHERE position_id IS NOT NULL GROUP BY tenant_id, position_id
)
SELECT p.first_name || ' ' || p.last_name AS persona, pos.description AS cargo, o.personas_cargo
FROM persons p
JOIN ocupacion o ON o.tenant_id = p.tenant_id AND o.position_id = p.position_id
JOIN positions pos ON pos.id = p.position_id
WHERE o.personas_cargo > (SELECT AVG(personas_cargo) FROM ocupacion WHERE tenant_id = p.tenant_id);

-- 18. CTE para personas por empresa y filtro superiores al promedio
WITH personas_tenant AS (
    SELECT tenant_id, COUNT(*) AS total_personas FROM persons GROUP BY tenant_id
)
SELECT t.name AS empresa, pt.total_personas
FROM personas_tenant pt
JOIN tenants t ON t.id = pt.tenant_id
WHERE pt.total_personas > (SELECT AVG(total_personas) FROM personas_tenant);

-- 19. CTE consolidado de Módulos, Plantillas y Personas por organización
SELECT t.name AS empresa,
    (SELECT COUNT(*) FROM tenant_modules tm WHERE tm.tenant_id = t.id) AS modulos,
    (SELECT COUNT(*) FROM tenanttemplates tt WHERE tt.tenant_id = t.id) AS plantillas,
    (SELECT COUNT(*) FROM persons p WHERE p.tenant_id = t.id) AS personas
FROM tenants t;

-- 20. Organizaciones faltantes de alguna etapa PHVA en sus plantillas
SELECT t.name AS empresa_incompleta FROM tenants t
LEFT JOIN tenanttemplates tt ON tt.tenant_id = t.id
GROUP BY t.id, t.name
HAVING COUNT(DISTINCT tt.phva_stage_id) < (SELECT COUNT(*) FROM phva_stages);

-- 21. Última fecha de actualización registrada por empresa
SELECT t.name AS empresa, MAX(tt.updated_at) AS ultima_actualizacion
FROM tenants t
JOIN tenanttemplates tt ON tt.tenant_id = t.id
GROUP BY t.id, t.name;

-- 22. Organizaciones con registros documentales pendientes
SELECT DISTINCT t.name AS empresa_con_pendientes
FROM tenants t
JOIN tenanttemplates tt ON tt.tenant_id = t.id
JOIN document_statuses ds ON ds.id = tt.document_status_id
WHERE ds.code = 'PENDIENTE';

-- 23. Informe consolidado de estado documental por organización
SELECT t.name AS empresa, COUNT(tt.id) AS total_documentos,
    COUNT(CASE WHEN ds.code = 'FINALIZADO' THEN 1 END) AS finalizados,
    COUNT(CASE WHEN ds.code = 'BORRADOR' THEN 1 END) AS borrador,
    COUNT(CASE WHEN ds.code = 'NO_INICIADO' THEN 1 END) AS no_iniciados,
    COUNT(CASE WHEN ds.code = 'PENDIENTE' THEN 1 END) AS pendientes,
    COALESCE(ROUND((COUNT(CASE WHEN ds.code = 'FINALIZADO' THEN 1 END)::NUMERIC / NULLIF(COUNT(tt.id), 0)) * 100, 2), 0) AS pct_cumplimiento
FROM tenants t
LEFT JOIN tenanttemplates tt ON tt.tenant_id = t.id
LEFT JOIN document_statuses ds ON ds.id = tt.document_status_id
GROUP BY t.id, t.name;

-- 24. Comparativa de porcentaje de cumplimiento SST vs PESV por organización
WITH cumplimiento_sistema AS (
    SELECT tt.tenant_id, sys.name AS sistema,
        COALESCE(ROUND((COUNT(CASE WHEN ds.code = 'FINALIZADO' THEN 1 END)::NUMERIC / NULLIF(COUNT(tt.id), 0)) * 100, 2), 0) AS pct
    FROM tenanttemplates tt
    JOIN type_system_sst sys ON sys.id = tt.type_system_sst_id
    JOIN document_statuses ds ON ds.id = tt.document_status_id
    GROUP BY tt.tenant_id, sys.name
),
pivot AS (
    SELECT tenant_id,
        MAX(CASE WHEN sistema = 'SST' THEN pct ELSE 0 END) AS pct_sst,
        MAX(CASE WHEN sistema = 'PESV' THEN pct ELSE 0 END) AS pct_pesv
    FROM cumplimiento_sistema GROUP BY tenant_id
)
SELECT t.name AS empresa, p.pct_sst, p.pct_pesv, ABS(p.pct_sst - p.pct_pesv) AS diferencia
FROM pivot p
JOIN tenants t ON t.id = p.tenant_id
WHERE ABS(p.pct_sst - p.pct_pesv) > 10;

-- 25. Vista consolidada de personas, módulos, plantillas y sistemas por empresa
CREATE OR REPLACE VIEW sst.vw_tenant_summary_consolidated AS
SELECT t.id AS tenant_id, t.name AS empresa,
    (SELECT COUNT(*) FROM persons p WHERE p.tenant_id = t.id) AS personas,
    (SELECT COUNT(*) FROM tenant_modules tm WHERE tm.tenant_id = t.id) AS modulos,
    (SELECT COUNT(*) FROM tenanttemplates tt WHERE tt.tenant_id = t.id) AS plantillas,
    (SELECT COUNT(*) FROM tenantsystems ts WHERE ts.tenant_id = t.id AND ts.is_active = TRUE) AS sistemas_habilitados
FROM sst.tenants t;
