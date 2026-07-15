import os
from urllib.parse import quote_plus

SECRET_KEY = os.environ["SUPERSET_SECRET_KEY"]

metadata_user = quote_plus(os.getenv("SUPERSET_METADATA_USER", "superset"))
metadata_password = quote_plus(os.environ["SUPERSET_METADATA_PASSWORD"])
metadata_database = quote_plus(os.getenv("SUPERSET_METADATA_DATABASE", "superset"))
SQLALCHEMY_DATABASE_URI = (
    f"postgresql+psycopg2://{metadata_user}:{metadata_password}"
    f"@superset-db:5432/{metadata_database}"
)

WTF_CSRF_ENABLED = True
TALISMAN_ENABLED = False
ENABLE_PROXY_FIX = True
ROW_LIMIT = 10000
SQL_MAX_ROW = 100000
SUPERSET_WEBSERVER_TIMEOUT = 120

CACHE_CONFIG = {
    "CACHE_TYPE": "SimpleCache",
    "CACHE_DEFAULT_TIMEOUT": 300,
}
DATA_CACHE_CONFIG = CACHE_CONFIG
FILTER_STATE_CACHE_CONFIG = CACHE_CONFIG
EXPLORE_FORM_DATA_CACHE_CONFIG = CACHE_CONFIG

FEATURE_FLAGS = {
    "ENABLE_TEMPLATE_PROCESSING": True,
}
