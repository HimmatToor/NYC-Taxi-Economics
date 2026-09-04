-- a trip can fail more than one check, so these counts sum to more than rejected_trips

with unnested as (
    select
        taxi_type,
        unnest(rejection_reasons) as rejection_reason
    from {{ ref('rejected_trips') }}
)

select
    taxi_type,
    rejection_reason,
    count(*) as trip_count
from unnested
group by 1, 2
order by taxi_type, trip_count desc
