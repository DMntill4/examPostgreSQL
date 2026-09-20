# Normalización de la Base de Datos, Definición de Claves Foráneas y Explicación del Diagrama Entidad-Relación

## 1. El Proceso de Normalización Paso a Paso (1FN, 2FN, 3FN)

La normalización es el proceso sistemático de descomponer tablas complejas para **eliminar la redundancia de datos** y **prevenir anomalías** de inserción, actualización y borrado. En este proyecto se aplicaron estrictamente las tres primeras formas normales sobre las 20 tablas.

---

### 1.1 Primera Forma Normal (1FN): Atomicidad y Eliminación de Grupos Repetitivos

**Regla:** Todos los campos deben ser atómicos (indivisibles), no deben existir listas separadas por comas ni grupos de columnas repetidas, y cada fila debe tener una clave primaria única (`PRIMARY KEY`).

#### Problema en un diseño NO normalizado:
Imagina guardar los datos en una sola tabla desnormalizada:
`empresa_unnormalized (id, nombre, ciudad_pais, persona_nombre_completo, modulos_habilitados)`
- `persona_nombre_completo` contiene "Laura Gómez" (dos datos en uno).
- `modulos_habilitados` contiene "Política SST, Matriz IPEVR, Diagnóstico Vial" (una lista separada por comas).

#### Solución en 1FN:
1. **Atomicidad de nombres:** Se dividió la información personal en atributos indivisibles: `first_name` ("Laura") y `last_name` ("Gómez").
2. **Eliminación de listas:** La columna `modulos_habilitados` se eliminó. Cada relación entre una empresa y un módulo pasa a ser una fila única e independiente en una tabla dedicada (`tenant_modules`).
3. **Claves Primarias:** Se asignó una clave primaria autoincremental `id SERIAL PRIMARY KEY` a cada una de las 20 tablas.

---

### 1.2 Segunda Forma Normal (2FN): Eliminación de Dependencias Parciales

**Regla:** La tabla debe estar en 1FN y todos los atributos que no son clave primaria deben depender de la **TOTALIDAD** de la clave primaria (aplica especialmente a relaciones Muchos a Muchos $N:M$).

#### Problema antes de la 2FN:
Si guardáramos el título y la descripción del módulo dentro de la tabla de asignaciones de la empresa:
`tenant_modules_incorrecto (tenant_id, module_id, modulo_titulo, modulo_descripcion, fecha_asignacion)`
- La clave primaria compuesta sería `(tenant_id, module_id)`.
- El atributo `modulo_titulo` depende únicamente de `module_id`, NO de `tenant_id`. Esto es una **dependencia parcial**. Si cambiamos la descripción de un módulo, habría que actualizar cientos de filas repetidas.

#### Solución en 2FN:
Se dividió la estructura en tres tablas con responsabilidades separadas:
1. **Catálogo General:** `modules (id, title, description, type_system_sst_id)` $\rightarrow$ Los datos del módulo dependen únicamente de `id`.
2. **Entidad Cliente:** `tenants (id, name, tax_id, ...)` $\rightarrow$ Los datos de la empresa dependen únicamente de `id`.
3. **Tabla Puente Intermedia:** `tenant_modules (id, tenant_id, module_id, assigned_at)` $\rightarrow$ Solo guarda la relación y el atributo propio de la asignación (`assigned_at`).

---

### 1.3 Tercera Forma Normal (3FN): Eliminación de Dependencias Transitivas

**Regla:** La tabla debe estar en 2FN y ningún atributo no clave debe depender de otro atributo no clave (no deben existir dependencias transitivas $A \rightarrow B \rightarrow C$).

#### Caso de Estudio Principal: La Jerarquía Geográfica
Si en la tabla `tenants` guardáramos directamente la ciudad, el departamento y el país:
`tenants (id, name, tax_id, ciudad_nombre, departamento_nombre, pais_nombre)`
- `id` (Tenant) $\rightarrow$ `ciudad_nombre` $\rightarrow$ `departamento_nombre` $\rightarrow$ `pais_nombre`.
- `departamento_nombre` no depende del Tenant `id`, depende de la `ciudad_nombre`. Si la empresa cambia de ciudad o se renombrara un departamento, se generarían inconsistencias masivas.

#### Solución en 3FN:
Se creó la jerarquía relacional desacoplada de 3 niveles:

$$\text{countries (id, name, iso\_code)} \longrightarrow \text{regions (id, country\_id, name)} \longrightarrow \text{cities (id, region\_id, name)}$$

La tabla `tenants` guarda exclusivamente la llave foránea `city_id INTEGER REFERENCES cities(id)`. A través de los `JOINs` navegamos hacia el departamento y el país sin duplicar texto.

---

## 2. Definición y Estrategia de Claves Foráneas (Foreign Keys)

Las claves foráneas (`FOREIGN KEY`) conectan las tablas y garantizan la **integridad referencial**. Para evitar registros huérfanos o bloqueos indebidos, se aplicaron tres políticas de borrado (`ON DELETE`):

