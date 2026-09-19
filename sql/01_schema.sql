-- =========================================================================
-- Proyecto: Base de datos SST / PESV - Plataforma multi-tenant
-- Archivo : 01_schema.sql
-- Motor   : PostgreSQL 16
-- Objetivo: Crear el esquema, todas las tablas normalizadas (3FN),
--           llaves primarias/foráneas y restricciones de integridad.
--           NO incluye consultas, vistas, funciones, procedimientos ni
--           triggers (eso se trabaja aparte).
-- =========================================================================

CREATE SCHEMA IF NOT EXISTS sst;
SET search_path TO sst, public;

-- Extensión útil para UUID si se necesita en el futuro (opcional)
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- =========================================================================
-- 1. UBICACIÓN GEOGRÁFICA (normalizada: país -> departamento/región -> ciudad)
-- =========================================================================

CREATE TABLE countries (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(100) NOT NULL,
    iso_code    VARCHAR(3)   NOT NULL,
    CONSTRAINT uq_countries_name UNIQUE (name),
    CONSTRAINT uq_countries_iso  UNIQUE (iso_code)
);

CREATE TABLE regions (                      -- departamentos / regiones
    id          SERIAL PRIMARY KEY,
    country_id  INTEGER NOT NULL REFERENCES countries(id) ON DELETE RESTRICT,
    name        VARCHAR(100) NOT NULL,
    CONSTRAINT uq_regions_country_name UNIQUE (country_id, name)
);

CREATE TABLE cities (                       -- municipios / ciudades
    id          SERIAL PRIMARY KEY,
    region_id   INTEGER NOT NULL REFERENCES regions(id) ON DELETE RESTRICT,
    name        VARCHAR(100) NOT NULL,
    CONSTRAINT uq_cities_region_name UNIQUE (region_id, name)
);

-- =========================================================================
-- 2. PARAMETRIZACIÓN GENERAL
-- =========================================================================

CREATE TABLE tenant_sizes (                 -- tamaño de empresa
    id            SERIAL PRIMARY KEY,
    name          VARCHAR(50) NOT NULL,      -- Micro, Pequeña, Mediana, Grande
    min_employees INTEGER NOT NULL DEFAULT 0,
    max_employees INTEGER,
    CONSTRAINT uq_tenant_sizes_name UNIQUE (name),
    CONSTRAINT chk_tenant_sizes_range CHECK (max_employees IS NULL OR max_employees >= min_employees)
);

CREATE TABLE type_system_sst (              -- tipos de sistema: SST, PESV, etc.
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(100) NOT NULL,
    description TEXT,
    CONSTRAINT uq_type_system_sst_name UNIQUE (name)
);

CREATE TABLE phva_stages (                  -- Planear, Hacer, Verificar, Actuar
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(20) NOT NULL,
    order_num   SMALLINT NOT NULL,
    CONSTRAINT uq_phva_stages_name UNIQUE (name),
    CONSTRAINT uq_phva_stages_order UNIQUE (order_num)
);

-- =========================================================================
-- 3. TENANTS (organizaciones / empresas) - núcleo multi-tenant
-- =========================================================================

