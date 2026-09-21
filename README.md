# Gestión Multi-Tenant de SST y PESV en PostgreSQL

[![PostgreSQL 16](https://img.shields.io/badge/PostgreSQL-16.0-336791?style=for-the-badge&logo=postgresql&logoColor=white)](https://www.postgresql.org/)
[![Docker](https://img.shields.io/badge/Docker-24.0+-2496ED?style=for-the-badge&logo=docker&logoColor=white)](https://www.docker.com/)
[![Docker Compose](https://img.shields.io/badge/Docker--Compose-v2+-2496ED?style=for-the-badge&logo=docker&logoColor=white)](https://docs.docker.com/compose/)
[![PL/pgSQL](https://img.shields.io/badge/PL/pgSQL-Procedural-4169E1?style=for-the-badge&logo=postgresql&logoColor=white)](https://www.postgresql.org/docs/current/plpgsql.html)
[![pgAdmin 4](https://img.shields.io/badge/pgAdmin-4-336791?style=for-the-badge&logo=postgresql&logoColor=white)](https://www.pgadmin.org/)

Base de datos relacional orientada a soportar una plataforma **multi-tenant** para la administración de la **Seguridad y Salud en el Trabajo (SST)** y el **Plan Estratégico de Seguridad Vial (PESV)**.

---

## 📌 Índice Principal del Repositorio

### 📚 Documentación Técnica (`docs/`)
* 🚀 **[Guía de Instalación y Despliegue](./docs/installation.md)** — Instrucciones paso a paso para levantar el entorno en Docker Compose (`PostgreSQL 16` + `pgAdmin 4`).
* 🏛️ **[Visión General del Sistema](./docs/systemOverview.md)** — Arquitectura del sistema multi-tenant, entidades clave y requerimientos.
* 📐 **[Normalización (1FN, 2FN, 3FN) y ERD](./docs/normalizationAndERD.md)** — Justificación paso a paso del proceso de normalización y estructura relacional.
* 📋 **[Especificación Académica del Proyecto](./docs/projectSpec.md)** — Planteamiento del problema, objetivos generales y específicos.
* 📖 **[Manual Didáctico del Dominio SST/PESV](./docs/guide.md)** — Guía de dominio sobre el ciclo PHVA y gestión documental por organización.

---

### 🗄️ Esquema Físico y Datos (`sql/`)
* 🛠️ **[DDL del Esquema Físico (20 Tablas)](./sql/01_schema.sql)** — Script de creación de tablas, llaves primarias/foráneas y restricciones `CHECK`.
* 🧪 **[Datos de Carga Inicial y Semillas](./sql/02_seed_data.sql)** — Script de inserción de catálogos y datos de prueba por empresa.

---

### 🔍 Módulos de Consultas y Programación en BD (`queries/`)
* 🟢 **[15 Consultas Básicas](./queries/basicQueries.sql)** — Selección, filtrado `WHERE`, ordenamiento y operadores `LIKE`/`IN`/`BETWEEN`.
* 🟡 **[20 Consultas Intermedias](./queries/intermediateQueries.sql)** — Múltiples `JOIN`s, agrupamientos `GROUP BY`, agregaciones y filtros `HAVING`.
* 🔴 **[25 Consultas Avanzadas](./queries/advancedQueries.sql)** — Window Functions (`DENSE_RANK`, `PARTITION BY`), CTEs y Pivots.
* 👁️ **[8 Vistas y Vistas Materializadas](./queries/viewsAndMviews.sql)** — Tableros consolidados, refresco `CONCURRENTLY` e índices únicos.
* ⚙️ **[15 Procedimientos Almacenados](./queries/storedProcedures.sql)** — Lógica transaccional en `PL/pgSQL`, validaciones preventivas y parámetros `OUT`.
* 🧩 **[8 Funciones PL/pgSQL](./queries/functions.sql)** — Funciones escalares y tabulares para cálculo de indicadores.
* ⚡ **[15 Triggers Automatizados](./queries/triggers.sql)** — Control de concurrencia (`editing_locks`) y auditoría automática (`audit_log`).

---

## 🗺️ Diagramas del Modelo de Datos

* 📊 **[Diagrama Entidad-Relación Completo (20 Tablas)](./img/dbdiagram_er_20_tables.png)**
* 📐 **[Diagrama Relacional de Arquitectura](./img/diagramE-R.png)**
