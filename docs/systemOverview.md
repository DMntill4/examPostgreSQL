# Visión General del Sistema: Gestión Multi-Tenant SST y PESV

## 1. Introducción y Contexto de Negocio

El **Sistema de Gestión Multi-Tenant SST y PESV** es una solución de software empresarial concebida para centralizar, automatizar y auditar el cumplimiento de dos marcos normativos críticos en Colombia:

1. **Seguridad y Salud en el Trabajo (SST):** Conjunto de políticas, matrices de identificación de peligros, evaluaciones de riesgo y programas de capacitación orientados a mitigar accidentes y enfermedades laborales.
2. **Plan Estratégico de Seguridad Vial (PESV):** Conjunto de acciones y mecanismos de prevención exigidos a organizaciones con flotas de vehículos o personal asignado a labores de transporte.

### 1.1 El Problema de Negocio
Tradicionalmente, las organizaciones gestionan sus evidencias documentales mediante archivos físicos o hojas de cálculo dispersas. Esta práctica genera inconsistencias, pérdida de trazabilidad, vencimiento no detectado de inspecciones y elevadas sanciones económicas por parte de los entes reguladores.

La plataforma resuelve esta problemática al ofrecer un entorno digital unificado en la nube donde múltiples empresas pueden suscribirse, estructurar sus equipos de trabajo, habilitar módulos normativos, instanciar plantillas estándar y someter su avance a procesos de evaluación continua.

---

## 2. Arquitectura de Datos Multi-Tenant

Para ofrecer una solución eficiente desde el punto de vista operativo y computacional, la plataforma implementa una **arquitectura de base de datos compartida con aislamiento lógico por discriminador**.

```text
                                  ┌─────────────────────────┐
                                  │ PostgreSQL (sst_pesv_db)│
                                  └────────────┬────────────┘
                                               │
                                  ┌────────────┴────────────┐
                                  │   Esquema Lógico 'sst'  │
                                  └────────────┬────────────┘
                                               │
        ┌──────────────────────────────────────┼──────────────────────────────────────┐
        │                                      │                                      │
 ┌──────┴────────┐                    ┌────────┴────────┐                    ┌────────┴────────┐
 │ Tenant 1 (NIT)│                    │ Tenant 2 (NIT) │                    │ Tenant 3 (NIT) │
 ├────────────────┤                    ├────────────────┤                    ├────────────────┤
 │ - Personas     │                    │ - Personas     │                    │ - Personas     │
 │ - Cargos       │                    │ - Cargos       │                    │ - Cargos       │
 │ - Módulos      │                    │ - Módulos      │                    │ - Módulos      │
 │ - Plantillas   │                    │ - Plantillas   │                    │ - Plantillas   │
 └────────────────┘                    └────────────────┘                    └────────────────┘
```

### Principios Fundamentales de Aislamiento:
* **Columna Discriminadora (`tenant_id`):** Presente en todas las entidades operativas y transaccionales del modelo.
* **Hermeticidad Lógica:** Toda consulta DML ejecuta un filtro restrictivo sobre `tenant_id`, garantizando que ninguna organización pueda consultar, modificar o interferir con los registros de otra entidad.

---

## 3. Desglose Estructural del Modelo Relacional (20 Tablas)

El modelo de datos se organiza en 6 capas funcionales interconectadas mediante llaves primarias autoincrementales (`SERIAL`) y restricciones de integridad referencial (`FOREIGN KEY`).

