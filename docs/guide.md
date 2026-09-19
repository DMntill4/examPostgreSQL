# Database Architecture & Implementation Guide
## Sistema de Gestión Multi-Tenant SST y PESV en PostgreSQL

* **Estudiante:** Diego Mantilla
---

## 1. Análisis de Requerimientos y Arquitectura Multi-Tenant

El sistema está diseñado para soportar una plataforma de software en la nube donde múltiples organizaciones cliente (denominadas **tenants**) gestionan sus procesos de **Seguridad y Salud en el Trabajo (SST)** y el **Plan Estratégico de Seguridad Vial (PESV)**.

### 1.1 Modelo de Aislamiento Lógico Multi-Tenant
Para garantizar la privacidad y seguridad de la información sin multiplicar el costo operativo de desplegar bases de datos independientes por cada cliente, se adoptó una arquitectura de **Base de Datos Compartida con Esquema Compartido y Aislamiento Lógico**.

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
┌───────┴────────┐                    ┌────────┴────────┐                    ┌────────┴────────┐
│ Tenant 1 (NIT) │                    │ Tenant 2 (NIT) │                    │ Tenant 3 (NIT) │
├────────────────┤                    ├────────────────┤                    ├────────────────┤
│ - Personas     │                    │ - Personas     │                    │ - Personas     │
│ - Cargos       │                    │ - Cargos       │                    │ - Cargos       │
│ - Módulos      │                    │ - Módulos      │                    │ - Módulos      │
│ - Plantillas   │                    │ - Plantillas   │                    │ - Plantillas   │
└────────────────┘                    └────────────────┘                    └────────────────┘
```

* **Columna de Aislamiento (`tenant_id`):** Todas las entidades operativas y transaccionales (`persons`, `positions`, `tenantsystems`, `tenant_modules`, `tenanttemplates`, `audit_log`) incluyen la llave foránea `tenant_id`.
* **Regla de Negocio:** Ninguna consulta u operación de un tenant puede acceder a filas donde `tenant_id` pertenezca a otra organización.

---

## 2. Proceso de Normalización de la Base de Datos

El diseño físico partió de la eliminación de la redundancia y de la prevención de anomalías de inserción, modificación y borrado.

### 2.1 Primera Forma Normal (1FN)
Una relación se encuentra en 1FN cuando todos sus atributos son atómicos (indivisibles) y no existen grupos o columnas repetitivas.

#### Antes de la 1FN (Tabla Desnormalizada Especulativa):
```text
tenant_unnormalized (
    tenant_id, empresa_nombre, pais_ciudad, 
    contacto1_nombre, contacto1_email, contacto2_nombre, contacto2_email,
    modulos_habilitados -- "Política, Matriz IPEVR, Diagnóstico Vial"
)
```

#### Después de la 1FN:
1. Se dividió la información personal en campos atómicos (`first_name`, `last_name`, `email`).
2. Se eliminaron las listas separadas por comas (`modulos_habilitados`). Cada relación entre tenant y módulo pasó a ser una fila independiente en una tabla dedicada.
3. Se asignó una clave primaria atómica (`id SERIAL`) a cada entidad.

### 2.2 Segunda Forma Normal (2FN)
Una relación está en 2FN cuando cumple la 1FN y todos los atributos que no forman parte de la clave primaria dependen de la **totalidad** de la clave primaria (no existe dependencia parcial).

#### Caso de Estudio: Asignación N:M de Módulos y Sistemas
Inicialmente, guardar los atributos del módulo dentro de la asignación del tenant violaba la 2FN porque el título del módulo dependía únicamente de `module_id` y no de `tenant_id`.

#### Solución en 2FN:
Se dividió la estructura en tres tablas:
1. Catálogo General: `modules (id, type_system_sst_id, title, description, display_order)`.
2. Organización: `tenants (id, name, tax_id, ...)`.
3. Tabla Puente: `tenant_modules (id, tenant_id, module_id, assigned_at)`.

### 2.3 Tercera Forma Normal (3FN)
Una relación está en 3FN cuando cumple la 2FN y ningún atributo no clave depende transitivamente de otro atributo no clave.

#### Caso de Estudio: Jerarquía Geográfica
Almacenar `country_name`, `region_name` y `city_name` dentro de la tabla `tenants` generaba una dependencia transitiva (`city_name` $\rightarrow$ `region_name` $\rightarrow$ `country_name`). Si se modificaba el nombre de un departamento, había que actualizar cientos de filas de tenants.

#### Solución en 3FN:
Se construyó la jerarquía relacional desacoplada:
$$\text{countries (id, name, iso\_code)} \longrightarrow \text{regions (id, country\_id, name)} \longrightarrow \text{cities (id, region\_id, name)}$$

La tabla `tenants` guarda únicamente la llave foránea `city_id`.

---

## 3. Esquema Físico y Clasificación por Capas (20 Tablas)

El modelo relacional está compuesto por 20 tablas organizadas funcionalmente en 6 capas:

```text
┌─────────────────────────────────────────────────────────────────────────────────┐
│ 1. CAPA DE CATÁLOGOS E INFRAESTRUCTURA GEOGRÁFICA                               │
│    countries, regions, cities, tenant_sizes, type_system_sst, phva_stages,      │
│    document_statuses                                                            │
├─────────────────────────────────────────────────────────────────────────────────┤
│ 2. CAPA ORGANIZACIONAL (NÚCLEO MULTI-TENANT)                                    │
│    tenants, positions, persons                                                  │
├─────────────────────────────────────────────────────────────────────────────────┤
│ 3. CAPA DE CONFIGURACIÓN DE SISTEMAS Y MÓDULOS                                  │
│    tenantsystems, modules, tenant_modules, formats_sst                         │
├─────────────────────────────────────────────────────────────────────────────────┤
│ 4. CAPA DOCUMENTAL Y PLANTILLAS                                                 │
│    templates, tenanttemplates, tenant_documents                                 │
├─────────────────────────────────────────────────────────────────────────────────┤
│ 5. CAPA DE EVALUACIÓN Y SEGUIMIENTO                                             │
│    evaluations                                                                  │
├─────────────────────────────────────────────────────────────────────────────────┤
│ 6. CAPA DE SEGURIDAD, CONCURRENCIA Y AUDITORÍA                                  │
│    editing_locks, audit_log                                                     │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### Restricciones de Integridad Aplicadas:
* **`PRIMARY KEY`:** Definida en todas las tablas mediante secuencias autoincrementales (`SERIAL`).
* **`FOREIGN KEY`:** Reglas estrictas `ON DELETE RESTRICT` para catálogos y `ON DELETE CASCADE` para entidades hijas dependientes.
* **`CHECK` Constraints:**
  * Formato de correo electrónico: `email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$'`.
  * Rangos de empleados: `CHECK (max_employees IS NULL OR max_employees >= min_employees)`.
  * Puntaje de evaluación: `CHECK (score BETWEEN 0 AND 100)`.
  * Validez de bloqueos: `CHECK (expires_at > locked_at)`.