```text
┌─────────────────────────────────────────────────────────────────────────────────┐
│ ESTRATEGIA DE RESTRICCIONES DE CLAVES FORÁNEAS (FOREIGN KEYS)                  │
├───────────────────────────────────┬─────────────────────────────────────────────┤
│ Política de Borrado               │ Aplica a Tablas                             │
├───────────────────────────────────┼─────────────────────────────────────────────┤
│ ON DELETE RESTRICT (Protección)   │ Catálogos (countries, regions, cities,      │
│                                   │ tenant_sizes, type_system_sst, modules,     │
│                                   │ phva_stages, document_statuses)             │
├───────────────────────────────────┼─────────────────────────────────────────────┤
│ ON DELETE CASCADE (Cascada)       │ Entidades Hijas por Tenant (positions,      │
│                                   │ persons, tenantsystems, tenant_modules,     │
│                                   │ tenanttemplates, tenant_documents,          │
│                                   │ evaluations)                                │
├───────────────────────────────────┼─────────────────────────────────────────────┤
│ ON DELETE SET NULL (Opcional)     │ Relaciones no obligatorias (position_id     │
│                                   │ en persons, format_id en templates)         │
└───────────────────────────────────┴─────────────────────────────────────────────┘
```

### 1. `ON DELETE RESTRICT` (Protección Estricta)
- **¿Qué hace?** Impide eliminar un registro padre si existen registros hijos apuntando a él.
- **¿Por qué se usó?** Si intentas borrar el país "Colombia" de `countries`, PostgreSQL arrojará un error porque hay departamentos en `regions` que lo usan. Protege los catálogos maestras.

### 2. `ON DELETE CASCADE` (Borrado en Cascada)
- **¿Qué hace?** Si se elimina el registro padre, elimina automáticamente todos los registros hijos asociados.
- **¿Por qué se usó?** Si una empresa (`tenant`) se da de baja y se elimina de `tenants`, se borran automáticamente en cascada sus cargos (`positions`), sus trabajadores (`persons`), sus módulos habilitados (`tenant_modules`) y sus documentos (`tenanttemplates`), evitando datos huérfanos e inservibles.

### 3. `ON DELETE SET NULL` (Desvinculación Opcional)
- **¿Qué hace?** Si se elimina el registro padre, el campo foráneo en el registro hijo se convierte en `NULL`.
- **¿Por qué se usó?** Si se borra un cargo en `positions`, el trabajador en `persons` **NO se borra** (el trabajador sigue existiendo en la empresa), simplemente su `position_id` pasa a ser `NULL` hasta que se le asigne un nuevo cargo.

---

## 3. Explicación del Diagrama Entidad-Relación (`img/`)

En la carpeta `img/` se encuentran dos representaciones gráficas del modelo:
- `img/dbdiagram_er_20_tables.png`: Diagrama técnico completo de las 20 tablas renderizado desde dbdiagram.io.
- `img/diagramE-R.png`: Diagrama relacional interactivo de DrawSQL.

### Estructura del Diagrama en 6 Bloques Funcionales:

```text
[1. Geografía]         [2. Organización]       [3. Catálogo & Suscripción]
 countries              tenant_sizes            type_system_sst
    │                      │                       │         │
    ▼                      ▼                       ▼         ▼
 regions  ───────────>  tenants  ───────────> tenantsystems  modules
    │                      │                       │         │
    ▼                      ├──> positions          │         ▼
  cities ──────────────────┤                       │     tenant_modules
                           └──> persons ───────────┼─────────┤
                                   │               │         │
                                   ▼               ▼         ▼
                         [6. Concurrencia]   [4. Documentación PHVA]
                           editing_locks        phva_stages ─> templates
                           audit_log            document_statuses ─> tenanttemplates
                                                                      │
                                                                      ▼
                                                                tenant_documents
                                                                      │
                                                                      ▼
                                                              [5. Evaluación]
                                                                evaluations
```

### Cómo Leer las Relaciones en el Diagrama:

1. **Jerarquía Geográfica (Izquierda):**
   `countries` $(1) \longrightarrow (N)$ `regions` $(1) \longrightarrow (N)$ `cities` $(1) \longrightarrow (N)$ `tenants`.
   Una ciudad contiene muchas empresas; una empresa pertenece a una sola ciudad.

2. **Núcleo de Empresa y Empleados (Centro):**
   `tenant_sizes` $(1) \longrightarrow (N)$ `tenants` $(1) \longrightarrow (N)$ `persons`.
   `tenants` $(1) \longrightarrow (N)$ `positions` $(1) \longrightarrow (N)$ `persons`.
   Una empresa define sus propios cargos y enrola a sus propios trabajadores.

3. **Suscripciones y Módulos N:M (Derecha Superior):**
   Relación Muchos a Muchos entre `tenants` y `modules` resuelta mediante la tabla puente `tenant_modules`.
   Relación Muchos a Muchos entre `tenants` y `type_system_sst` resuelta mediante la tabla puente `tenantsystems`.

4. **Ciclo PHVA y Plantillas (Derecha Inferior):**
   `templates` combina el `module_id`, `format_id` y `phva_stage_id`.
   Cuando el Tenant adopta una plantilla, se crea una fila en `tenanttemplates` conectando el `tenant_id`, `template_id`, `phva_stage_id` y `document_status_id`.
   `tenanttemplates` $(1) \longrightarrow (N)$ `tenant_documents`.

5. **Evaluación y Seguridad (Fondo):**
   Cada `tenanttemplate` recibe calificaciones en `evaluations`.
   `editing_locks` bloquea recursos por `person_id`.
   `audit_log` captura cambios globales por `tenant_id` en formato `JSONB`.
