SET search_path TO sst, public;

-- 1. Registrar nueva organización con validación previa
CREATE OR REPLACE PROCEDURE sp_register_tenant(
    p_name VARCHAR, p_tax_id VARCHAR, p_email VARCHAR, p_phone VARCHAR,
    p_city_id INT, p_size_id INT
)
LANGUAGE plpgsql AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM tenants WHERE tax_id = p_tax_id OR contact_email = p_email) THEN
        RAISE EXCEPTION 'La organización con NIT % o correo % ya existe.', p_tax_id, p_email;
    END IF;
    INSERT INTO tenants (name, tax_id, contact_email, contact_phone, city_id, tenant_size_id)
    VALUES (p_name, p_tax_id, p_email, p_phone, p_city_id, p_size_id);
END;
$$;

-- 2. Registrar nueva persona vinculada a organización y cargo
CREATE OR REPLACE PROCEDURE sp_register_person(
    p_tenant_id INT, p_position_id INT, p_document_id VARCHAR,
    p_first_name VARCHAR, p_last_name VARCHAR, p_email VARCHAR, p_phone VARCHAR
)
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO persons (tenant_id, position_id, document_id, first_name, last_name, email, phone)
    VALUES (p_tenant_id, p_position_id, p_document_id, p_first_name, p_last_name, p_email, p_phone);
END;
$$;

-- 3. Cambiar estado de una organización entre activa e inactiva
CREATE OR REPLACE PROCEDURE sp_toggle_tenant_status(p_tenant_id INT, p_is_active BOOLEAN)
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE tenants SET is_active = p_is_active, updated_at = now() WHERE id = p_tenant_id;
END;
$$;

-- 4. Asignar módulo a una organización evitando duplicados
CREATE OR REPLACE PROCEDURE sp_assign_module(p_tenant_id INT, p_module_id INT)
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO tenant_modules (tenant_id, module_id) VALUES (p_tenant_id, p_module_id)
    ON CONFLICT (tenant_id, module_id) DO NOTHING;
END;
$$;

-- 5. Habilitar sistema SST para una organización
CREATE OR REPLACE PROCEDURE sp_enable_system(p_tenant_id INT, p_system_id INT)
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO tenantsystems (tenant_id, type_system_sst_id) VALUES (p_tenant_id, p_system_id)
    ON CONFLICT (tenant_id, type_system_sst_id) DO UPDATE SET is_active = TRUE;
END;
$$;

-- 6. Asignar plantilla a una organización
CREATE OR REPLACE PROCEDURE sp_assign_template(
    p_tenant_id INT, p_template_id INT, p_system_id INT, p_phva_id INT
)
LANGUAGE plpgsql AS $$
DECLARE v_status_id INT;
BEGIN
    SELECT id INTO v_status_id FROM document_statuses WHERE code = 'NO_INICIADO';
    INSERT INTO tenanttemplates (tenant_id, template_id, type_system_sst_id, phva_stage_id, document_status_id)
    VALUES (p_tenant_id, p_template_id, p_system_id, p_phva_id, v_status_id);
END;
$$;

-- 7. Cambiar cargo de una persona
CREATE OR REPLACE PROCEDURE sp_change_person_position(p_person_id INT, p_new_position_id INT)
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE persons SET position_id = p_new_position_id, updated_at = now() WHERE id = p_person_id;
END;
$$;

-- 8. Trasladar persona de una organización a otra
CREATE OR REPLACE PROCEDURE sp_transfer_person(p_person_id INT, p_new_tenant_id INT, p_new_position_id INT)
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE persons SET tenant_id = p_new_tenant_id, position_id = p_new_position_id, updated_at = now() WHERE id = p_person_id;
END;
$$;

-- 9. Deshabilitar módulos de una organización inactiva
CREATE OR REPLACE PROCEDURE sp_disable_modules_inactive_tenant(p_tenant_id INT)
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE tenant_modules SET is_active = FALSE WHERE tenant_id = p_tenant_id;
END;
$$;

-- 10. Eliminar asignación de módulo validando dependencias
CREATE OR REPLACE PROCEDURE sp_remove_module_assignment(p_tenant_id INT, p_module_id INT)
LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM tenant_modules WHERE tenant_id = p_tenant_id AND module_id = p_module_id;
END;
$$;

-- 11. Determinar plantillas por organización y mostrar mediante RAISE NOTICE
CREATE OR REPLACE PROCEDURE sp_notice_tenant_templates_count(p_tenant_id INT)
LANGUAGE plpgsql AS $$
DECLARE v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count FROM tenanttemplates WHERE tenant_id = p_tenant_id;
    RAISE NOTICE 'La organización ID % tiene un total de % plantillas asignadas.', p_tenant_id, v_count;
END;
$$;

-- 12. Determinar porcentaje de cumplimiento documental
CREATE OR REPLACE PROCEDURE sp_get_compliance_pct(p_tenant_id INT, OUT p_pct NUMERIC)
LANGUAGE plpgsql AS $$
DECLARE v_total INT; v_fin INT;
BEGIN
    SELECT COUNT(*), COUNT(CASE WHEN ds.code = 'FINALIZADO' THEN 1 END)
    INTO v_total, v_fin
    FROM tenanttemplates tt
    JOIN document_statuses ds ON ds.id = tt.document_status_id
    WHERE tt.tenant_id = p_tenant_id;
    
    p_pct := COALESCE(ROUND((v_fin::NUMERIC / NULLIF(v_total, 0)) * 100, 2), 0);
END;
$$;

-- 13. Cantidad de documentos por etapa PHVA
CREATE OR REPLACE PROCEDURE sp_count_docs_by_phva(p_tenant_id INT, p_phva_id INT, OUT p_count INT)
LANGUAGE plpgsql AS $$
BEGIN
    SELECT COUNT(*) INTO p_count FROM tenanttemplates WHERE tenant_id = p_tenant_id AND phva_stage_id = p_phva_id;
END;
$$;

-- 14. Modificar datos de contacto de organización
CREATE OR REPLACE PROCEDURE sp_update_tenant_contact(p_tenant_id INT, p_email VARCHAR, p_phone VARCHAR)
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE tenants SET contact_email = p_email, contact_phone = p_phone, updated_at = now() WHERE id = p_tenant_id;
END;
$$;

-- 15. Asignar plantilla con manejo de excepciones
CREATE OR REPLACE PROCEDURE sp_assign_template_safe(
    p_tenant_id INT, p_template_id INT, p_system_id INT, p_phva_id INT
)
LANGUAGE plpgsql AS $$
DECLARE v_status_id INT;
BEGIN
    SELECT id INTO v_status_id FROM document_statuses WHERE code = 'NO_INICIADO';
    INSERT INTO tenanttemplates (tenant_id, template_id, type_system_sst_id, phva_stage_id, document_status_id)
    VALUES (p_tenant_id, p_template_id, p_system_id, p_phva_id, v_status_id);
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error detectado al asignar la plantilla: %', SQLERRM;
END;
$$;