* **`UNIQUE` Constraints:**
  * `tax_id` único en `tenants`.
  * `(tenant_id, document_id)` único en `persons`.
  * `(tenant_id, module_id)` único en `tenant_modules`.

---

## 4. Comportamiento y Dinámica del Sistema de Datos

El comportamiento operativo del sistema sigue un flujo secuencial a través de las 20 tablas:

```text
[1. Registro de Tenant] ──> [2. Definición de Cargos y Personas]
         │
         ├──> [3. Habilitación de Sistemas SST / PESV y Módulos]
         │
         └──> [4. Asignación de Plantillas (tenanttemplates)]
                   │
                   ├──> [5. Edición Concurrente Protegida (editing_locks)]
                   ├──> [6. Generación de Documentos (tenant_documents)]
                   ├──> [7. Evaluación (evaluations)]
                   └──> [8. Auditoría Automática por Evento (audit_log)]
```

### 4.1 Flujo Operativo Paso a Paso:
1. **Alta de Organización:** Se crea la fila en `tenants` vinculando su ciudad (`city_id`) y tamaño (`tenant_size_id`). Un disparador de auditoría registra la acción en `audit_log`.
2. **Estructura Humana:** Se definen los cargos en `positions` especificando su `tenant_id`. Se registran las personas en `persons` vinculándolas a su respectivo cargo y tenant.
3. **Suscripción de Módulos:** Se insertan los registros en `tenantsystems` y `tenant_modules` activando los componentes funcionales habilitados para la empresa.
4. **Instanciación Documental:** La empresa adopta plantillas del catálogo (`templates`). Cada adopción crea una fila en `tenanttemplates` clasificando la etapa PHVA (`phva_stage_id`) y el estado inicial (`document_status_id = NO_INICIADO`).
5. **Control de Concurrencia:** Cuando un usuario inicia la edición de un documento, se registra una fila en `editing_locks`. Si otro usuario del mismo tenant intenta acceder mientras `expires_at > NOW()`, el sistema le niega la edición.
6. **Finalización y Evaluación:** Al completarse el documento (`tenant_documents`), su estado cambia a `FINALIZADO`. Se registra la evaluación en `evaluations` con el puntaje obtenido.

