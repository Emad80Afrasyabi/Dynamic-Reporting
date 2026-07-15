SHOW CATALOGS;

SHOW SCHEMAS FROM postgresql;
SHOW TABLES FROM postgresql.dm;
DESCRIBE postgresql.dm.device;
DESCRIBE postgresql.dm.driver;

SELECT
    "Id",
    "DeployId",
    "DeviceStatus",
    "DeviceType",
    "Activated",
    "LastActivityTime"
FROM postgresql.dm.device
WHERE NOT "Deleted"
ORDER BY "LastActivityTime" DESC NULLS LAST
LIMIT 100;

SELECT
    "DeviceStatus",
    count(*) AS device_count
FROM postgresql.dm.device
WHERE NOT "Deleted"
GROUP BY "DeviceStatus"
ORDER BY device_count DESC;

SELECT
    "Activated",
    count(*) AS driver_count
FROM postgresql.dm.driver
WHERE NOT "Deleted"
GROUP BY "Activated"
ORDER BY "Activated";

SHOW SCHEMAS FROM elasticsearch;
SHOW TABLES FROM elasticsearch.default LIKE 'event-%';
DESCRIBE elasticsearch.default."event-20260715";

SELECT
    deviceid,
    devicestatus,
    gpsinfo.latitude,
    gpsinfo.longitude,
    gpstrackinginfo.speed,
    messagedatetimestamp.seconds
FROM elasticsearch.default."event-20260715"
LIMIT 100;

SELECT deviceid, gpsinfo.latitude, gpsinfo.longitude
FROM elasticsearch.default."event-*"
LIMIT 100;

SELECT eventtype, count(*) AS cnt
FROM elasticsearch.default."event-20260715"
GROUP BY eventtype
ORDER BY cnt DESC
LIMIT 10;

-- Federated join: PostgreSQL devices with Elasticsearch events
SELECT
    d."Id",
    d."DeployId",
    e.deviceid,
    e.gpsinfo.latitude,
    e.gpsinfo.longitude
FROM postgresql.dm.device d
JOIN elasticsearch.default."event-20260715" e
    ON cast(d."Id" as varchar) = e.deviceid
WHERE NOT d."Deleted"
LIMIT 100;
