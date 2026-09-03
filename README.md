# NYC Taxi Economics

An end-to-end data analytics project on NYC TLC yellow and green taxi trip
data (full calendar year 2025, ~42M trips), built to demonstrate data
engineering, SQL/analytics engineering, and machine learning practices
together on one dataset.

**Question the project answers:** what drives fares, tipping behavior, and
ride demand across NYC's taxi market, and how do the two taxi types differ?

## Architecture

```
Raw parquet (TaxiData/) ──► etl/load_raw.py ──► Postgres: raw.yellow_trips, raw.green_trips
                                                          │
                                              dbt staging models (rename/cast, 1:1 with source)
                                                          │
                                              dbt intermediate model (union + data-quality flags)
                                                          │
                                              dbt marts (dim_zone, dim_date, fact_trips [incremental],
                                                          agg_daily_zone, agg_hourly_demand)
                                                          │
                        ┌─────────────────────────────────┼─────────────────────────────┐
                        ▼                                 ▼                             ▼
                Tableau dashboard              Jupyter notebooks + report      ML models (tip, fare,
                (reads marts directly)         (SQL-heavy exploratory work)     demand forecasting)
```

Orchestrated by **Airflow** (monthly-partitioned DAG, backfillable), transformed
with **dbt** (tested, documented, incremental), stored in **Postgres**, both
running in **Docker**.

## Why this stack

- **Postgres + Docker**: a real relational warehouse instead of flat files, containerized so setup is one command and reproducible from a clean checkout.
- **dbt**: industry-standard analytics engineering tool. Staging/intermediate/marts layering, schema tests (`not_null`, `unique`, `relationships`, `accepted_values`), incremental models, and a lineage graph (`dbt docs generate`) — all things a hand-rolled SQL script can't give you.
- **Airflow**: scheduled, backfillable, retry-aware orchestration rather than a script you remember to run. The DAG is monthly-partitioned so a single month can be reprocessed without touching the rest of the year.
- **dbt `analyses/`**: hand-written analytical SQL (window functions, CTEs, z-score anomaly detection) that isn't part of the warehouse build but demonstrates SQL depth directly — see [dbt/taxi_analytics/analyses/](dbt/taxi_analytics/analyses/).

## Repo layout

```
TaxiData/                    raw parquet, gitignored (yellow ~869MB, green ~14MB, 2025)
docker-compose.yml           warehouse Postgres + Airflow (LocalExecutor)
docker/                      Airflow image build + its extra requirements
dags/taxi_pipeline.py        monthly Airflow DAG: load raw -> dbt seed/run/test
etl/
  extract.py                 file discovery helpers
  load_raw.py                streams parquet -> raw.* via COPY, idempotent per source file
  db.py                      connection helper (reads .env)
  sql/raw/                   raw table DDL
dbt/
  profiles.yml                connection profile (reads env vars, no secrets committed)
  taxi_analytics/
    models/staging/           1:1 rename/cast of raw.yellow_trips, raw.green_trips
    models/intermediate/      union + data-quality flag columns
    models/marts/             dim_zone, dim_date, fact_trips, agg_daily_zone, agg_hourly_demand
    analyses/                 standalone analytical SQL (window functions, anomaly detection)
    seeds/taxi_zone_lookup.csv official TLC zone lookup
notebooks/                   exploratory analysis (depends on marts)
report/                      written findings for GitHub
dashboard/                   Tableau workbook
ml/
  tip_prediction/
  fare_prediction/
  demand_forecast/
```

## Data quality approach

Nothing is silently dropped in the pipeline. `int_trips_unioned` attaches
boolean flag columns (`is_valid_fare`, `is_valid_distance`,
`is_valid_passenger_count`, `is_valid_duration`, `is_known_zone`, rolled up
into `is_valid_trip`) instead of filtering rows out — `fact_trips` keeps every
row, and marts/analyses/ML all decide for themselves whether to filter on
`is_valid_trip`. This keeps the raw shape of the data auditable and matches
how a real warehouse handles messy source data (TLC trip data is known to
contain negative fares, zero-distance trips with nonzero fares, and
out-of-range timestamps).

## Setup

1. **Install Docker Desktop** (not yet installed on this machine): `brew install --cask docker`, then launch it once from Applications.
2. **Configure environment**: `cp .env.example .env` and fill in real passwords.
3. **Start the stack**:
   ```
   docker compose up -d --build
   ```
   This builds the Airflow image (with dbt baked in), starts both Postgres instances, runs `airflow db migrate` + creates the admin user, then starts the webserver (http://localhost:8080) and scheduler.
4. **Install the dbt package dependency** (one-time, from inside the airflow-scheduler container):
   ```
   docker compose exec airflow-scheduler bash -c "cd dbt/taxi_analytics && dbt deps --profiles-dir /opt/airflow/dbt"
   ```
5. **Backfill the year** via the Airflow UI (unpause `taxi_pipeline`) or CLI:
   ```
   docker compose exec airflow-scheduler airflow dags backfill taxi_pipeline -s 2025-01-01 -e 2025-12-01
   ```
6. **Local Python env** for notebooks/ML (outside Docker):
   ```
   python -m venv .venv && source .venv/bin/activate
   pip install -r requirements.txt
   ```
