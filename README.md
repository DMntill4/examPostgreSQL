# Gestión Multi-Tenant de SST y PESV en PostgreSQL

[![PostgreSQL 16](https://img.shields.io/badge/PostgreSQL-16.0-336791?style=for-the-badge&logo=postgresql&logoColor=white)](https://www.postgresql.org/)
[![Docker](https://img.shields.io/badge/Docker-24.0+-2496ED?style=for-the-badge&logo=docker&logoColor=white)](https://www.docker.com/)
[![Docker Compose](https://img.shields.io/badge/Docker--Compose-v2+-2496ED?style=for-the-badge&logo=docker&logoColor=white)](https://docs.docker.com/compose/)
[![PL/pgSQL](https://img.shields.io/badge/PL/pgSQL-Procedural-4169E1?style=for-the-badge&logo=postgresql&logoColor=white)](https://www.postgresql.org/docs/current/plpgsql.html)
[![pgAdmin 4](https://img.shields.io/badge/pgAdmin-4-336791?style=for-the-badge&logo=postgresql&logoColor=white)](https://www.pgadmin.org/)

Base de datos relacional para la administración estructurada, trazable e independiente (**multi-tenant**) de la **Seguridad y Salud en el Trabajo (SST)** y el **Plan Estratégico de Seguridad Vial (PESV)** de múltiples organizaciones.

---

## 🛠️ Stack Tecnológico

* **Motor de Base de Datos:** PostgreSQL 16
* **Programación en BD:** PL/pgSQL (Procedimientos, Funciones, Triggers)
* **Contenerización:** Docker & Docker Compose
* **Administración Visual:** pgAdmin 4
* **Diseño y Diagramación:** DrawSQL & dbdiagram.io

---

## 🚀 Guía Rápida de Despliegue y Ejecución

### 1. Iniciar los Contenedores
Ejecuta el siguiente comando en la raíz del proyecto para levantar PostgreSQL 16 y pgAdmin 4:

```bash
docker compose up -d
```

### 2. Conectarse vía CLI (`psql`)
Accede directamente al contenedor de PostgreSQL:

```bash
docker exec -it sst_pesv_pg psql -U sst_admin -d sst_pesv_db
```

### 3. Cargar Esquema y Semilla (si es necesario)
Los scripts iniciales se ejecutan automáticamente al levantar el contenedor, pero se pueden ejecutar manualmente con:

```bash
# Cargar DDL de Tablas y Restricciones
docker exec -i sst_pesv_pg psql -U sst_admin -d sst_pesv_db -f /docker-entrypoint-initdb.d/01_schema.sql

# Cargar Datos de Prueba
docker exec -i sst_pesv_pg psql -U sst_admin -d sst_pesv_db -f /docker-entrypoint-initdb.d/02_seed_data.sql
```

### 4. Acceso Web a pgAdmin 4
* **URL:** `http://localhost:8080`
* **Usuario:** `admin@admin.com`
* **Contraseña:** `admin`

---

## 📌 Índice General del Repositorio

### 🗄️ 1. Esquema Físico y Datos (`sql/`)
* [`sql/01_schema.sql`](./sql/01_schema.sql): Script DDL completo de creación del esquema `sst` con 20 tablas normalizadas en 3FN, claves primarias, foráneas e integridad referencial.
* [`sql/02_seed_data.sql`](./sql/02_seed_data.sql): Carga de catálogos base y semillas de prueba para entornos multi-empresa.

### 🔍 2. Consultas y Lógica Programable (`queries/`)
* [`queries/basicQueries.sql`](./queries/basicQueries.sql): **15 Consultas Básicas** — Filtrado, ordenamiento, comparaciones e `IN`/`BETWEEN`.
* [`queries/intermediateQueries.sql`](./queries/intermediateQueries.sql): **20 Consultas Intermedias** — Agregaciones, `JOIN`s múltiples, agrupamientos `GROUP BY` y filtros `HAVING`.
* [`queries/advancedQueries.sql`](./queries/advancedQueries.sql): **25 Consultas Avanzadas** — Window Functions (`DENSE_RANK`, `PARTITION BY`), CTEs, Subconsultas correlacionadas y Pivots.
* [`queries/viewsAndMviews.sql`](./queries/viewsAndMviews.sql): **8 Vistas y Vistas Materializadas** — Tableros consolidados, refresco `CONCURRENTLY` e Índices Únicos.
* [`queries/storedProcedures.sql`](./queries/storedProcedures.sql): **15 Procedimientos Almacenados** — Transacciones, parámetros `OUT`, validaciones lógicas e inserciones seguras.
* [`queries/functions.sql`](./queries/functions.sql): **8 Funciones PL/pgSQL** — Funciones escalares y tabulares de cálculo de cumplimiento.
* [`queries/triggers.sql`](./queries/triggers.sql): **15 Triggers Automatizados** — Auditoría paso a paso (`audit_log`) y control de bloqueos de edición (`editing_locks`).

### 📚 3. Centro de Documentación Técnica (`docs/`)
* [`docs/systemOverview.md`](./docs/systemOverview.md): Visión general de la arquitectura del sistema y diccionario de entidades.
* [`docs/normalizationAndERD.md`](./docs/normalizationAndERD.md): Proceso de normalización a **3FN**, análisis de dependencias funcionales y diseño relacional.
* [`docs/projectSpec.md`](./docs/projectSpec.md): Especificación académica, problemática planteada y objetivos del proyecto.
* [`docs/guide.md`](./docs/guide.md): Manual didáctico sobre el ciclo PHVA y la arquitectura multi-tenant.
* [`docs/installation.md`](./docs/installation.md): Guía paso a paso de instalación y solución de problemas con Docker.

---

## 🗺️ Diagramas de Entidad-Relación

### Diagrama Entidad-Relación (20 Tablas)
![Diagrama Entidad-Relación 20 Tablas](./img/dbdiagram_er_20_tables.png)

### Diagrama Relacional en DrawSQL
![Diagrama Entidad-Relación DrawSQL](./img/diagramE-R.png)
