-- Raw layer: mirrors the TLC source schema as closely as possible.
-- No cleaning/typing decisions here — that belongs in dbt staging models.
-- _source_file / _loaded_at give us load lineage and let re-runs be idempotent per file.

CREATE SCHEMA IF NOT EXISTS raw;

CREATE TABLE IF NOT EXISTS raw.yellow_trips (
    vendor_id               INTEGER,
    tpep_pickup_datetime    TIMESTAMP,
    tpep_dropoff_datetime   TIMESTAMP,
    passenger_count         DOUBLE PRECISION,
    trip_distance           DOUBLE PRECISION,
    rate_code_id            DOUBLE PRECISION,
    store_and_fwd_flag      TEXT,
    pu_location_id          INTEGER,
    do_location_id          INTEGER,
    payment_type            BIGINT,
    fare_amount              DOUBLE PRECISION,
    extra                    DOUBLE PRECISION,
    mta_tax                  DOUBLE PRECISION,
    tip_amount                DOUBLE PRECISION,
    tolls_amount               DOUBLE PRECISION,
    improvement_surcharge      DOUBLE PRECISION,
    total_amount                DOUBLE PRECISION,
    congestion_surcharge         DOUBLE PRECISION,
    airport_fee                   DOUBLE PRECISION,
    cbd_congestion_fee             DOUBLE PRECISION,
    _source_file             TEXT NOT NULL,
    _loaded_at                TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS raw.green_trips (
    vendor_id               INTEGER,
    lpep_pickup_datetime    TIMESTAMP,
    lpep_dropoff_datetime   TIMESTAMP,
    store_and_fwd_flag      TEXT,
    rate_code_id            DOUBLE PRECISION,
    pu_location_id          INTEGER,
    do_location_id          INTEGER,
    passenger_count         DOUBLE PRECISION,
    trip_distance           DOUBLE PRECISION,
    fare_amount              DOUBLE PRECISION,
    extra                    DOUBLE PRECISION,
    mta_tax                  DOUBLE PRECISION,
    tip_amount                DOUBLE PRECISION,
    tolls_amount               DOUBLE PRECISION,
    ehail_fee                   DOUBLE PRECISION,
    improvement_surcharge        DOUBLE PRECISION,
    total_amount                  DOUBLE PRECISION,
    payment_type                   DOUBLE PRECISION,
    trip_type                       DOUBLE PRECISION,
    congestion_surcharge             DOUBLE PRECISION,
    cbd_congestion_fee                 DOUBLE PRECISION,
    _source_file             TEXT NOT NULL,
    _loaded_at                TIMESTAMP NOT NULL DEFAULT now()
);

-- Idempotent re-runs: one load per source file. If a DAG task retries or a
-- month is backfilled, wipe that file's rows first instead of appending duplicates.
CREATE INDEX IF NOT EXISTS ix_yellow_trips_source_file ON raw.yellow_trips (_source_file);
CREATE INDEX IF NOT EXISTS ix_green_trips_source_file ON raw.green_trips (_source_file);
