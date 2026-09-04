-- union yellow + green, add QC flag columns. nothing gets filtered here,
-- fact_trips is what actually applies is_valid_trip.
-- flags are coalesced to false so a null field (e.g. passenger_count) makes
-- a trip invalid instead of making is_valid_trip null (null and true = null,
-- not false, so it would otherwise slip past the "where is_valid_trip" filter)

with unioned as (
    select * from {{ ref('stg_yellow_trips') }}
    union all
    select * from {{ ref('stg_green_trips') }}
),

flagged as (
    select
        *,
        extract(epoch from (dropoff_datetime - pickup_datetime)) / 60.0 as trip_duration_minutes,
        case
            when tip_amount is not null and fare_amount > 0
                then round(tip_amount / fare_amount * 100, 2)
        end as tip_pct,
        cbd_congestion_fee > 0 as is_cbd_trip
    from unioned
),

qc_flags as (
    select
        *,
        coalesce(fare_amount > 0 and total_amount > 0, false) as is_valid_fare,
        coalesce(trip_distance > 0 and trip_distance < 100, false) as is_valid_distance,
        coalesce(passenger_count between 1 and 6, false) as is_valid_passenger_count,
        coalesce(trip_duration_minutes > 0 and trip_duration_minutes < 480, false) as is_valid_duration,
        coalesce(pu_location_id not in (264, 265) and do_location_id not in (264, 265), false) as is_known_zone,
        -- meter clocks occasionally record garbage years (seen: 2007/2008, and a
        -- few days into the following year from New Year's Eve trips). TLC files
        -- also always carry a handful of trips just outside the stated month, so
        -- this is deliberately a year-level bound, not a strict month check.
        coalesce(extract(year from pickup_datetime) between 2024 and 2026, false) as is_valid_pickup_year
    from flagged
)

select
    *,
    is_valid_fare and is_valid_distance and is_valid_passenger_count
        and is_valid_duration and is_known_zone and is_valid_pickup_year as is_valid_trip
from qc_flags
