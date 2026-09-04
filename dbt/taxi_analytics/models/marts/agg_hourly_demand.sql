-- zone x hour trip counts, feeds the demand forecasting model and dashboard

select
    f.pickup_date,
    f.pickup_hour,
    f.taxi_type,
    f.pu_location_id as location_id,
    z.borough,
    count(*) as trip_count,
    avg(f.fare_amount) as avg_fare,
    avg(f.tip_pct) as avg_tip_pct
from {{ ref('fact_trips') }} f
left join {{ ref('dim_zone') }} z on f.pu_location_id = z.location_id
group by 1, 2, 3, 4, 5
