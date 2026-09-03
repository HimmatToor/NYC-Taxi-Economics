-- Unions yellow + green on the common schema and attaches data-quality flags
-- as columns rather than filtering rows out, so downstream consumers choose
-- whether to trust flagged trips (e.g. ML training excludes them, a raw
-- trip-volume chart might not).

with unioned as (
    select * from {{ ref('stg_yellow_trips') }}
    union all
    select * from {{ ref('stg_green_trips') }}
),

flagged as (
    select
        *,
        extract(epoch from (dropoff_datetime - pickup_datetime)) / 60.0
            as trip_duration_minutes,
        case
            when tip_amount is not null and fare_amount > 0
                then round(tip_amount / fare_amount * 100, 2)
        end as tip_pct,
        cbd_congestion_fee > 0                                    as is_cbd_trip

    from unioned
)

select
    *,

    (fare_amount > 0 and total_amount > 0)                        as is_valid_fare,
    (trip_distance > 0 and trip_distance < 100)                   as is_valid_distance,
    (passenger_count between 1 and 6)                              as is_valid_passenger_count,
    (trip_duration_minutes > 0 and trip_duration_minutes < 480)   as is_valid_duration,
    (pu_location_id not in (264, 265) and do_location_id not in (264, 265))
                                                                    as is_known_zone,

    (
        fare_amount > 0 and total_amount > 0
        and trip_distance > 0 and trip_distance < 100
        and passenger_count between 1 and 6
        and trip_duration_minutes > 0 and trip_duration_minutes < 480
        and pu_location_id not in (264, 265)
        and do_location_id not in (264, 265)
    ) as is_valid_trip

from flagged