---

## 5. Despliegue y Administración con Docker y pgAdmin 4

### 5.1 Arquitectura del Contenedor
El entorno está empaquetado en dos servicios dentro de `docker-compose.yml`:
* **Servidor PostgreSQL 16 (`db`):** Puerto `5432`. Carga automáticamente `01_schema.sql` y `02_seed_data.sql` en el primer arranque.
* **Servidor pgAdmin 4 (`pgadmin`):** Puerto `8080`. Herramienta gráfica web para gestión y visualización de diagramas ER.

### 5.2 Comandos de Gestión:

```powershell
# Levantar el entorno en segundo plano
docker compose up -d

# Reiniciar datos desde cero (limpia el volumen)
docker compose down -v
docker compose up -d

# Conectarse a la consola interactiva psql
docker exec -it sst_pesv_pg psql -U sst_admin -d sst_pesv_db
```

### 5.3 Conexión desde pgAdmin 4:
* URL: `http://localhost:8080`
* Usuario: `admin@admin.com` | Clave: `admin`
* Parámetros de servidor: Host `db`, Puerto `5432`, DB `sst_pesv_db`, Usuario `sst_admin`, Clave `sst_admin_pass`.

---

## 6. Diccionario de Datos Completo (20 Tablas)

### 6.1 `countries`
Catálogo de países.

| Columna | Tipo de Dato | Restricciones | Nulable | Descripción |
| :--- | :--- | :--- | :--- | :--- |
| `id` | `SERIAL` | `PRIMARY KEY` | No | ID único del país. |
| `name` | `VARCHAR(100)` | `UNIQUE` | No | Nombre del país. |
| `iso_code` | `VARCHAR(3)` | `UNIQUE` | No | Código ISO de 3 letras. |

### 6.2 `regions`
Departamentos o regiones geográficas.

| Columna | Tipo de Dato | Restricciones | Nulable | Descripción |
| :--- | :--- | :--- | :--- | :--- |
| `id` | `SERIAL` | `PRIMARY KEY` | No | ID único de la región. |
| `country_id` | `INTEGER` | `FOREIGN KEY (countries.id)` | No | País al que pertenece. |
| `name` | `VARCHAR(100)` | - | No | Nombre del departamento. |

### 6.3 `cities`
Municipios o ciudades.

| Columna | Tipo de Dato | Restricciones | Nulable | Descripción |
| :--- | :--- | :--- | :--- | :--- |
| `id` | `SERIAL` | `PRIMARY KEY` | No | ID único del municipio. |
| `region_id` | `INTEGER` | `FOREIGN KEY (regions.id)` | No | Región a la que pertenece. |
| `name` | `VARCHAR(100)` | - | No | Nombre del municipio. |

### 6.4 `tenant_sizes`
Clasificación de empresas por número de trabajadores.

| Columna | Tipo de Dato | Restricciones | Nulable | Descripción |
| :--- | :--- | :--- | :--- | :--- |
| `id` | `SERIAL` | `PRIMARY KEY` | No | ID del tamaño empresarial. |
| `name` | `VARCHAR(50)` | `UNIQUE` | No | Nombre (Micro, Pequeña, etc.). |
| `min_employees`| `INTEGER` | `CHECK (>= 0)` | No | Mínimo de empleados. |
| `max_employees`| `INTEGER` | - | Sí | Máximo de empleados. |

### 6.5 `tenants`
Entidad núcleo multi-tenant (organizaciones clientes).

