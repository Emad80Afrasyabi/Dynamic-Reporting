from superset import db
from superset.models.core import Database

connections = {
    "PostgreSQL via Trino": "trino://superset@trino:8080/postgresql/dm",
    "Elasticsearch via Trino": "trino://superset@trino:8080/elasticsearch/default",
}

for database_name, sqlalchemy_uri in connections.items():
    database = (
        db.session.query(Database)
        .filter(Database.database_name == database_name)
        .one_or_none()
    )
    if database is None:
        database = Database(database_name=database_name)
    database.set_sqlalchemy_uri(sqlalchemy_uri)
    database.expose_in_sqllab = True
    database.allow_dml = False
    database.allow_ctas = False
    database.allow_cvas = False
    db.session.add(database)

db.session.commit()
