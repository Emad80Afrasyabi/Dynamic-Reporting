ARG SUPERSET_VERSION=6.0.0
FROM apache/superset:${SUPERSET_VERSION}

USER root

RUN . /app/.venv/bin/activate && \
    uv pip install --no-cache \
      "psycopg2-binary==2.9.10" \
      "trino[sqlalchemy]==0.337.0"

COPY superset_config.py /app/pythonpath/superset_config.py
COPY bootstrap.py /app/bootstrap.py
COPY superset-init.sh /app/superset-init.sh
RUN chmod +x /app/superset-init.sh

USER superset

CMD ["/app/docker/entrypoints/run-server.sh"]
