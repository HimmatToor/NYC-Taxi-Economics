select
    f.pickup_date,
    f.taxi_type,
    f.pu_location_id as location_id,
    z.borough,
    z.zone,
    count(*) as trip_count,
    sum(f.total_amount) as total_revenue,
    avg(f.fare_amount) as avg_fare,
    avg(f.tip_pct) as avg_tip_pct,
    avg(f.trip_distance) as avg_trip_distance,
    avg(f.trip_duration_minutes) as avg_trip_duration_minutes,
    sum(case when f.is_cbd_trip then 1 else 0 end) as cbd_trip_count
from {{ ref('fact_trips') }} f
left join {{ ref('dim_zone') }} z on f.pu_location_id = z.location_id
group by 1, 2, 3, 4, 5
