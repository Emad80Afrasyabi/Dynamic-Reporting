# Sepahtan Reporting

This development stack runs Trino as a federated SQL layer and Apache Superset as the report and dashboard builder.

## Services

| Service | URL | Purpose |
|---|---|---|
| Trino | `http://localhost:8800` | Federated Trino SQL query engine |
| Superset | `http://localhost:8888` | SQL Lab, datasets, charts, dashboards |
| Superset metadata PostgreSQL | Internal only | Stores Superset users, datasets, and dashboards |

Superset uses port `8888` because the main Sepahtan stack uses `8088` for ksqlDB.

## Data sources

Trino exposes these catalogs:

- `postgresql`: `DeviceManagementDb`, including `dm."device"` and `dm."driver"`. Application tables are in the `dm` schema.
- `elasticsearch`: Elasticsearch daily event indices such as `event-20260711` and `event-20260712`.

Credentials are stored only in the ignored `.env` file. Copy `.env.example` when creating another environment.

## Start

From the `reporting` directory:

```powershell
docker compose up -d --build
```

Check status:

```powershell
docker compose ps
docker compose logs -f trino
docker compose logs -f superset-init
docker compose logs -f superset
```

Stop the services without deleting dashboards:

```powershell
docker compose down
```

Delete services and all reporting metadata:

```powershell
docker compose down -v
```

The last command permanently removes Superset users, datasets, charts, and dashboards.

## Sign in

Open `http://localhost:8888` and use `SUPERSET_ADMIN_USERNAME` and `SUPERSET_ADMIN_PASSWORD` from `.env`.

Initialization automatically registers:

- `PostgreSQL via Trino`
- `Elasticsearch via Trino`

Both connections are exposed in SQL Lab and configured without DML, CTAS, or CVAS permissions.

## Verify Trino

Open the Trino CLI in the running container:

```powershell
docker compose exec trino trino
```

Then run:

```sql
SHOW CATALOGS;
SHOW SCHEMAS FROM postgresql;
SHOW TABLES FROM postgresql.dm;
SELECT * FROM postgresql.dm.device LIMIT 10;
SHOW TABLES FROM elasticsearch.default LIKE 'event-%';
SELECT "_id", "_source" FROM elasticsearch.default."event-*" LIMIT 10;
```

More examples are in `examples/queries.sql`.

## Daily Elasticsearch indices

The Trino Elasticsearch connector supports wildcard table names. Querying the following table automatically includes current and future matching daily indices:

```sql
SELECT *
FROM elasticsearch.default."event-*"
LIMIT 100;
```

Use a specific index when a report targets one day:

```sql
SELECT *
FROM elasticsearch.default."event-20260712"
LIMIT 100;
```

An Elasticsearch alias is optional. Wildcard tables already provide a dynamic all-days query, while an alias can provide a stable business name and tighter index control.

All indices selected by a wildcard should use compatible mappings. Conflicting field types between days can make a wildcard query fail. Use an Elasticsearch index template to keep event mappings consistent.

The connector supports Elasticsearch 7.x and 8.x. Arrays require Trino metadata in the Elasticsearch mapping, non-default date formats may not be exposed, and unsupported complex fields can be annotated as raw JSON. The hidden `_source` column is useful when validating mappings.

## Build a PostgreSQL report

1. Open **SQL > SQL Lab**.
2. Select `PostgreSQL via Trino` and schema `dm`.
3. Run:

```sql
SELECT
    "DeviceStatus",
    count(*) AS device_count
FROM device
WHERE NOT "Deleted"
GROUP BY "DeviceStatus"
ORDER BY device_count DESC
```

4. Select **Save > Save dataset**.
5. Open the dataset in Explore and create a bar chart using `DeviceStatus` as the dimension and `device_count` as the metric.

**Note**: Trino lowercases unquoted identifiers. PostgreSQL table and column names are lowercase in the `dm` schema, so no quoting is needed for most tables. Use double quotes only if an identifier contains uppercase characters or special characters.
6. Save the chart into a dashboard.

## Build a dynamic event report

1. In SQL Lab, select `Elasticsearch via Trino` and schema `default`.
2. Start with the complete event document so the available fields can be inspected:

```sql
SELECT "_id", "_source"
FROM "event-*"
LIMIT 100
```

3. Run `DESCRIBE elasticsearch.default."event-20260712"` to identify mapped columns.
4. Replace `_source` with the mapped dimensions and measures needed by the report.
5. Save the query as a virtual dataset and build charts from it.

Because the virtual dataset references `"event-*"`, newly created daily event indices are included automatically.

## Federated PostgreSQL and Elasticsearch query

Trino can join the two catalogs in one statement. The event mapping was not supplied, so replace `<event_device_field>` with the actual mapped Elasticsearch field:

```sql
SELECT
    d."Id",
    d."DeployId",
    e.deviceid,
    e.gpsinfo.latitude,
    e.gpsinfo.longitude
FROM postgresql.dm.device d
JOIN elasticsearch.default."event-*" e
    ON cast(d."Id" as varchar) = e.deviceid
WHERE NOT d."Deleted"
LIMIT 100
```

Apply restrictive filters to both sources before federated joins. Trino may need to transfer rows from both systems and perform the join itself when connector pushdown is unavailable.

## Add another data source

Create a new properties file under `trino/etc/catalog`. The filename becomes the Trino catalog name. Restart Trino after adding or changing a catalog:

```powershell
docker compose restart trino
```

Register the catalog in Superset with a URI shaped like:

```text
trino://superset@trino:8080/<catalog>/<schema>
```

## Important development limitations

- Trino and Superset are served over plain HTTP.
- Trino has no authentication or access-control policy in this development setup.
- The current source credentials have broad access. Create dedicated read-only PostgreSQL and Elasticsearch accounts before production.
- `SimpleCache` is process-local. Use Redis when adding multiple Superset web workers, asynchronous SQL Lab, alerts, or scheduled reports.
- The single Trino process is both coordinator and worker. Production requires sizing, multiple workers, TLS, authentication, authorization, monitoring, and backups.
- Rotate the supplied source credentials if they were exposed outside an approved secure channel.

## Troubleshooting

### A catalog is missing

```powershell
docker compose logs trino
```

Look for invalid connector properties, authentication failures, or network timeouts.

### PostgreSQL mixed-case names fail

PostgreSQL identifiers such as `"Device"` and `"LastActivityTime"` are case-sensitive. Keep double quotes around them. The catalog also enables Trino's case-insensitive name matching for easier discovery.

### Elasticsearch connects but tables fail

Confirm that the account can call cluster metadata, mappings, search, and scroll APIs. Also confirm that Elasticsearch publishes an address reachable from Docker. `elasticsearch.ignore-publish-address=true` is enabled for the provided mapped endpoint.

### Superset initialization fails

```powershell
docker compose logs superset-init
docker compose run --rm superset-init
```

The initializer is idempotent: it upgrades metadata, ensures the admin exists, initializes roles, and upserts both Trino connections.
