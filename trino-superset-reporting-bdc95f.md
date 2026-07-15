# Trino + Apache Superset Dynamic Report Builder

Set up Trino and Apache Superset via Docker Compose to query PostgreSQL (`DeviceManagementDb`) and Elasticsearch (`event-*` daily indices) through a single SQL interface, using Superset's native UI for building reports and dashboards.

## Context

- **Deployment**: Docker Compose (dev mode, no auth)
- **Data sources**:
  - PostgreSQL: `10.10.10.208:30432`, database `DeviceManagementDb`, user `postgres` / password `ygbgXWmVOu`
  - Elasticsearch: `10.10.10.206:31201`, user `elastic` / password `00ABftjB8t92Wr2VyRnM3473`
  - ES indices: daily pattern `event-YYYYMMDD` (e.g. `event-20260711`, `event-20260712`)
- **Query language**: Trino SQL (native, no T-SQL translation)
- **UI**: Superset native UI (chart builder, dashboards, SQL Lab)
- **Location**: New `reporting/` directory in the Sepahtan repo
- **Sample tables**: `Driver`, `Device` (PostgreSQL); `event-*` indices (Elasticsearch)

## Architecture

```
Superset (port 8088)
    │  SQLAlchemy (trino://)
    ▼
Trino Coordinator (port 8800)
    │  Connectors
    ├──► PostgreSQL (10.10.10.208:30432 / DeviceManagementDb)
    └──► Elasticsearch (10.10.10.206:31201 / event-* indices)
```

## Steps

### Step 1: Create directory structure

```
reporting/
├── docker-compose.yml          # Trino + Superset services
├── trino/
│   └── etc/
│       ├── config.properties   # Trino coordinator config
│       ├── jvm.config          # JVM settings
│       └── catalog/
│           ├── postgresql.properties   # PostgreSQL connector
│           └── elasticsearch.properties # Elasticsearch connector
├── superset/
│   ├── superset-init.sh        # Init script (create admin, init DB)
│   └── superset_config.py      # Superset configuration
└── README.md                   # Setup and usage guide
```

### Step 2: Trino Docker Compose service

- Image: `trinodb/trino:latest`
- Port: `8080` (avoid conflict with Kafka-UI on 8080 — use `8800:8080`)
- Mount `trino/etc/` as `/etc/trino/`
- No auth, single-node (coordinator + worker in one process)
- JVM heap: 2GB (configurable)

### Step 3: Trino catalog configs

**PostgreSQL** (`postgresql.properties`):
```properties
connector.name=postgresql
connection-url=jdbc:postgresql://10.10.10.208:30432/DeviceManagementDb
connection-user=postgres
connection-password=ygbgXWmVOu
```
- Exposes all schemas/tables in `DeviceManagementDb` via the `postgresql` catalog
- Key tables: `Driver`, `Device`, `Company`, `Representation`, `CommonBaseValue`, `Vehicle`

**Elasticsearch** (`elasticsearch.properties`):
```properties
connector.name=elasticsearch
elasticsearch.host=10.10.10.206
elasticsearch.port=31201
elasticsearch.default-schema-name=default
elasticsearch.security=true
elasticsearch.username=elastic
elasticsearch.password=00ABftjB8t92Wr2VyRnM3473
elasticsearch.index-pattern=event-*
```
- Exposes `event-*` daily indices as tables in the `elasticsearch` catalog
- Each day's index appears as a separate table (e.g. `event-20260711`, `event-20260712`)
- **Note**: Trino ES connector discovers indices matching the pattern on startup; new daily indices require a metadata refresh (`SHOW TABLES` re-scan or Trino restart)

### Step 4: Superset Docker Compose service

- Image: `apache/superset:latest`
- Port: `8088:8088`
- Depends on Trino being healthy
- Init script creates admin user and initializes metadata DB
- Custom `superset_config.py` with:
  - Trino database connection string
  - SQL Lab enabled
  - Chart factory defaults

### Step 5: Superset → Trino connection

- Register two databases in Superset:
  - `PostgreSQL (via Trino)`: `trino://user@trino:8080/postgresql`
  - `Elasticsearch (via Trino)`: `trino://user@trino:8080/elasticsearch`
- Enable SQL Lab for ad-hoc querying
- Pre-register sample datasets:
  - `postgresql.public."Driver"` — driver info
  - `postgresql.public."Device"` — device info with FK to `Company`, `Representation`
  - `elasticsearch.default."event-20260712"` — sample event data
- Create a sample dashboard: Device status overview (join Device with CommonBaseValue for status names)

### Step 6: Verification & testing

1. Start services: `docker compose -f reporting/docker-compose.yml up -d`
2. Verify Trino: `curl http://localhost:8800/v1/info`
3. Test PostgreSQL query: `SELECT * FROM postgresql.public."Device" LIMIT 10`
4. Test Elasticsearch query: `SELECT * FROM elasticsearch.default."event-20260712" LIMIT 10`
5. Test federated join: Join `Device` table with `event-*` index on device ID
6. Access Superset at `http://localhost:8088`, create sample chart from `Device` dataset

### Step 7: Documentation (README.md)

- How to start/stop services
- How to add new data sources (new Trino catalogs)
- How to create datasets and charts in Superset
- Trino SQL quick reference (common patterns vs T-SQL)
- Federated query examples
- Troubleshooting guide

## Daily Index Strategy

Elasticsearch indices follow a daily pattern `event-YYYYMMDD`. Considerations:

- **Short-term**: Each daily index appears as a separate Trino table. Query specific days directly.
- **Medium-term**: Create a Trino **view** that unions recent days:
  ```sql
  CREATE VIEW elasticsearch.default.events_recent AS
  SELECT * FROM elasticsearch.default."event-20260711"
  UNION ALL
  SELECT * FROM elasticsearch.default."event-20260712";
  ```
- **Long-term**: Create an Elasticsearch **alias** (`events-all`) pointing to all daily indices. Trino sees it as a single table. This is the recommended approach for production.

## Out of Scope (for now)

- Authentication/security (dev mode)
- Kubernetes deployment
- T-SQL translation layer
- Custom Superset plugins or embedded UI
- Kafka connector (can add later)
