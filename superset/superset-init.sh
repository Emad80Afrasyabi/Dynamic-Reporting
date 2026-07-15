#!/bin/sh
set -eu

superset db upgrade
superset fab create-admin \
  --username "${SUPERSET_ADMIN_USERNAME}" \
  --firstname Reporting \
  --lastname Admin \
  --email "${SUPERSET_ADMIN_EMAIL}" \
  --password "${SUPERSET_ADMIN_PASSWORD}" || true
superset init
superset shell < /app/bootstrap.py
