-- everything fact_trips excluded, plus which check(s) it failed

select
    taxi_type,
    source_file,
    pickup_datetime,
    pu_location_id,
    do_location_id,
    fare_amount,
    trip_distance,
    trip_duration_minutes,
    passenger_count,

    array_remove(array[
        case when not is_valid_fare then 'invalid_fare' end,
        case when not is_valid_distance then 'invalid_distance' end,
        case when not is_valid_passenger_count then 'invalid_passenger_count' end,
        case when not is_valid_duration then 'invalid_duration' end,
        case when not is_known_zone then 'unknown_zone' end,
        case when not is_valid_pickup_year then 'invalid_pickup_year' end
    ], null) as rejection_reasons

from {{ ref('int_trips_unioned') }}
where not is_valid_trip