| Columna | Tipo de Dato | Restricciones | Nulable | Descripción |
| :--- | :--- | :--- | :--- | :--- |
| `id` | `SERIAL` | `PRIMARY KEY` | No | ID único de la empresa. |
| `name` | `VARCHAR(150)` | - | No | Razón social. |
| `tax_id` | `VARCHAR(20)` | `UNIQUE` | No | NIT o ID fiscal. |
| `contact_email`| `VARCHAR(100)` | `CHECK (email LIKE '%@%')` | No | Correo principal. |
| `contact_phone`| `VARCHAR(20)` | - | Sí | Teléfono principal. |
| `city_id` | `INTEGER` | `FOREIGN KEY (cities.id)` | No | Ciudad de radicación. |
| `tenant_size_id`| `INTEGER` | `FOREIGN KEY (tenant_sizes.id)` | No | Clasificación por tamaño. |
| `is_active` | `BOOLEAN` | `DEFAULT TRUE` | No | Estado de activación. |
| `created_at` | `TIMESTAMP` | `DEFAULT CURRENT_TIMESTAMP` | No | Fecha de creación. |
| `updated_at` | `TIMESTAMP` | `DEFAULT CURRENT_TIMESTAMP` | No | Fecha de modificación. |

### 6.6 `positions`
Cargos laborales propios por organización.

| Columna | Tipo de Dato | Restricciones | Nulable | Descripción |
| :--- | :--- | :--- | :--- | :--- |
| `id` | `SERIAL` | `PRIMARY KEY` | No | ID del cargo. |
| `tenant_id` | `INTEGER` | `FOREIGN KEY (tenants.id)` | No | Empresa propietaria del cargo. |
| `description` | `VARCHAR(100)` | - | No | Nombre del cargo. |

### 6.7 `persons`
Usuarios y trabajadores vinculados a los tenants.

| Columna | Tipo de Dato | Restricciones | Nulable | Descripción |
| :--- | :--- | :--- | :--- | :--- |
| `id` | `SERIAL` | `PRIMARY KEY` | No | ID único de la persona. |
| `tenant_id` | `INTEGER` | `FOREIGN KEY (tenants.id)` | No | Empresa a la que pertenece. |
| `position_id` | `INTEGER` | `FOREIGN KEY (positions.id)` | Sí | Cargo asignado. |
| `document_id` | `VARCHAR(20)` | - | No | Número de cédula / documento. |
| `first_name` | `VARCHAR(80)` | - | No | Nombres. |
| `last_name` | `VARCHAR(80)` | - | No | Apellidos. |
| `email` | `VARCHAR(100)` | - | No | Correo electrónico. |
| `phone` | `VARCHAR(20)` | - | Sí | Teléfono de contacto. |
| `is_active` | `BOOLEAN` | `DEFAULT TRUE` | No | Estado activo. |
| `created_at` | `TIMESTAMP` | `DEFAULT CURRENT_TIMESTAMP` | No | Fecha de alta. |
| `updated_at` | `TIMESTAMP` | `DEFAULT CURRENT_TIMESTAMP` | No | Fecha de actualización. |

### 6.8 `type_system_sst`
Tipos de sistemas de gestión.

| Columna | Tipo de Dato | Restricciones | Nulable | Descripción |
| :--- | :--- | :--- | :--- | :--- |
| `id` | `SERIAL` | `PRIMARY KEY` | No | ID del tipo de sistema. |
| `name` | `VARCHAR(50)` | `UNIQUE` | No | Nombre (SST, PESV). |
| `description` | `TEXT` | - | Sí | Descripción general. |

### 6.9 `tenantsystems`
Sistemas SST/PESV habilitados por empresa.

| Columna | Tipo de Dato | Restricciones | Nulable | Descripción |
| :--- | :--- | :--- | :--- | :--- |
| `id` | `SERIAL` | `PRIMARY KEY` | No | ID de la suscripción. |
| `tenant_id` | `INTEGER` | `FOREIGN KEY (tenants.id)` | No | Empresa cliente. |
| `type_system_sst_id` | `INTEGER` | `FOREIGN KEY (type_system_sst.id)` | No | Sistema habilitado. |
| `is_active` | `BOOLEAN` | `DEFAULT TRUE` | No | Estado activo. |

### 6.10 `modules`
Módulos del catálogo general por sistema.

