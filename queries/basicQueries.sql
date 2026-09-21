SET search_path TO sst, public;

-- 1. Consultar todos los registros almacenados en tenants
SELECT * FROM tenants;

-- 2. Consultar nombre, correo de contacto y teléfono de tenants
SELECT name, contact_email, contact_phone FROM tenants;

-- 3. Listar personas (nombres, apellidos, correo)
SELECT first_name, last_name, email FROM persons;

-- 4. Personas cuyo estado se encuentre activo
SELECT * FROM persons WHERE is_active = TRUE;

-- 5. Organizaciones cuyo nombre contenga una determinada palabra
SELECT * FROM tenants WHERE name ILIKE '%Andina%';

-- 6. Listar todos los países ordenados alfabéticamente
SELECT * FROM countries ORDER BY name ASC;

-- 7. Departamentos o regiones pertenecientes a un país determinado
SELECT * FROM regions WHERE country_id = 1;

-- 8. Municipios o ciudades correspondientes a una región específica
SELECT * FROM cities WHERE region_id = 1;

-- 9. Todos los cargos ordenados por descripción
SELECT * FROM positions ORDER BY description ASC;

-- 10. Personas que pertenezcan a una organización determinada por tenant_id
SELECT * FROM persons WHERE tenant_id = 1;

-- 11. Organizaciones activas dentro del sistema
SELECT * FROM tenants WHERE is_active = TRUE;

-- 12. Organizaciones registradas en un período determinado
SELECT * FROM tenants WHERE created_at BETWEEN '2026-01-01 00:00:00' AND '2026-12-31 23:59:59';

-- 13. Tamaños de empresa en tenant_sizes
SELECT * FROM tenant_sizes;

-- 14. Tipos de sistemas SST en type_system_sst
SELECT * FROM type_system_sst;

-- 15. Módulos registrados (título, descripción, orden de presentación)
SELECT title, description, display_order FROM modules ORDER BY display_order ASC;
