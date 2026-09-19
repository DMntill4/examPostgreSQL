-- =========================================================================
-- Archivo: 02_seed_data.sql
-- Objetivo: Cargar datos de parametrización (catálogos) y un conjunto
--           mínimo de datos de ejemplo por organización, para poder luego
--           practicar las consultas, vistas, funciones y triggers.
-- =========================================================================

SET search_path TO sst, public;

-- ---------- Geografía ----------
INSERT INTO countries (name, iso_code) VALUES
('Colombia', 'COL'),
('México', 'MEX');

INSERT INTO regions (country_id, name) VALUES
((SELECT id FROM countries WHERE name = 'Colombia'), 'Santander'),
((SELECT id FROM countries WHERE name = 'Colombia'), 'Antioquia'),
((SELECT id FROM countries WHERE name = 'Colombia'), 'Cundinamarca'),
((SELECT id FROM countries WHERE name = 'México'),   'Jalisco');

INSERT INTO cities (region_id, name) VALUES
((SELECT id FROM regions WHERE name = 'Santander'),     'Bucaramanga'),
((SELECT id FROM regions WHERE name = 'Santander'),     'Floridablanca'),
((SELECT id FROM regions WHERE name = 'Antioquia'),     'Medellín'),
((SELECT id FROM regions WHERE name = 'Cundinamarca'),  'Bogotá'),
((SELECT id FROM regions WHERE name = 'Jalisco'),       'Guadalajara');

-- ---------- Parametrización general ----------
INSERT INTO tenant_sizes (name, min_employees, max_employees) VALUES
('Microempresa', 1, 10),
('Pequeña',      11, 50),
('Mediana',      51, 200),
('Grande',       201, NULL);

INSERT INTO type_system_sst (name, description) VALUES
('SST',  'Sistema de Gestión de Seguridad y Salud en el Trabajo'),
('PESV', 'Plan Estratégico de Seguridad Vial');

INSERT INTO phva_stages (name, order_num) VALUES
('Planear',   1),
('Hacer',     2),
('Verificar', 3),
('Actuar',    4);

INSERT INTO document_statuses (code, name) VALUES
('NO_INICIADO', 'No iniciado'),
('BORRADOR',    'En borrador'),
('FINALIZADO',  'Finalizado'),
('PENDIENTE',   'Pendiente');

-- ---------- Tenants (organizaciones) de ejemplo ----------
INSERT INTO tenants (name, tax_id, contact_email, contact_phone, city_id, tenant_size_id, is_active) VALUES
('Constructora Andina S.A.S.', '900123456-1', 'contacto@andina.com',  '6076000000',
    (SELECT id FROM cities WHERE name = 'Bucaramanga'),
    (SELECT id FROM tenant_sizes WHERE name = 'Mediana'), TRUE),
('Transportes del Oriente Ltda.', '900654321-2', 'contacto@transoriente.com', '6076111111',
    (SELECT id FROM cities WHERE name = 'Floridablanca'),
    (SELECT id FROM tenant_sizes WHERE name = 'Pequeña'), TRUE),
('Textiles Paisa S.A.', '900789456-3', 'contacto@textilespaisa.com', '6042222222',
    (SELECT id FROM cities WHERE name = 'Medellín'),
    (SELECT id FROM tenant_sizes WHERE name = 'Grande'), TRUE);

-- ---------- Cargos por organización ----------
INSERT INTO positions (tenant_id, description) VALUES
((SELECT id FROM tenants WHERE tax_id = '900123456-1'), 'Coordinador SST'),
((SELECT id FROM tenants WHERE tax_id = '900123456-1'), 'Operario de obra'),
((SELECT id FROM tenants WHERE tax_id = '900654321-2'), 'Conductor'),
((SELECT id FROM tenants WHERE tax_id = '900654321-2'), 'Supervisor PESV'),
((SELECT id FROM tenants WHERE tax_id = '900789456-3'), 'Jefe de planta');

-- ---------- Personas ----------
INSERT INTO persons (tenant_id, position_id, document_id, first_name, last_name, email, phone, is_active) VALUES
((SELECT id FROM tenants WHERE tax_id = '900123456-1'),
 (SELECT id FROM positions WHERE description = 'Coordinador SST'),
 '1091111111', 'Laura', 'Gómez', 'laura.gomez@andina.com', '3001111111', TRUE),
((SELECT id FROM tenants WHERE tax_id = '900123456-1'),
 (SELECT id FROM positions WHERE description = 'Operario de obra'),
 '1091111112', 'Carlos', 'Pérez', 'carlos.perez@andina.com', '3001111112', TRUE),
((SELECT id FROM tenants WHERE tax_id = '900654321-2'),
 (SELECT id FROM positions WHERE description = 'Conductor'),
 '1091111113', 'Andrés', 'Rojas', 'andres.rojas@transoriente.com', '3001111113', TRUE),
((SELECT id FROM tenants WHERE tax_id = '900789456-3'),
 (SELECT id FROM positions WHERE description = 'Jefe de planta'),
 '1091111114', 'María', 'López', 'maria.lopez@textilespaisa.com', '3001111114', TRUE);

-- ---------- Sistemas SST habilitados por tenant ----------
INSERT INTO tenantsystems (tenant_id, type_system_sst_id, is_active) VALUES
((SELECT id FROM tenants WHERE tax_id = '900123456-1'), (SELECT id FROM type_system_sst WHERE name='SST'),  TRUE),
((SELECT id FROM tenants WHERE tax_id = '900654321-2'), (SELECT id FROM type_system_sst WHERE name='SST'),  TRUE),
((SELECT id FROM tenants WHERE tax_id = '900654321-2'), (SELECT id FROM type_system_sst WHERE name='PESV'), TRUE),
((SELECT id FROM tenants WHERE tax_id = '900789456-3'), (SELECT id FROM type_system_sst WHERE name='SST'),  TRUE);

