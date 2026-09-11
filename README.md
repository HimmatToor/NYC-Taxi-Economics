# NYC Taxi Economics

Data engineering + Analytics + ML project on NYC TLC yellow and green taxi
trips, full calendar year 2025 (~35M cleaned trips). Looking at what drives
fares, tipping, and demand across the taxi market, and how yellow and green
compare.

## What's built

- **[dbt/taxi_analytics/](dbt/taxi_analytics/)** - staging to intermediate to marts
  transformation layer, tested and documented. `fact_trips` is the cleaning
  gate (only rows that pass QC get in); `rejected_trips`, `dq_summary`, and
  `dq_rejection_reasons` are the audit trail for what got excluded and why.
  [analyses/](dbt/taxi_analytics/analyses/) has four hand-written analytical
  SQL queries (window functions, month-over-month growth, z-score anomaly
  detection).
- **[dags/taxi_pipeline.py](dags/taxi_pipeline.py)** - monthly Airflow DAG
  that loads raw parquet and runs the dbt transformations. Backfilled the
  full 2025 calendar year, ~35.3M trips end to end.
- **[notebooks/taxi_economics_analysis.ipynb](notebooks/taxi_economics_analysis.ipynb)**
  - the main analysis: data cleaning summary, market structure, demand
  patterns, fare trends, and tipping behavior. Standout finding: tipping
  collapses outside Manhattan (26% average tip vs. 0.9% in the Bronx, driven
  by a 97% $0-tip rate on card payments there). Written up in
  [report/findings.md](report/findings.md).
- **[ml/](ml/)** - three models built on top of the analysis, each with a
  time-based train/test split (train Jan-Oct, test Nov-Dec):
  - [tip_prediction/](ml/tip_prediction/tip_prediction.ipynb) - R²=0.32;
    confirms pickup borough is the strongest predictor of tip %.
  - [fare_prediction/](ml/fare_prediction/fare_prediction.ipynb) - R²=0.93,
    MAE=$1.18; independently recovers the airport-flat-rate effect from
    location features alone, and doubles as a fare-anomaly detector.
  - [demand_forecast/](ml/demand_forecast/demand_forecast.ipynb) - beats a
    naive same-day-last-week baseline by 42% (MAPE 10.1% vs. 17.4%).

  Results summarized in [report/ml_model_results.md](report/ml_model_results.md).
- **[dashboard/nyc_taxi_economics.twbx](dashboard/nyc_taxi_economics.twbx)** -
  Tableau dashboard covering the same KPIs interactively (market structure,
  demand heatmap, fare trends, tipping by borough, data quality). PDF export
  at [dashboard/nyc_dashboard.pdf](dashboard/nyc_dashboard.pdf) for a quick
  look without opening Tableau.

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
  taxi_economics_analysis.ipynb
report/
  findings.md                 written analysis findings
  ml_model_results.md         ML model results summary
dashboard/
  nyc_taxi_economics.twbx     Tableau packaged workbook
  nyc_dashboard.pdf           static export
ml/
  tip_prediction/tip_prediction.ipynb
  fare_prediction/fare_prediction.ipynb
  demand_forecast/demand_forecast.ipynb
```

## Data cleaning

Cleaning happens in one place, not scattered across queries.

`int_trips_unioned` computes QC flags per trip (valid fare, valid distance,
valid passenger count, valid duration, known zone, valid pickup year) but
doesn't drop anything, so the flagged data is still inspectable.

`fact_trips` is the actual gate: it only keeps rows where all the checks
pass. Everything downstream (aggregates, analyses, dashboard, ML) reads from
fact_trips, so it's working with clean data without having to filter itself.

Rejected rows aren't thrown away either:
- `rejected_trips` - excluded rows plus which check(s) they failed
- `dq_summary` - rejection rate by taxi type / month
- `dq_rejection_reasons` - counts by reason

TLC data has the usual issues: negative fares, zero-distance trips with a
fare attached, trip durations that don't make sense, unknown zone codes, and
a handful of corrupted meter-clock timestamps.

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
