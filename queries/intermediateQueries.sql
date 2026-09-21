SET search_path TO sst, public;

-- 1. Personas con nombre completo y nombre de la organización
SELECT p.first_name || ' ' || p.last_name AS full_name, t.name AS empresa
FROM persons p
JOIN tenants t ON t.id = p.tenant_id;

-- 2. Cada persona junto con el cargo que desempeña
SELECT p.first_name || ' ' || p.last_name AS full_name, pos.description AS cargo
FROM persons p
LEFT JOIN positions pos ON pos.id = p.position_id;

-- 3. Organización junto con su tamaño de empresa
SELECT t.name AS empresa, ts.name AS tamano_empresa
FROM tenants t
JOIN tenant_sizes ts ON ts.id = t.tenant_size_id;

-- 4. Organización con ciudad, región y país
SELECT t.name AS empresa, c.name AS ciudad, r.name AS region, co.name AS pais
FROM tenants t
JOIN cities c ON c.id = t.city_id
JOIN regions r ON r.id = c.region_id
JOIN countries co ON co.id = r.country_id;

-- 5. Cantidad de personas en cada organización
SELECT t.name AS empresa, COUNT(p.id) AS total_personas
FROM tenants t
LEFT JOIN persons p ON p.tenant_id = t.id
GROUP BY t.id, t.name;

-- 6. Organizaciones con más de una cantidad determinada de personas
SELECT t.name AS empresa, COUNT(p.id) AS total_personas
FROM tenants t
JOIN persons p ON p.tenant_id = t.id
GROUP BY t.id, t.name
HAVING COUNT(p.id) > 1;

-- 7. Módulos habilitados para cada organización
SELECT t.name AS empresa, m.title AS modulo
FROM tenant_modules tm
JOIN tenants t ON t.id = tm.tenant_id
JOIN modules m ON m.id = tm.module_id;

-- 8. Cantidad de módulos habilitados por organización
SELECT t.name AS empresa, COUNT(tm.module_id) AS total_modulos
FROM tenants t
LEFT JOIN tenant_modules tm ON tm.tenant_id = t.id
GROUP BY t.id, t.name;

-- 9. Sistemas SST habilitados para cada organización
SELECT t.name AS empresa, tsyst.name AS sistema
FROM tenantsystems ts
JOIN tenants t ON t.id = ts.tenant_id
JOIN type_system_sst tsyst ON tsyst.id = ts.type_system_sst_id
WHERE ts.is_active = TRUE;

-- 10. Módulos existentes junto con el sistema SST al que pertenecen
SELECT m.title AS modulo, tsyst.name AS sistema
FROM modules m
JOIN type_system_sst tsyst ON tsyst.id = m.type_system_sst_id;

-- 11. Formatos registrados en formats_sst con su módulo
SELECT f.name AS formato, m.title AS modulo
FROM formats_sst f
JOIN modules m ON m.id = f.module_id;

-- 12. Cantidad de formatos asociados a cada módulo
SELECT m.title AS modulo, COUNT(f.id) AS total_formatos
FROM modules m
LEFT JOIN formats_sst f ON f.module_id = m.id
GROUP BY m.id, m.title;

-- 13. Plantillas asignadas a cada organización
SELECT t.name AS empresa, tmpl.name AS plantilla
FROM tenanttemplates tt
JOIN tenants t ON t.id = tt.tenant_id
JOIN templates tmpl ON tmpl.id = tt.template_id;

-- 14. Plantilla asignada indicando organización, sistema SST y etapa PHVA
SELECT t.name AS empresa, tmpl.name AS plantilla, tsyst.name AS sistema, ph.name AS etapa_phva
FROM tenanttemplates tt
JOIN tenants t ON t.id = tt.tenant_id
JOIN templates tmpl ON tmpl.id = tt.template_id
JOIN type_system_sst tsyst ON tsyst.id = tt.type_system_sst_id
JOIN phva_stages ph ON ph.id = tt.phva_stage_id;

-- 15. Cantidad de plantillas asignadas a cada organización
SELECT t.name AS empresa, COUNT(tt.id) AS total_plantillas
FROM tenants t
LEFT JOIN tenanttemplates tt ON tt.tenant_id = t.id
GROUP BY t.id, t.name;

-- 16. Organizaciones que actualmente no tengan personas registradas
SELECT t.id, t.name AS empresa
FROM tenants t
LEFT JOIN persons p ON p.tenant_id = t.id
WHERE p.id IS NULL;

-- 17. Módulos que todavía no hayan sido asignados a ninguna organización
SELECT m.id, m.title AS modulo
FROM modules m
LEFT JOIN tenant_modules tm ON tm.module_id = m.id
WHERE tm.id IS NULL;

-- 18. Etapas PHVA mostrando el número de plantillas asociadas
SELECT ph.name AS etapa_phva, COUNT(tmpl.id) AS total_plantillas
FROM phva_stages ph
LEFT JOIN templates tmpl ON tmpl.phva_stage_id = ph.id
GROUP BY ph.id, ph.name, ph.order_num
ORDER BY ph.order_num;

-- 19. Cantidad de organizaciones registradas en cada municipio o ciudad
SELECT c.name AS ciudad, COUNT(t.id) AS total_organizaciones
FROM cities c
LEFT JOIN tenants t ON t.city_id = c.id
GROUP BY c.id, c.name;

-- 20. Cargos existentes en cada organización y personas que ocupan cada cargo
SELECT t.name AS empresa, pos.description AS cargo, COUNT(p.id) AS total_personas
FROM positions pos
JOIN tenants t ON t.id = pos.tenant_id
LEFT JOIN persons p ON p.position_id = pos.id
GROUP BY t.id, t.name, pos.id, pos.description;