| Columna | Tipo de Dato | Restricciones | Nulable | Descripción |
| :--- | :--- | :--- | :--- | :--- |
| `id` | `SERIAL` | `PRIMARY KEY` | No | ID del módulo. |
| `type_system_sst_id` | `INTEGER` | `FOREIGN KEY (type_system_sst.id)` | No | Sistema al que pertenece. |
| `title` | `VARCHAR(120)` | - | No | Título del módulo. |
| `description` | `TEXT` | - | Sí | Descripción funcional. |
| `display_order` | `INTEGER` | `DEFAULT 1` | No | Orden de presentación. |

### 6.11 `tenant_modules`
Módulos habilitados por empresa.

| Columna | Tipo de Dato | Restricciones | Nulable | Descripción |
| :--- | :--- | :--- | :--- | :--- |
| `id` | `SERIAL` | `PRIMARY KEY` | No | ID de la asignación. |
| `tenant_id` | `INTEGER` | `FOREIGN KEY (tenants.id)` | No | Empresa cliente. |
| `module_id` | `INTEGER` | `FOREIGN KEY (modules.id)` | No | Módulo asignado. |
| `assigned_at` | `TIMESTAMP` | `DEFAULT CURRENT_TIMESTAMP` | No | Fecha de asignación. |

### 6.12 `phva_stages`
Etapas del ciclo Deming (Planear, Hacer, Verificar, Actuar).

| Columna | Tipo de Dato | Restricciones | Nulable | Descripción |
| :--- | :--- | :--- | :--- | :--- |
| `id` | `SERIAL` | `PRIMARY KEY` | No | ID de la etapa. |
| `name` | `VARCHAR(50)` | `UNIQUE` | No | Nombre de la etapa. |
| `order_num` | `INTEGER` | `UNIQUE` | No | Orden de la fase (1 a 4). |

### 6.13 `formats_sst`
Formatos base asociados a un módulo.

| Columna | Tipo de Dato | Restricciones | Nulable | Descripción |
| :--- | :--- | :--- | :--- | :--- |
| `id` | `SERIAL` | `PRIMARY KEY` | No | ID del formato. |
| `module_id` | `INTEGER` | `FOREIGN KEY (modules.id)` | No | Módulo funcional. |
| `name` | `VARCHAR(120)` | - | No | Nombre del formato. |
| `description` | `TEXT` | - | Sí | Descripción. |

### 6.14 `templates`
Plantillas documentales base.

| Columna | Tipo de Dato | Restricciones | Nulable | Descripción |
| :--- | :--- | :--- | :--- | :--- |
| `id` | `SERIAL` | `PRIMARY KEY` | No | ID de la plantilla. |
| `module_id` | `INTEGER` | `FOREIGN KEY (modules.id)` | No | Módulo asociado. |
| `format_id` | `INTEGER` | `FOREIGN KEY (formats_sst.id)` | No | Formato base. |
| `phva_stage_id`| `INTEGER` | `FOREIGN KEY (phva_stages.id)` | No | Etapa PHVA. |
| `name` | `VARCHAR(150)` | - | No | Nombre de la plantilla. |
| `description` | `TEXT` | - | Sí | Descripción preliminar. |

### 6.15 `document_statuses`
Estados de avance documental.

| Columna | Tipo de Dato | Restricciones | Nulable | Descripción |
| :--- | :--- | :--- | :--- | :--- |
| `id` | `SERIAL` | `PRIMARY KEY` | No | ID del estado. |
| `code` | `VARCHAR(30)` | `UNIQUE` | No | Código clave (`FINALIZADO`, etc.). |
| `name` | `VARCHAR(50)` | - | No | Nombre legible. |

### 6.16 `tenanttemplates`
Instancia de plantilla asignada a una empresa.

| Columna | Tipo de Dato | Restricciones | Nulable | Descripción |
| :--- | :--- | :--- | :--- | :--- |
| `id` | `SERIAL` | `PRIMARY KEY` | No | ID de la asignación. |
| `tenant_id` | `INTEGER` | `FOREIGN KEY (tenants.id)` | No | Empresa cliente. |
| `template_id` | `INTEGER` | `FOREIGN KEY (templates.id)` | No | Plantilla base. |
| `type_system_sst_id` | `INTEGER` | `FOREIGN KEY (type_system_sst.id)` | No | Sistema SST/PESV. |
| `phva_stage_id`| `INTEGER` | `FOREIGN KEY (phva_stages.id)` | No | Etapa PHVA. |
| `document_status_id` | `INTEGER` | `FOREIGN KEY (document_statuses.id)` | No | Estado actual. |
| `updated_by` | `INTEGER` | `FOREIGN KEY (persons.id)` | Sí | Usuario modificador. |
| `created_at` | `TIMESTAMP` | `DEFAULT CURRENT_TIMESTAMP` | No | Fecha de creación. |
| `updated_at` | `TIMESTAMP` | `DEFAULT CURRENT_TIMESTAMP` | No | Fecha de actualización. |

