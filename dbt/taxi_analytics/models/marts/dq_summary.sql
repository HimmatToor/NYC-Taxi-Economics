-- rejection rate by taxi type / month, for the report's cleaning section

with base as (
    select
        taxi_type,
        date_trunc('month', pickup_datetime)::date as month,
        is_valid_trip
    from {{ ref('int_trips_unioned') }}
)

select
    taxi_type,
    month,
    count(*) as total_trips,
    sum(case when is_valid_trip then 1 else 0 end) as clean_trips,
    sum(case when not is_valid_trip then 1 else 0 end) as rejected_trips,
    round(
        sum(case when not is_valid_trip then 1 else 0 end)::numeric
        / nullif(count(*), 0) * 100,
        2
    ) as rejection_rate_pct
from base
group by 1, 2
order by taxi_type, month
