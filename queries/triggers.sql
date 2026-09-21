SET search_path TO sst, public;

-- 1. Trigger actualiza updated_at en tenants
CREATE OR REPLACE FUNCTION fn_trg_update_tenant_timestamp()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;
CREATE TRIGGER trg_tenants_updated_at BEFORE UPDATE ON tenants FOR EACH ROW EXECUTE FUNCTION fn_trg_update_tenant_timestamp();

-- 2. Trigger actualiza updated_at en persons
CREATE OR REPLACE FUNCTION fn_trg_update_person_timestamp()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;
CREATE TRIGGER trg_persons_updated_at BEFORE UPDATE ON persons FOR EACH ROW EXECUTE FUNCTION fn_trg_update_person_timestamp();

-- 3. Trigger impide registrar personas en organizaciones inactivas
CREATE OR REPLACE FUNCTION fn_trg_prevent_person_inactive_tenant()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM tenants WHERE id = NEW.tenant_id AND is_active = TRUE) THEN
        RAISE EXCEPTION 'No se pueden registrar personas en una organización inactiva.';
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER trg_check_person_tenant BEFORE INSERT OR UPDATE ON persons FOR EACH ROW EXECUTE FUNCTION fn_trg_prevent_person_inactive_tenant();

-- 4. Trigger impide asignar módulos duplicados
CREATE OR REPLACE FUNCTION fn_trg_prevent_duplicate_module()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM tenant_modules WHERE tenant_id = NEW.tenant_id AND module_id = NEW.module_id AND id <> COALESCE(NEW.id, 0)) THEN
        RAISE EXCEPTION 'El módulo ya está asignado a esta organización.';
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER trg_check_duplicate_module BEFORE INSERT ON tenant_modules FOR EACH ROW EXECUTE FUNCTION fn_trg_prevent_duplicate_module();

-- 5. Trigger impide asignar plantillas a organizaciones inactivas
CREATE OR REPLACE FUNCTION fn_trg_prevent_template_inactive_tenant()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM tenants WHERE id = NEW.tenant_id AND is_active = TRUE) THEN
        RAISE EXCEPTION 'No se pueden asignar plantillas a organizaciones inactivas.';
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER trg_check_template_tenant BEFORE INSERT ON tenanttemplates FOR EACH ROW EXECUTE FUNCTION fn_trg_prevent_template_inactive_tenant();

-- 6. Trigger valida que la persona se asocie a un cargo de la misma organización
CREATE OR REPLACE FUNCTION fn_trg_validate_person_position_tenant()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.position_id IS NOT NULL THEN
        IF NOT EXISTS (SELECT 1 FROM positions WHERE id = NEW.position_id AND tenant_id = NEW.tenant_id) THEN
            RAISE EXCEPTION 'El cargo seleccionado no pertenece a la misma organización.';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER trg_check_person_position BEFORE INSERT OR UPDATE ON persons FOR EACH ROW EXECUTE FUNCTION fn_trg_validate_person_position_tenant();

-- 7. Trigger actualiza fecha de modificación en tenanttemplates
CREATE OR REPLACE FUNCTION fn_trg_update_tenanttemplate_timestamp()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;
CREATE TRIGGER trg_tenanttemplate_updated_at BEFORE UPDATE ON tenanttemplates FOR EACH ROW EXECUTE FUNCTION fn_trg_update_tenanttemplate_timestamp();

-- 8. Trigger impide eliminar organización si existen personas
CREATE OR REPLACE FUNCTION fn_trg_prevent_delete_tenant_with_persons()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM persons WHERE tenant_id = OLD.id) THEN
        RAISE EXCEPTION 'No se puede eliminar la organización porque tiene personas asociadas.';
    END IF;
    RETURN OLD;
END;
$$;
CREATE TRIGGER trg_check_delete_tenant BEFORE DELETE ON tenants FOR EACH ROW EXECUTE FUNCTION fn_trg_prevent_delete_tenant_with_persons();