CREATE TABLE tenants (
    id              SERIAL PRIMARY KEY,
    name            VARCHAR(200) NOT NULL,
    tax_id          VARCHAR(30)  NOT NULL,     -- NIT / identificación fiscal
    contact_email   VARCHAR(150) NOT NULL,
    contact_phone   VARCHAR(30),
    city_id         INTEGER REFERENCES cities(id) ON DELETE RESTRICT,
    tenant_size_id  INTEGER REFERENCES tenant_sizes(id) ON DELETE RESTRICT,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_tenants_tax_id UNIQUE (tax_id),
    CONSTRAINT uq_tenants_contact_email UNIQUE (contact_email),
    CONSTRAINT chk_tenants_email CHECK (contact_email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$')
);

-- =========================================================================
-- 4. CARGOS Y PERSONAS (dependen de tenant)
-- =========================================================================

CREATE TABLE positions (                    -- cargos, propios de cada organización
    id          SERIAL PRIMARY KEY,
    tenant_id   INTEGER NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    description VARCHAR(150) NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_positions_tenant_desc UNIQUE (tenant_id, description)
);

CREATE TABLE persons (
    id           SERIAL PRIMARY KEY,
    tenant_id    INTEGER NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    position_id  INTEGER REFERENCES positions(id) ON DELETE SET NULL,
    document_id  VARCHAR(30) NOT NULL,        -- cédula / documento de identidad
    first_name   VARCHAR(100) NOT NULL,
    last_name    VARCHAR(100) NOT NULL,
    email        VARCHAR(150) NOT NULL,
    phone        VARCHAR(30),
    is_active    BOOLEAN NOT NULL DEFAULT TRUE,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_persons_email UNIQUE (email),
    CONSTRAINT uq_persons_tenant_document UNIQUE (tenant_id, document_id),
    CONSTRAINT chk_persons_email CHECK (email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$')
);

-- =========================================================================
-- 5. SISTEMAS SST HABILITADOS POR TENANT
-- =========================================================================

CREATE TABLE tenantsystems (
    id               SERIAL PRIMARY KEY,
    tenant_id        INTEGER NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    type_system_sst_id INTEGER NOT NULL REFERENCES type_system_sst(id) ON DELETE RESTRICT,
    enabled_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    is_active        BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_tenantsystems_tenant_system UNIQUE (tenant_id, type_system_sst_id)
);

-- =========================================================================
-- 6. MÓDULOS (catálogo general, pertenecen a un sistema SST)
-- =========================================================================

CREATE TABLE modules (
    id                  SERIAL PRIMARY KEY,
    type_system_sst_id  INTEGER NOT NULL REFERENCES type_system_sst(id) ON DELETE RESTRICT,
    title               VARCHAR(150) NOT NULL,
    description         TEXT,
    display_order       SMALLINT NOT NULL DEFAULT 0,
    CONSTRAINT uq_modules_system_title UNIQUE (type_system_sst_id, title)
);

CREATE TABLE tenant_modules (               -- módulos habilitados por organización
    id          SERIAL PRIMARY KEY,
    tenant_id   INTEGER NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    module_id   INTEGER NOT NULL REFERENCES modules(id) ON DELETE RESTRICT,
    enabled_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    is_active   BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_tenant_modules_tenant_module UNIQUE (tenant_id, module_id)
);

-- =========================================================================
-- 7. FORMATOS (asociados a un módulo)
-- =========================================================================

CREATE TABLE formats_sst (
    id          SERIAL PRIMARY KEY,
    module_id   INTEGER NOT NULL REFERENCES modules(id) ON DELETE CASCADE,
    name        VARCHAR(150) NOT NULL,
    description TEXT,
    CONSTRAINT uq_formats_module_name UNIQUE (module_id, name)
);

-- =========================================================================
-- 8. PLANTILLAS (catálogo general de documentos base)
-- =========================================================================

CREATE TABLE templates (
    id              SERIAL PRIMARY KEY,
    module_id       INTEGER NOT NULL REFERENCES modules(id) ON DELETE RESTRICT,
    format_id       INTEGER REFERENCES formats_sst(id) ON DELETE SET NULL,
    phva_stage_id   INTEGER NOT NULL REFERENCES phva_stages(id) ON DELETE RESTRICT,
    name            VARCHAR(200) NOT NULL,
    description     TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_templates_module_name UNIQUE (module_id, name)
);

-- Estados posibles de un documento/plantilla asignada
CREATE TABLE document_statuses (
    id      SERIAL PRIMARY KEY,
    code    VARCHAR(20) NOT NULL,   -- NO_INICIADO, BORRADOR, FINALIZADO, PENDIENTE
    name    VARCHAR(50) NOT NULL,
    CONSTRAINT uq_document_statuses_code UNIQUE (code)
);

-- =========================================================================
-- 9. PLANTILLAS ASIGNADAS A CADA ORGANIZACIÓN (documentos por tenant)
-- =========================================================================

CREATE TABLE tenanttemplates (
    id                  SERIAL PRIMARY KEY,
    tenant_id           INTEGER NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    template_id         INTEGER NOT NULL REFERENCES templates(id) ON DELETE RESTRICT,
    type_system_sst_id  INTEGER NOT NULL REFERENCES type_system_sst(id) ON DELETE RESTRICT,
    phva_stage_id       INTEGER NOT NULL REFERENCES phva_stages(id) ON DELETE RESTRICT,
    document_status_id  INTEGER NOT NULL REFERENCES document_statuses(id) ON DELETE RESTRICT,
    assigned_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by          INTEGER REFERENCES persons(id) ON DELETE SET NULL,
    CONSTRAINT uq_tenanttemplates_tenant_template UNIQUE (tenant_id, template_id)
);

-- Instancia documental generada
CREATE TABLE tenant_documents (
    id                  SERIAL PRIMARY KEY,
    tenanttemplate_id   INTEGER NOT NULL REFERENCES tenanttemplates(id) ON DELETE CASCADE,
    document_name       VARCHAR(200) NOT NULL,
    document_status_id  INTEGER NOT NULL REFERENCES document_statuses(id) ON DELETE RESTRICT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- =========================================================================
-- 10. EVALUACIONES (instrumentos asociados a una plantilla asignada)
-- =========================================================================

CREATE TABLE evaluations (
    id                  SERIAL PRIMARY KEY,
    tenanttemplate_id   INTEGER NOT NULL REFERENCES tenanttemplates(id) ON DELETE CASCADE,
    name                VARCHAR(200) NOT NULL,
    description         TEXT,
    score               NUMERIC(5,2),
    evaluated_at        TIMESTAMPTZ,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_evaluations_score CHECK (score IS NULL OR (score >= 0 AND score <= 100))
);

-- =========================================================================
-- 11. CONTROL DE EDICIÓN CONCURRENTE (bloqueos)
-- =========================================================================

CREATE TABLE editing_locks (
    id           SERIAL PRIMARY KEY,
    table_name   VARCHAR(100) NOT NULL,   -- tabla del recurso bloqueado
    record_id    INTEGER NOT NULL,        -- id del registro bloqueado
    locked_by    INTEGER NOT NULL REFERENCES persons(id) ON DELETE CASCADE,
    locked_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at   TIMESTAMPTZ NOT NULL,
    is_active    BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_editing_locks_resource UNIQUE (table_name, record_id, is_active) DEFERRABLE INITIALLY IMMEDIATE
);

-- =========================================================================
-- 12. AUDITORÍA (para los triggers que se implementen después)
-- =========================================================================

CREATE TABLE audit_log (
    id          SERIAL PRIMARY KEY,
    tenant_id   INTEGER NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    action      VARCHAR(20) NOT NULL,     -- INSERT, UPDATE, DELETE
    old_data    JSONB,
    new_data    JSONB,
    changed_by  VARCHAR(100) DEFAULT CURRENT_USER,
    changed_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);


-- =========================================================================
-- ÍNDICES DE APOYO (los específicos de rendimiento se definen en 03_indexes.sql)
-- =========================================================================

CREATE INDEX idx_persons_tenant_id          ON persons(tenant_id);
CREATE INDEX idx_tenant_modules_tenant_id   ON tenant_modules(tenant_id);
CREATE INDEX idx_tenanttemplates_tenant_id  ON tenanttemplates(tenant_id);
CREATE INDEX idx_tenanttemplates_status     ON tenanttemplates(document_status_id);