```text
┌─────────────────────────────────────────────────────────────────────────────────┐
│ 1. CAPA GEOGRÁFICA Y NORMAS REGIONALES                                           │
│    countries ──> regions ──> cities                                             │
├─────────────────────────────────────────────────────────────────────────────────┤
│ 2. CAPA ORGANIZACIONAL (ENTIDADES Y PERSONAL)                                   │
│    tenant_sizes, tenants, positions, persons                                    │
├─────────────────────────────────────────────────────────────────────────────────┤
│ 3. CAPA DE CATÁLOGOS Y SUSCRIPCIONES                                            │
│    type_system_sst, tenantsystems, modules, tenant_modules                      │
├─────────────────────────────────────────────────────────────────────────────────┤
│ 4. CAPA DOCUMENTAL Y CICLO PHVA                                                 │
│    phva_stages, formats_sst, templates, document_statuses, tenanttemplates,    │
│    tenant_documents                                                             │
├─────────────────────────────────────────────────────────────────────────────────┤
│ 5. CAPA DE EVALUACIÓN Y SEGUIMIENTO                                             │
│    evaluations                                                                  │
├─────────────────────────────────────────────────────────────────────────────────┤
│ 6. CAPA DE CONCURRENCIA Y AUDITORÍA                                             │
│    editing_locks, audit_log                                                     │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 3.1 Capa Geográfica (Normalización 3FN)
* **`countries`**: Registro de países de operación.
* **`regions`**: Departamentos o provincias asociadas a un país.
* **`cities`**: Municipios vinculados a un departamento. Determina la ubicación de los tenants.

### 3.2 Capa Organizacional
* **`tenant_sizes`**: Clasificación por tamaño empresarial (Micro, Pequeña, Mediana, Grande), fundamental para determinar el nivel de exigencia normativa.
* **`tenants`**: Entidad central que representa a cada empresa cliente registrada en el sistema.
* **`positions`**: Catálogo de cargos laborales definidos de manera independiente por cada empresa.
* **`persons`**: Registro de empleados y personal asociado a cada tenant.

### 3.3 Capa de Catálogos y Suscripciones
* **`type_system_sst`**: Tipología de los sistemas de gestión soportados (SST, PESV).
* **`tenantsystems`**: Matriz de suscripción activa de sistemas por empresa.
* **`modules`**: Catálogo general de módulos funcionales (ej. Matriz IPEVR, Inspección de Vehículos).
* **`tenant_modules`**: Asignación efectiva de módulos contratados por cada empresa.

### 3.4 Capa Documental y Ciclo PHVA
* **`phva_stages`**: Las cuatro fases del ciclo de mejora continua Deming (Planear, Hacer, Verificar, Actuar).
* **`formats_sst`**: Tipología de formatos estándar del sistema.
* **`templates`**: Plantillas maestras provistas por la plataforma.
* **`document_statuses`**: Catálogo de estados de avance documental (`NO_INICIADO`, `BORRADOR`, `PENDIENTE`, `FINALIZADO`).
* **`tenanttemplates`**: Instanciación de plantillas adoptadas por una empresa específica.
* **`tenant_documents`**: Archivos y documentos finales generados en la operación diaria.

### 3.5 Capa de Evaluación
* **`evaluations`**: Registro de valoraciones cuantitativas (puntuación de 0.00 a 100.00) aplicadas al avance de las plantillas y documentos de cada tenant.

### 3.6 Capa de Seguridad y Auditoría
* **`editing_locks`**: Mecanismo de bloqueo pesimista que evita la edición concurrente simulada de un mismo recurso por múltiples usuarios.
* **`audit_log`**: Registro histórico de cambios estructurales (`INSERT`, `UPDATE`, `DELETE`) en formato semiestructurado `JSONB`.

---

## 4. Dinámica del Flujo de Información

1. **Afiliación:** La empresa se registra en `tenants` asociando su ubicación (`city_id`) y escala (`tenant_size_id`).
2. **Estructuración:** La empresa define sus `positions` y vincula a sus colaboradores en `persons`.
3. **Suscripción:** Se habilitan los sistemas en `tenantsystems` y los componentes en `tenant_modules`.
4. **Adopción Documental:** La empresa vincula plantillas base en `tenanttemplates`, clasificándolas según la fase en `phva_stages`.
5. **Edición Segura:** Se bloquea temporalmente el recurso mediante `editing_locks` mientras se actualiza el estado en `tenant_documents`.
6. **Valoración y Trazabilidad:** Se registra la calificación en `evaluations` y se almacena la traza de auditoría en `audit_log`.
