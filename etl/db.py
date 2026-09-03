import os

import psycopg2
from dotenv import load_dotenv

load_dotenv()


def get_connection():
    return psycopg2.connect(
        host=os.environ["WAREHOUSE_DB_HOST"],
        port=os.environ.get("WAREHOUSE_DB_PORT", 5432),
        dbname=os.environ["WAREHOUSE_DB_NAME"],
        user=os.environ["WAREHOUSE_DB_USER"],
        password=os.environ["WAREHOUSE_DB_PASSWORD"],
    )


def run_sql_file(conn, path):
    with open(path) as f:
        sql = f.read()
    with conn.cursor() as cur:
        cur.execute(sql)
    conn.commit()