-- 9. Trigger impide eliminar sistema SST si está en uso
CREATE OR REPLACE FUNCTION fn_trg_prevent_delete_system_in_use()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM tenantsystems WHERE type_system_sst_id = OLD.id AND is_active = TRUE) THEN
        RAISE EXCEPTION 'No se puede eliminar el sistema SST porque está en uso por organizaciones.';
    END IF;
    RETURN OLD;
END;
$$;
CREATE TRIGGER trg_check_delete_system BEFORE DELETE ON type_system_sst FOR EACH ROW EXECUTE FUNCTION fn_trg_prevent_delete_system_in_use();

-- 10. Trigger impide eliminar módulo si está asignado
CREATE OR REPLACE FUNCTION fn_trg_prevent_delete_module_in_use()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM tenant_modules WHERE module_id = OLD.id) THEN
        RAISE EXCEPTION 'No se puede eliminar el módulo porque está asignado a organizaciones.';
    END IF;
    RETURN OLD;
END;
$$;
CREATE TRIGGER trg_check_delete_module BEFORE DELETE ON modules FOR EACH ROW EXECUTE FUNCTION fn_trg_prevent_delete_module_in_use();

-- 11. Trigger valida que porcentaje esté entre 0 y 100
CREATE OR REPLACE FUNCTION fn_trg_validate_score_range()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.score IS NOT NULL AND (NEW.score < 0 OR NEW.score > 100) THEN
        RAISE EXCEPTION 'El porcentaje debe estar comprendido entre 0 y 100.';
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER trg_check_score_range BEFORE INSERT OR UPDATE ON evaluations FOR EACH ROW EXECUTE FUNCTION fn_trg_validate_score_range();

-- 12. Trigger auditoría de modificaciones en datos principales de tenant
CREATE OR REPLACE FUNCTION fn_trg_audit_tenant_changes()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF (TG_OP = 'UPDATE') THEN
        INSERT INTO audit_log (tenant_id, action, old_data, new_data)
        VALUES (OLD.id, 'UPDATE', to_jsonb(OLD), to_jsonb(NEW));
        RETURN NEW;
    ELSIF (TG_OP = 'INSERT') THEN
        INSERT INTO audit_log (tenant_id, action, new_data)
        VALUES (NEW.id, 'INSERT', to_jsonb(NEW));
        RETURN NEW;
    ELSIF (TG_OP = 'DELETE') THEN
        INSERT INTO audit_log (tenant_id, action, old_data)
        VALUES (OLD.id, 'DELETE', to_jsonb(OLD));
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$;
CREATE TRIGGER trg_audit_tenants AFTER INSERT OR UPDATE OR DELETE ON tenants FOR EACH ROW EXECUTE FUNCTION fn_trg_audit_tenant_changes();

-- 13. Trigger auditoría de cambio de estado en tenant (guarda valor anterior y nuevo)
CREATE OR REPLACE FUNCTION fn_trg_audit_tenant_status_change()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF OLD.is_active <> NEW.is_active THEN
        INSERT INTO audit_log (tenant_id, action, old_data, new_data)
        VALUES (NEW.id, 'STATUS_CHANGE', jsonb_build_object('is_active', OLD.is_active), jsonb_build_object('is_active', NEW.is_active));
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER trg_audit_tenant_status AFTER UPDATE ON tenants FOR EACH ROW EXECUTE FUNCTION fn_trg_audit_tenant_status_change();

-- 14. Trigger registra fecha y usuario al modificar plantilla
CREATE OR REPLACE FUNCTION fn_trg_audit_template_user_update()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;
CREATE TRIGGER trg_audit_template_update BEFORE UPDATE ON tenanttemplates FOR EACH ROW EXECUTE FUNCTION fn_trg_audit_template_user_update();

-- 15. Trigger elimina o desactiva bloqueos de edición vencidos
CREATE OR REPLACE FUNCTION fn_trg_expire_editing_locks()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    UPDATE editing_locks SET is_active = FALSE WHERE expires_at <= now() AND is_active = TRUE;
    RETURN NEW;
END;
$$;
CREATE TRIGGER trg_check_expired_locks BEFORE INSERT OR UPDATE ON editing_locks FOR EACH STATEMENT EXECUTE FUNCTION fn_trg_expire_editing_locks();
