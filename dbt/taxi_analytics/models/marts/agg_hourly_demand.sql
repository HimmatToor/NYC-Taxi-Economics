-- Zone x hour trip counts: the feature table the demand-forecasting model reads from,
-- and the granularity the dashboard's demand views are built on.
select
    f.pickup_date,
    f.pickup_hour,
    f.taxi_type,
    f.pu_location_id                     as location_id,
    z.borough,
    count(*)                              as trip_count,
    avg(f.fare_amount)                    as avg_fare,
    avg(f.tip_pct)                        as avg_tip_pct
from {{ ref('fact_trips') }} f
left join {{ ref('dim_zone') }} z on f.pu_location_id = z.location_id
where f.is_valid_trip
group by 1, 2, 3, 4, 5
