"""
Load raw TLC parquet files into the `raw` schema of the warehouse Postgres DB.

Re-running for a file deletes its existing rows first (matched on
_source_file), so retries and backfills don't create duplicates.

Files are streamed in row-group batches with pyarrow instead of read fully
into memory - yellow months are ~3.5M rows / 20 columns each.

python -m etl.load_raw --taxi-type yellow --month 2025-01
python -m etl.load_raw --taxi-type yellow --all
python -m etl.load_raw --taxi-type both --all
"""

import argparse
import io
import sys

import pyarrow.parquet as pq

from etl.db import get_connection, run_sql_file
from etl.extract import list_files, month_from_filename

BATCH_SIZE = 500_000

# Explicit rather than trusting source column order, so a TLC schema change
# gets caught instead of silently misaligning columns.
YELLOW_COLUMNS = {
    "VendorID": "vendor_id",
    "tpep_pickup_datetime": "tpep_pickup_datetime",
    "tpep_dropoff_datetime": "tpep_dropoff_datetime",
    "passenger_count": "passenger_count",
    "trip_distance": "trip_distance",
    "RatecodeID": "rate_code_id",
    "store_and_fwd_flag": "store_and_fwd_flag",
    "PULocationID": "pu_location_id",
    "DOLocationID": "do_location_id",
    "payment_type": "payment_type",
    "fare_amount": "fare_amount",
    "extra": "extra",
    "mta_tax": "mta_tax",
    "tip_amount": "tip_amount",
    "tolls_amount": "tolls_amount",
    "improvement_surcharge": "improvement_surcharge",
    "total_amount": "total_amount",
    "congestion_surcharge": "congestion_surcharge",
    "Airport_fee": "airport_fee",
    "cbd_congestion_fee": "cbd_congestion_fee",
}

GREEN_COLUMNS = {
    "VendorID": "vendor_id",
    "lpep_pickup_datetime": "lpep_pickup_datetime",
    "lpep_dropoff_datetime": "lpep_dropoff_datetime",
    "store_and_fwd_flag": "store_and_fwd_flag",
    "RatecodeID": "rate_code_id",
    "PULocationID": "pu_location_id",
    "DOLocationID": "do_location_id",
    "passenger_count": "passenger_count",
    "trip_distance": "trip_distance",
    "fare_amount": "fare_amount",
    "extra": "extra",
    "mta_tax": "mta_tax",
    "tip_amount": "tip_amount",
    "tolls_amount": "tolls_amount",
    "ehail_fee": "ehail_fee",
    "improvement_surcharge": "improvement_surcharge",
    "total_amount": "total_amount",
    "payment_type": "payment_type",
    "trip_type": "trip_type",
    "congestion_surcharge": "congestion_surcharge",
    "cbd_congestion_fee": "cbd_congestion_fee",
}

TABLE_BY_TYPE = {"yellow": "raw.yellow_trips", "green": "raw.green_trips"}
COLUMNS_BY_TYPE = {"yellow": YELLOW_COLUMNS, "green": GREEN_COLUMNS}


def load_file(conn, taxi_type: str, file_path) -> int:
    table = TABLE_BY_TYPE[taxi_type]
    source_columns = COLUMNS_BY_TYPE[taxi_type]
    target_columns = list(source_columns.values()) + ["_source_file"]
    source_file = file_path.name

    parquet_file = pq.ParquetFile(file_path)
    available = set(parquet_file.schema_arrow.names)
    missing = set(source_columns) - available
    if missing:
        raise ValueError(
            f"{source_file}: missing expected columns {missing}, "
            "TLC schema may have changed, update the column map"
        )

    with conn.cursor() as cur:
        cur.execute(f"DELETE FROM {table} WHERE _source_file = %s", (source_file,))

    total_rows = 0
    copy_sql = (
        f"COPY {table} ({', '.join(target_columns)}) "
        "FROM STDIN WITH (FORMAT csv, NULL '')"
    )
    for batch in parquet_file.iter_batches(
        batch_size=BATCH_SIZE, columns=list(source_columns)
    ):
        df = batch.to_pandas().rename(columns=source_columns)
        df = df[list(source_columns.values())]
        df["_source_file"] = source_file

        buffer = io.StringIO()
        df.to_csv(buffer, index=False, header=False, na_rep="")
        buffer.seek(0)

        with conn.cursor() as cur:
            cur.copy_expert(copy_sql, buffer)

        total_rows += len(df)

    conn.commit()
    return total_rows


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--taxi-type", choices=["yellow", "green", "both"], required=True)
    parser.add_argument("--month", help="YYYY-MM, e.g. 2025-01")
    parser.add_argument("--all", action="store_true", help="load every available month")
    args = parser.parse_args()

    if not args.month and not args.all:
        parser.error("pass either --month YYYY-MM or --all")

    taxi_types = ["yellow", "green"] if args.taxi_type == "both" else [args.taxi_type]

    conn = get_connection()
    run_sql_file(conn, "etl/sql/raw/create_raw_tables.sql")

    for taxi_type in taxi_types:
        files = list_files(taxi_type)
        if args.month:
            files = [f for f in files if month_from_filename(f) == args.month]
            if not files:
                sys.exit(f"No {taxi_type} file found for month {args.month}")

        for file_path in files:
            rows = load_file(conn, taxi_type, file_path)
            print(f"[{taxi_type}] {file_path.name}: loaded {rows:,} rows")

    conn.close()


if __name__ == "__main__":
    main()
