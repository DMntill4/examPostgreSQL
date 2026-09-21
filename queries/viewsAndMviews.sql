SET search_path TO sst, public;

-- 1. Vista vw_tenant_persons (organizaciones con sus personas y cargos)
CREATE OR REPLACE VIEW vw_tenant_persons AS
SELECT t.id AS tenant_id, t.name AS empresa,
       p.id AS person_id, p.first_name || ' ' || p.last_name AS persona,
       pos.description AS cargo
FROM tenants t
JOIN persons p ON p.tenant_id = t.id
LEFT JOIN positions pos ON pos.id = p.position_id;

-- 2. Vista consolidada geográfica (municipio, departamento/región, país)
CREATE OR REPLACE VIEW vw_tenant_geography AS
SELECT t.id AS tenant_id, t.name AS empresa, c.name AS municipio, r.name AS region, co.name AS pais
FROM tenants t
JOIN cities c ON c.id = t.city_id
JOIN regions r ON r.id = c.region_id
JOIN countries co ON co.id = r.country_id;

-- 3. Vista de módulos habilitados por empresa y su sistema SST
CREATE OR REPLACE VIEW vw_tenant_enabled_modules AS
SELECT t.id AS tenant_id, t.name AS empresa, m.title AS modulo, sys.name AS sistema
FROM tenant_modules tm
JOIN tenants t ON t.id = tm.tenant_id
JOIN modules m ON m.id = tm.module_id
JOIN type_system_sst sys ON sys.id = m.type_system_sst_id
WHERE tm.is_active = TRUE;

-- 4. Vista de cantidad total de plantillas por empresa y etapa PHVA
CREATE OR REPLACE VIEW vw_tenant_templates_by_phva AS
SELECT t.id AS tenant_id, t.name AS empresa, ps.name AS etapa_phva, COUNT(tt.id) AS total_plantillas
FROM tenants t
CROSS JOIN phva_stages ps
LEFT JOIN tenanttemplates tt ON tt.tenant_id = t.id AND tt.phva_stage_id = ps.id
GROUP BY t.id, t.name, ps.id, ps.name, ps.order_num;

-- 5. Vista de personas por organización y cargo
CREATE OR REPLACE VIEW vw_persons_count_by_position AS
SELECT t.id AS tenant_id, t.name AS empresa, pos.description AS cargo, COUNT(p.id) AS total_personas
FROM positions pos
JOIN tenants t ON t.id = pos.tenant_id
LEFT JOIN persons p ON p.position_id = pos.id
GROUP BY t.id, t.name, pos.id, pos.description;

-- 6. Vista Materializada de consolidado de cumplimiento documental
CREATE MATERIALIZED VIEW IF NOT EXISTS vm_tenant_compliance_summary AS
SELECT t.id AS tenant_id, t.name AS empresa,
       COUNT(tt.id) AS total_documentos,
       COUNT(CASE WHEN ds.code = 'FINALIZADO' THEN 1 END) AS documentos_finalizados,
       COUNT(CASE WHEN ds.code = 'PENDIENTE' THEN 1 END) AS documentos_pendientes,
       ROUND((COUNT(CASE WHEN ds.code = 'FINALIZADO' THEN 1 END) * 100.0 / COUNT(tt.id)), 2) AS pct_cumplimiento
FROM tenants t
LEFT JOIN tenanttemplates tt ON tt.tenant_id = t.id
LEFT JOIN document_statuses ds ON ds.id = tt.document_status_id
GROUP BY t.id, t.name;

-- 7. Actualización de vista materializada
REFRESH MATERIALIZED VIEW vm_tenant_compliance_summary;

-- 8. Análisis e índices recomendados para la vista materializada
CREATE UNIQUE INDEX IF NOT EXISTS idx_vm_tenant_compliance_tenant_id ON vm_tenant_compliance_summary(tenant_id);
