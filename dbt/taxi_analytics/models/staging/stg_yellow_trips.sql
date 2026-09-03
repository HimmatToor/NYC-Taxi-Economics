-- Rename/cast only. No filtering here — data quality flags live downstream
-- in int_trips_unioned so raw shape stays inspectable and nothing is silently dropped.

with source as (
    select * from {{ source('raw', 'yellow_trips') }}
)

select
    'yellow'                                as taxi_type,
    vendor_id,
    tpep_pickup_datetime::timestamp         as pickup_datetime,
    tpep_dropoff_datetime::timestamp        as dropoff_datetime,
    passenger_count::int                    as passenger_count,
    trip_distance::numeric(10, 2)           as trip_distance,
    rate_code_id::int                       as rate_code_id,
    store_and_fwd_flag,
    pu_location_id,
    do_location_id,
    payment_type::int                       as payment_type,
    null::numeric                           as trip_type,
    fare_amount::numeric(10, 2)             as fare_amount,
    extra::numeric(10, 2)                   as extra,
    mta_tax::numeric(10, 2)                 as mta_tax,
    tip_amount::numeric(10, 2)              as tip_amount,
    tolls_amount::numeric(10, 2)            as tolls_amount,
    null::numeric(10, 2)                    as ehail_fee,
    improvement_surcharge::numeric(10, 2)   as improvement_surcharge,
    congestion_surcharge::numeric(10, 2)    as congestion_surcharge,
    airport_fee::numeric(10, 2)             as airport_fee,
    cbd_congestion_fee::numeric(10, 2)      as cbd_congestion_fee,
    total_amount::numeric(10, 2)            as total_amount,
    _source_file                            as source_file
from source
