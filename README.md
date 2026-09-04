# NYC Taxi Economics

Data engineering + analytics + ML project on NYC TLC yellow and green taxi
trips, full calendar year 2025 (~42M trips). Looking at what drives fares,
tipping, and demand across the taxi market, and how yellow and green compare.

## Architecture

Raw parquet files get loaded into Postgres, transformed with dbt, and
orchestrated with Airflow. Everything runs in Docker.

```
TaxiData/ (parquet)
   -> etl/load_raw.py
   -> Postgres raw schema (raw.yellow_trips, raw.green_trips)
   -> dbt staging (rename/cast, 1:1 with source)
   -> dbt intermediate (union yellow+green, add QC flags)
   -> dbt marts (fact_trips, dim_zone, dim_date, aggregates, dq tables)
   -> Tableau / notebooks / ML
```

## Repo layout

```
TaxiData/                    raw parquet, gitignored
docker-compose.yml           warehouse Postgres + Airflow
docker/                      Airflow image + requirements
dags/taxi_pipeline.py        monthly DAG: load raw -> dbt seed/run/test
etl/
  extract.py                 file discovery
  load_raw.py                parquet -> raw.* via COPY, idempotent per file
  db.py                      connection helper
  sql/raw/                   raw table DDL
dbt/
  profiles.yml
  taxi_analytics/
    models/staging/
    models/intermediate/
    models/marts/
    analyses/                 hand-written analytical SQL
    seeds/taxi_zone_lookup.csv
notebooks/
report/
dashboard/
ml/
  tip_prediction/
  fare_prediction/
  demand_forecast/
```

## Data cleaning

Cleaning happens in one place, not scattered across queries.

`int_trips_unioned` computes QC flags per trip (valid fare, valid distance,
valid passenger count, valid duration, known zone) but doesn't drop
anything, so the flagged data is still inspectable.

`fact_trips` is the actual gate: it only keeps rows where all the checks
pass. Everything downstream (aggregates, analyses, dashboard, ML) reads from
fact_trips, so it's working with clean data without having to filter itself.

Rejected rows aren't thrown away either:
- `rejected_trips` - excluded rows plus which check(s) they failed
- `dq_summary` - rejection rate by taxi type / month
- `dq_rejection_reasons` - counts by reason

TLC data has the usual issues: negative fares, zero-distance trips with a
fare attached, trip durations that don't make sense, unknown zone codes.

## Setup

1. Make sure Docker Desktop is running.
2. `cp .env.example .env` and fill in real passwords.
3. `docker compose up -d --build`
   Builds the Airflow image (dbt included), starts both Postgres instances,
   runs migrations + creates the admin user, starts webserver (localhost:8080)
   and scheduler.
4. One-time: install the dbt package deps.
   ```
   docker compose exec airflow-scheduler bash -c "cd dbt/taxi_analytics && dbt deps --profiles-dir /opt/airflow/dbt"
   ```
5. Backfill the year, via the Airflow UI or:
   ```
   docker compose exec airflow-scheduler airflow dags backfill taxi_pipeline -s 2025-01-01 -e 2025-12-01
   ```
6. Local env for notebooks/ML:
   ```
   python -m venv .venv && source .venv/bin/activate
   pip install -r requirements.txt
   ```