-- ---------- Módulos (catálogo, por sistema SST) ----------
INSERT INTO modules (type_system_sst_id, title, description, display_order) VALUES
((SELECT id FROM type_system_sst WHERE name='SST'),  'Política y objetivos',        'Definición de política SST', 1),
((SELECT id FROM type_system_sst WHERE name='SST'),  'Identificación de peligros',  'IPEVR y matriz de riesgos', 2),
((SELECT id FROM type_system_sst WHERE name='PESV'), 'Diagnóstico vial',            'Diagnóstico de seguridad vial', 1),
((SELECT id FROM type_system_sst WHERE name='PESV'), 'Plan de acción vial',         'Plan de acción PESV', 2);

-- ---------- Módulos habilitados por tenant ----------
INSERT INTO tenant_modules (tenant_id, module_id) VALUES
((SELECT id FROM tenants WHERE tax_id = '900123456-1'), (SELECT id FROM modules WHERE title='Política y objetivos')),
((SELECT id FROM tenants WHERE tax_id = '900123456-1'), (SELECT id FROM modules WHERE title='Identificación de peligros')),
((SELECT id FROM tenants WHERE tax_id = '900654321-2'), (SELECT id FROM modules WHERE title='Diagnóstico vial')),
((SELECT id FROM tenants WHERE tax_id = '900789456-3'), (SELECT id FROM modules WHERE title='Política y objetivos'));

-- ---------- Formatos por módulo ----------
INSERT INTO formats_sst (module_id, name, description) VALUES
((SELECT id FROM modules WHERE title='Política y objetivos'), 'Formato política SST', 'Formato para redactar la política'),
((SELECT id FROM modules WHERE title='Identificación de peligros'), 'Matriz IPEVR', 'Formato de identificación de peligros'),
((SELECT id FROM modules WHERE title='Diagnóstico vial'), 'Formato diagnóstico vial', 'Formato base diagnóstico PESV');

-- ---------- Plantillas (catálogo general) ----------
INSERT INTO templates (module_id, format_id, phva_stage_id, name, description) VALUES
((SELECT id FROM modules WHERE title='Política y objetivos'),
 (SELECT id FROM formats_sst WHERE name='Formato política SST'),
 (SELECT id FROM phva_stages WHERE name='Planear'),
 'Plantilla política SST', 'Documento base de política SST'),
((SELECT id FROM modules WHERE title='Identificación de peligros'),
 (SELECT id FROM formats_sst WHERE name='Matriz IPEVR'),
 (SELECT id FROM phva_stages WHERE name='Hacer'),
 'Plantilla matriz IPEVR', 'Documento base matriz de riesgos'),
((SELECT id FROM modules WHERE title='Diagnóstico vial'),
 (SELECT id FROM formats_sst WHERE name='Formato diagnóstico vial'),
 (SELECT id FROM phva_stages WHERE name='Planear'),
 'Plantilla diagnóstico vial', 'Documento base diagnóstico PESV');

-- ---------- Plantillas asignadas a organizaciones ----------
INSERT INTO tenanttemplates (tenant_id, template_id, type_system_sst_id, phva_stage_id, document_status_id, updated_by) VALUES
((SELECT id FROM tenants WHERE tax_id = '900123456-1'),
 (SELECT id FROM templates WHERE name='Plantilla política SST'),
 (SELECT id FROM type_system_sst WHERE name='SST'),
 (SELECT id FROM phva_stages WHERE name='Planear'),
 (SELECT id FROM document_statuses WHERE code='FINALIZADO'),
 (SELECT id FROM persons WHERE document_id='1091111111')),
((SELECT id FROM tenants WHERE tax_id = '900123456-1'),
 (SELECT id FROM templates WHERE name='Plantilla matriz IPEVR'),
 (SELECT id FROM type_system_sst WHERE name='SST'),
 (SELECT id FROM phva_stages WHERE name='Hacer'),
 (SELECT id FROM document_statuses WHERE code='BORRADOR'),
 (SELECT id FROM persons WHERE document_id='1091111111')),
((SELECT id FROM tenants WHERE tax_id = '900654321-2'),
 (SELECT id FROM templates WHERE name='Plantilla diagnóstico vial'),
 (SELECT id FROM type_system_sst WHERE name='PESV'),
 (SELECT id FROM phva_stages WHERE name='Planear'),
 (SELECT id FROM document_statuses WHERE code='NO_INICIADO'),
 NULL);

-- ---------- Documentos generados por tenant ----------
INSERT INTO tenant_documents (tenanttemplate_id, document_name, document_status_id) VALUES
((SELECT tt.id FROM tenanttemplates tt JOIN templates t ON t.id = tt.template_id WHERE t.name = 'Plantilla política SST' LIMIT 1),
 'Política_SST_Constructora_Andina_2026.pdf',
 (SELECT id FROM document_statuses WHERE code='FINALIZADO')),
((SELECT tt.id FROM tenanttemplates tt JOIN templates t ON t.id = tt.template_id WHERE t.name = 'Plantilla matriz IPEVR' LIMIT 1),
 'Matriz_Riesgos_Obra_Bucaramanga.xlsx',
 (SELECT id FROM document_statuses WHERE code='BORRADOR'));

-- ---------- Evaluaciones ----------
INSERT INTO evaluations (tenanttemplate_id, name, description, score, evaluated_at) VALUES
((SELECT tt.id FROM tenanttemplates tt
    JOIN templates t ON t.id = tt.template_id
    WHERE t.name = 'Plantilla política SST' LIMIT 1),
 'Evaluación inicial política SST', 'Revisión de cumplimiento de la política', 85.5, now());

