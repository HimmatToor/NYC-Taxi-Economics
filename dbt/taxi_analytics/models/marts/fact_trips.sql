{{
    config(
        materialized='incremental',
        unique_key='trip_id',
        on_schema_change='sync_all_columns'
    )
}}

-- only valid trips get in here, this is the cleaning gate.
-- rejected rows go to rejected_trips instead.
with trips as (

    select * from {{ ref('int_trips_unioned') }}

    where is_valid_trip

    {% if is_incremental() %}
    and pickup_datetime > (select coalesce(max(pickup_datetime), '1900-01-01') from {{ this }})
    {% endif %}

),

keyed as (
    select
        {{ dbt_utils.generate_surrogate_key([
            'taxi_type', 'source_file', 'pickup_datetime', 'dropoff_datetime',
            'pu_location_id', 'do_location_id', 'vendor_id', 'fare_amount', 'trip_distance'
        ]) }} as trip_id,

        taxi_type,
        vendor_id,
        pickup_datetime,
        dropoff_datetime,
        date_trunc('day', pickup_datetime)::date as pickup_date,
        extract(hour from pickup_datetime)::int as pickup_hour,
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

        -- tip_amount isn't part of the key (tips get adjusted after the fact),
        -- so two source rows can occasionally collide on trip_id - happens with
        -- genuine TLC duplicate/corrected records. keep the one with the highest
        -- tip_amount, arbitrary but deterministic.
        row_number() over (
            partition by
                taxi_type, source_file, pickup_datetime, dropoff_datetime,
                pu_location_id, do_location_id, vendor_id, fare_amount, trip_distance
            order by tip_amount desc
        ) as row_num

    from trips
)

select
    trip_id,
    taxi_type,
    vendor_id,
    pickup_datetime,
    dropoff_datetime,
    pickup_date,
    pickup_hour,
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
    is_cbd_trip

from keyed
where row_num = 1