### 6.17 `tenant_documents`
Documentos generados físicamente por el tenant.

| Columna | Tipo de Dato | Restricciones | Nulable | Descripción |
| :--- | :--- | :--- | :--- | :--- |
| `id` | `SERIAL` | `PRIMARY KEY` | No | ID del documento. |
| `tenanttemplate_id` | `INTEGER` | `FOREIGN KEY (tenanttemplates.id)` | No | Plantilla del tenant. |
| `document_name` | `VARCHAR(150)` | - | No | Nombre del documento. |
| `document_status_id` | `INTEGER` | `FOREIGN KEY (document_statuses.id)` | No | Estado del documento. |
| `created_at` | `TIMESTAMP` | `DEFAULT CURRENT_TIMESTAMP` | No | Fecha de creación. |
| `updated_at` | `TIMESTAMP` | `DEFAULT CURRENT_TIMESTAMP` | No | Fecha de actualización. |

### 6.18 `evaluations`
Evaluaciones aplicadas a los documentos.

| Columna | Tipo de Dato | Restricciones | Nulable | Descripción |
| :--- | :--- | :--- | :--- | :--- |
| `id` | `SERIAL` | `PRIMARY KEY` | No | ID de la evaluación. |
| `tenanttemplate_id` | `INTEGER` | `FOREIGN KEY (tenanttemplates.id)` | No | Documento evaluado. |
| `name` | `VARCHAR(150)` | - | No | Nombre del instrumento. |
| `description` | `TEXT` | - | Sí | Observaciones. |
| `score` | `NUMERIC(5,2)` | `CHECK (score BETWEEN 0 AND 100)` | No | Nota de 0 a 100. |
| `evaluated_at`| `TIMESTAMP` | `DEFAULT CURRENT_TIMESTAMP` | No | Fecha de evaluación. |

### 6.19 `editing_locks`
Control de edición concurrente.

| Columna | Tipo de Dato | Restricciones | Nulable | Descripción |
| :--- | :--- | :--- | :--- | :--- |
| `id` | `SERIAL` | `PRIMARY KEY` | No | ID del bloqueo. |
| `resource_type`| `VARCHAR(50)` | - | No | Tipo de recurso. |
| `resource_id` | `INTEGER` | - | No | ID del registro. |
| `person_id` | `INTEGER` | `FOREIGN KEY (persons.id)` | No | Usuario bloqueador. |
| `locked_at` | `TIMESTAMP` | `DEFAULT CURRENT_TIMESTAMP` | No | Fecha inicio bloqueo. |
| `expires_at` | `TIMESTAMP` | `CHECK (expires_at > locked_at)` | No | Vencimiento del bloqueo. |
| `is_active` | `BOOLEAN` | `DEFAULT TRUE` | No | Vigencia del bloqueo. |

### 6.20 `audit_log`
Registro de auditoría automática con datos JSONB.

| Columna | Tipo de Dato | Restricciones | Nulable | Descripción |
| :--- | :--- | :--- | :--- | :--- |
| `id` | `SERIAL` | `PRIMARY KEY` | No | ID del log. |
| `tenant_id` | `INTEGER` | `FOREIGN KEY (tenants.id)` | No | Empresa auditada. |
| `action` | `VARCHAR(20)` | - | No | Operación (INSERT, UPDATE, DELETE). |
| `old_data` | `JSONB` | - | Sí | Estado previo. |
| `new_data` | `JSONB` | - | Sí | Nuevo estado. |
| `changed_by` | `VARCHAR(50)` | `DEFAULT CURRENT_USER` | No | Usuario ejecutor. |
| `changed_at` | `TIMESTAMP` | `DEFAULT CURRENT_TIMESTAMP` | No | Timestamp del cambio. |
