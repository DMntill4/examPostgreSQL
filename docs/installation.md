# Installation and Quick Start Guide
## Deployment Instructions for PostgreSQL SST/PESV Multi-Tenant Database

* **Author:** Diego Mantilla
* **Repository:** https://github.com/DMntill4/examPostgreSQL.git
* **Target Engine:** PostgreSQL 16+ via Docker Compose

---

## 1. Prerequisites

Before starting, ensure you have the following tools installed on your operating system:

* **Git:** Version control client ([git-scm.com](https://git-scm.com/))
* **Docker Desktop:** Container engine ([docker.com](https://www.docker.com/))
* **Docker Compose:** Version 2.0+ (Included with Docker Desktop)

---

## 2. Step 1: Clone the Repository

Open your terminal (PowerShell, Command Prompt, or Bash) and clone the repository:

```bash
git clone https://github.com/DMntill4/examPostgreSQL.git
cd examPostgreSQL
```

---

## 3. Step 2: Deploy Containerized Environment

Run the following command to start both the PostgreSQL 16 server and pgAdmin 4 in detached mode:

```bash
docker compose up -d
```

### Automatic Database Initialization
When the container boots for the first time, Docker automatically executes the SQL scripts located in `sql/` in alphabetical order:
1. `sql/01_schema.sql`: Creates the `sst` schema, 20 normalized tables (3FN), foreign keys, and integrity constraints.
2. `sql/02_seed_data.sql`: Populates the database with initial catalog, tenant, employee, module, and document seed data.

---

## 4. Step 3: Connect and Verify Database

### Option A: Command Line Interface (`psql` via Docker)
To open an interactive PostgreSQL shell inside the container:

```bash
docker exec -it sst_pesv_pg psql -U sst_admin -d sst_pesv_db
```

Once inside `psql`, set the active schema and list all 20 tables:

```sql
SET search_path TO sst, public;
\dt
```

To test querying initialized tenant data:

```sql
SELECT * FROM sst.tenants;
```

---

### Option B: Graphical User Interface via pgAdmin 4 Web

1. Open your browser and navigate to: **[http://localhost:8080](http://localhost:8080)**
2. Log in with default credentials:
   * **Email:** `admin@admin.com`
   * **Password:** `admin`
3. Click **Add New Server** and configure connection parameters:
   * **Name:** `SST Database`
   * **Host:** `db` (or `localhost` / `127.0.0.1` if connecting outside docker network)
   * **Port:** `5432`
   * **Maintenance Database:** `sst_pesv_db`
   * **Username:** `sst_admin`
   * **Password:** `sst_admin_pass`
4. Expand `Databases` $\rightarrow$ `sst_pesv_db` $\rightarrow$ `Schemas` $\rightarrow$ `sst`. Right-click `sst` and select **Generate ERD** to view the auto-generated ER Diagram.

---

### Option C: External SQL GUI Clients (DBeaver / DataGrip / VS Code)

Connect any desktop database client using the exposed localhost port:

* **Host:** `localhost` (or `127.0.0.1`)
* **Port:** `5432`
* **Database:** `sst_pesv_db`
* **Username:** `sst_admin`
* **Password:** `sst_admin_pass`

---

## 5. Step 4: Environment Reset and Troubleshooting

If you modify schema scripts and need to rebuild the database from scratch:

```bash
# Stop containers and wipe the data volume
docker compose down -v

# Re-deploy containers with clean initialization
docker compose up -d
```

### Checking Container Logs
To inspect PostgreSQL startup logs:

```bash
docker logs sst_pesv_pg --tail 50
```
