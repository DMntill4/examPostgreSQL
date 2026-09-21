SET search_path TO sst, public;

-- 1. Función que retorna la cantidad total de personas asociadas a un tenant
CREATE OR REPLACE FUNCTION fn_count_persons(p_tenant_id INT)
RETURNS INT LANGUAGE plpgsql AS $$
DECLARE v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count FROM persons WHERE tenant_id = p_tenant_id;
    RETURN COALESCE(v_count, 0);
END;
$$;

-- 2. Función que retorna el porcentaje de cumplimiento documental
CREATE OR REPLACE FUNCTION fn_get_compliance_pct(p_tenant_id INT)
RETURNS NUMERIC(5,2) LANGUAGE plpgsql AS $$
DECLARE v_total INT; v_fin INT;
BEGIN
    SELECT COUNT(*), COUNT(CASE WHEN ds.code = 'FINALIZADO' THEN 1 END)
    INTO v_total, v_fin
    FROM tenanttemplates tt
    JOIN document_statuses ds ON ds.id = tt.document_status_id
    WHERE tt.tenant_id = p_tenant_id;
    
    IF v_total = 0 THEN
        RETURN 0.00;
    END IF;
    RETURN ROUND((v_fin * 100.0 / v_total), 2);
END;
$$;

-- 3. Función que valida si un módulo está habilitado (booleano)
CREATE OR REPLACE FUNCTION fn_is_module_enabled(p_tenant_id INT, p_module_id INT)
RETURNS BOOLEAN LANGUAGE plpgsql AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM tenant_modules WHERE tenant_id = p_tenant_id AND module_id = p_module_id AND is_active = TRUE
    );
END;
$$;

-- 4. Función que retorna nombre completo de una persona
CREATE OR REPLACE FUNCTION fn_get_full_name(p_person_id INT)
RETURNS VARCHAR LANGUAGE plpgsql AS $$
DECLARE v_name VARCHAR;
BEGIN
    SELECT first_name || ' ' || last_name INTO v_name FROM persons WHERE id = p_person_id;
    RETURN COALESCE(v_name, '');
END;
$$;

-- 5. Función que retorna la cantidad de plantillas por tenant y etapa PHVA
CREATE OR REPLACE FUNCTION fn_count_templates_by_phva(p_tenant_id INT, p_phva_id INT)
RETURNS INT LANGUAGE plpgsql AS $$
DECLARE v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count FROM tenanttemplates WHERE tenant_id = p_tenant_id AND phva_stage_id = p_phva_id;
    RETURN COALESCE(v_count, 0);
END;
$$;

-- 6. Función tabular que retorna todos los módulos habilitados por tenant
CREATE OR REPLACE FUNCTION fn_get_enabled_modules(p_tenant_id INT)
RETURNS TABLE(module_id INT, title VARCHAR, description TEXT) LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT m.id, m.title, m.description
    FROM tenant_modules tm
    JOIN modules m ON m.id = tm.module_id
    WHERE tm.tenant_id = p_tenant_id AND tm.is_active = TRUE;
END;
$$;

-- 7. Función tabular que retorna personas pertenecientes a un tenant con sus cargos
CREATE OR REPLACE FUNCTION fn_get_tenant_persons_positions(p_tenant_id INT)
RETURNS TABLE(person_id INT, full_name VARCHAR, email VARCHAR, cargo VARCHAR) LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT p.id, (p.first_name || ' ' || p.last_name)::VARCHAR, p.email, COALESCE(pos.description, 'Sin Cargo')::VARCHAR
    FROM persons p
    LEFT JOIN positions pos ON pos.id = p.position_id
    WHERE p.tenant_id = p_tenant_id;
END;
$$;

-- 8. Función que clasifica el nivel de cumplimiento (Bajo, Medio, Alto)
CREATE OR REPLACE FUNCTION fn_get_compliance_category(p_tenant_id INT)
RETURNS VARCHAR LANGUAGE plpgsql AS $$
DECLARE v_pct NUMERIC(5,2);
BEGIN
    v_pct := fn_get_compliance_pct(p_tenant_id);
    IF v_pct < 50 THEN RETURN 'Bajo';
    ELSIF v_pct BETWEEN 50 AND 80 THEN RETURN 'Medio';
    ELSE RETURN 'Alto';
    END IF;
END;
$$;
