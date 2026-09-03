"""
Monthly taxi data pipeline: raw parquet -> Postgres raw layer -> dbt staging/marts.

Scheduled monthly for calendar year 2025 with catchup=True, so the full year
is populated via Airflow's own backfill mechanism:

    airflow dags backfill taxi_pipeline -s 2025-01-01 -e 2025-12-31

Each run's data_interval_start maps to the YYYY-MM file for that month.
"""

from datetime import datetime

from airflow import DAG
from airflow.operators.bash import BashOperator

DBT_PROJECT_DIR = "/opt/airflow/dbt/taxi_analytics"
DBT_PROFILES_DIR = "/opt/airflow/dbt"

default_args = {
    "owner": "analytics",
    "retries": 2,
}

with DAG(
    dag_id="taxi_pipeline",
    description="Load yellow/green TLC trips into Postgres and run dbt transformations",
    default_args=default_args,
    schedule_interval="@monthly",
    start_date=datetime(2025, 1, 1),
    end_date=datetime(2025, 12, 31),
    catchup=True,
    max_active_runs=1,
    tags=["taxi", "elt"],
) as dag:

    load_yellow = BashOperator(
        task_id="load_yellow_raw",
        bash_command=(
            "cd /opt/airflow && python -m etl.load_raw "
            "--taxi-type yellow --month {{ data_interval_start.strftime('%Y-%m') }}"
        ),
    )

    load_green = BashOperator(
        task_id="load_green_raw",
        bash_command=(
            "cd /opt/airflow && python -m etl.load_raw "
            "--taxi-type green --month {{ data_interval_start.strftime('%Y-%m') }}"
        ),
    )

    dbt_seed = BashOperator(
        task_id="dbt_seed",
        bash_command=f"cd {DBT_PROJECT_DIR} && dbt seed --profiles-dir {DBT_PROFILES_DIR}",
    )

    dbt_run = BashOperator(
        task_id="dbt_run",
        bash_command=f"cd {DBT_PROJECT_DIR} && dbt run --profiles-dir {DBT_PROFILES_DIR}",
    )

    dbt_test = BashOperator(
        task_id="dbt_test",
        bash_command=f"cd {DBT_PROJECT_DIR} && dbt test --profiles-dir {DBT_PROFILES_DIR}",
    )

    [load_yellow, load_green] >> dbt_seed >> dbt_run >> dbt_test
