{{
    config(
        materialized='incremental',
        unique_key='trip_id',
        on_schema_change='sync_all_columns'
    )
}}

with trips as (

    select * from {{ ref('int_trips_unioned') }}

    {% if is_incremental() %}
    where pickup_datetime > (select coalesce(max(pickup_datetime), '1900-01-01') from {{ this }})
    {% endif %}

)

select
    {{ dbt_utils.generate_surrogate_key([
        'taxi_type', 'source_file', 'pickup_datetime',
        'pu_location_id', 'do_location_id', 'vendor_id', 'fare_amount'
    ]) }}                                          as trip_id,

    taxi_type,
    vendor_id,
    pickup_datetime,
    dropoff_datetime,
    date_trunc('day', pickup_datetime)::date        as pickup_date,
    extract(hour from pickup_datetime)::int         as pickup_hour,
    pu_location_id,
    do_location_id,
    passenger_count,
    trip_distance,
    trip_duration_minutes,
    payment_type,
    fare_amount,
    extra,
    mta_tax,
    tip_amount,
    tip_pct,
    tolls_amount,
    improvement_surcharge,
    congestion_surcharge,
    airport_fee,
    cbd_congestion_fee,
    total_amount,
    is_cbd_trip,
    is_valid_trip

from trips
