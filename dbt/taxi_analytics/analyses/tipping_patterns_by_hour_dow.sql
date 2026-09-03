-- Tipping behavior by hour-of-day x day-of-week, split by taxi type.
-- Demonstrates a pivot-style aggregation plus a window function to find,
-- for each taxi type, which hour tips best relative to that type's own average.

with hourly_tips as (
    select
        f.taxi_type,
        d.day_of_week,
        f.pickup_hour,
        avg(f.tip_pct)   as avg_tip_pct,
        count(*)         as trip_count
    from {{ ref('fact_trips') }} f
    join {{ ref('dim_date') }} d on f.pickup_date = d.date_day
    where f.is_valid_trip
      and f.payment_type = 1              -- credit card: cash tips aren't captured in TLC data
    group by 1, 2, 3
),

benchmarked as (
    select
        *,
        avg(avg_tip_pct) over (partition by taxi_type) as taxi_type_avg_tip_pct,
        avg_tip_pct - avg(avg_tip_pct) over (partition by taxi_type) as tip_pct_vs_avg
    from hourly_tips
)

select
    taxi_type,
    day_of_week,
    pickup_hour,
    trip_count,
    round(avg_tip_pct, 2)          as avg_tip_pct,
    round(taxi_type_avg_tip_pct, 2) as taxi_type_avg_tip_pct,
    round(tip_pct_vs_avg, 2)        as tip_pct_vs_avg,
    rank() over (partition by taxi_type order by avg_tip_pct desc) as tip_rank_within_taxi_type
from benchmarked
order by taxi_type, tip_rank_within_taxi_type
