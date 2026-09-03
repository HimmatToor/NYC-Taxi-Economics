-- 7-day rolling average trip demand per borough, using a window frame
-- (ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) to smooth day-of-week noise
-- out of the raw daily counts. Useful as a sanity check against, and
-- feature-engineering reference for, the demand forecasting model.

with daily_borough_demand as (
    select
        f.pickup_date,
        z.borough,
        count(*) as trip_count
    from {{ ref('fact_trips') }} f
    join {{ ref('dim_zone') }} z on f.pu_location_id = z.location_id
    where f.is_valid_trip
    group by 1, 2
)

select
    pickup_date,
    borough,
    trip_count,
    round(avg(trip_count) over (
        partition by borough
        order by pickup_date
        rows between 6 preceding and current row
    ), 1) as rolling_7day_avg_trips,
    trip_count - avg(trip_count) over (
        partition by borough
        order by pickup_date
        rows between 6 preceding and current row
    ) as deviation_from_rolling_avg
from daily_borough_demand
order by borough, pickup_date
