# Guía de Instalación e Inicio Rápido
## Instrucciones de Despliegue para la Base de Datos Multi-Tenant SST/PESV en PostgreSQL

* **Autor:** Diego Mantilla
* **Repositorio:** https://github.com/DMntill4/examPostgreSQL.git
* **Motor Objetivo:** PostgreSQL 16+ mediante Docker Compose

---

## 1. Requisitos Previos

Antes de comenzar, asegúrate de tener instaladas las siguientes herramientas en tu sistema operativo:

* **Git:** Cliente de control de versiones ([git-scm.com](https://git-scm.com/))
* **Docker Desktop:** Motor de contenedores ([docker.com](https://www.docker.com/))
* **Docker Compose:** Versión 2.0+ (Incluido con Docker Desktop)

---

## 2. Paso 1: Clonar el Repositorio

Abre tu terminal (PowerShell, CMD o Bash) y clona el repositorio:

```bash
git clone https://github.com/DMntill4/examPostgreSQL.git
cd examPostgreSQL
```

---

## 3. Paso 2: Desplegar el Entorno Contenedorizado

Ejecuta el siguiente comando para iniciar el servidor de PostgreSQL 16 y pgAdmin 4 en segundo plano:

```bash
docker compose up -d
```

### Inicialización Automática de la Base de Datos
Cuando el contenedor arranca por primera vez, Docker ejecuta automáticamente los scripts SQL ubicados en `sql/` en orden alfabético:
1. `sql/01_schema.sql`: Crea el esquema `sst`, las 20 tablas normalizadas (3FN), llaves foráneas y restricciones de integridad.
2. `sql/02_seed_data.sql`: Puebla la base de datos con información inicial de catálogos, empresas, personal, módulos y documentos.

---

## 4. Paso 3: Conexión y Verificación

### Opción A: Consola de Comandos (`psql` vía Docker)
Para abrir una consola interactiva de PostgreSQL dentro del contenedor:

```bash
docker exec -it sst_pesv_pg psql -U sst_admin -d sst_pesv_db
```

Una vez adentro de `psql`, establece el esquema activo y lista las 20 tablas:

```sql
SET search_path TO sst, public;
\dt
```

Para probar la consulta de datos de empresas registradas:

```sql
SELECT * FROM sst.tenants;
```

---

### Opción B: Interfaz Gráfica Web mediante pgAdmin 4

1. Abre tu navegador e ingresa a: **[http://localhost:8080](http://localhost:8080)**
2. Inicia sesión con las credenciales por defecto:
   * **Correo:** `admin@admin.com`
   * **Contraseña:** `admin`
3. Haz clic en **Add New Server** y configura los parámetros de conexión:
   * **Name:** `SST Database`
   * **Host:** `db` (o `localhost` / `127.0.0.1` si te conectas fuera de la red docker)
   * **Port:** `5432`
   * **Maintenance Database:** `sst_pesv_db`
   * **Username:** `sst_admin`
   * **Password:** `sst_admin_pass`
4. Despliega `Databases` $\rightarrow$ `sst_pesv_db` $\rightarrow$ `Schemas` $\rightarrow$ `sst`. Haz clic derecho sobre `sst` y selecciona **Generate ERD** para ver el diagrama ER generado.

---

### Opción C: Clientes Gráficos Externos (DBeaver / DataGrip / VS Code)

Conecta cualquier cliente de base de datos usando el puerto expuesto en localhost:

* **Host:** `localhost` (o `127.0.0.1`)
* **Puerto:** `5432`
* **Base de datos:** `sst_pesv_db`
* **Usuario:** `sst_admin`
* **Contraseña:** `sst_admin_pass`

---

## 5. Paso 4: Reinicio y Mantenimiento del Entorno

Si modificas los scripts del esquema y necesitas reconstruir la base de datos desde cero:

```bash
# Detener contenedores y eliminar el volumen de datos
docker compose down -v

# Volver a desplegar los contenedores con inicialización limpia
docker compose up -d
```

### Inspección de Logs
Para revisar los logs de inicio del servidor PostgreSQL:

```bash
docker logs sst_pesv_pg --tail 50
```
