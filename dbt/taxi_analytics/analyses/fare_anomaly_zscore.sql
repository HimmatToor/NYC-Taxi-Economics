-- trips where fare-per-mile is a statistical outlier for their taxi type (|z| > 3)
-- candidates for overcharge/meter-error, also useful before training the fare model

with fare_per_mile as (
    select
        trip_id,
        taxi_type,
        pickup_date,
        pu_location_id,
        fare_amount,
        trip_distance,
        fare_amount / trip_distance as fare_per_mile
    from {{ ref('fact_trips') }}
    where trip_distance >= 0.5   -- avoid divide-by-near-zero noise
),

scored as (
    select
        *,
        avg(fare_per_mile) over (partition by taxi_type) as avg_fare_per_mile,
        stddev(fare_per_mile) over (partition by taxi_type) as stddev_fare_per_mile
    from fare_per_mile
)

select
    trip_id,
    taxi_type,
    pickup_date,
    pu_location_id,
    fare_amount,
    trip_distance,
    round(fare_per_mile, 2) as fare_per_mile,
    round((fare_per_mile - avg_fare_per_mile) / nullif(stddev_fare_per_mile, 0), 2) as fare_per_mile_zscore
from scored
where abs((fare_per_mile - avg_fare_per_mile) / nullif(stddev_fare_per_mile, 0)) > 3
order by fare_per_mile_zscore desc
