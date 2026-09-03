-- Month-over-month revenue growth by pickup zone, using LAG() to compare
-- each zone-month against its own prior month, then ranking zones within
-- each month by growth rate. Compile with `dbt compile` to get runnable SQL.

with monthly_zone_revenue as (
    select
        date_trunc('month', pickup_date)::date as month,
        location_id,
        borough,
        zone,
        sum(total_revenue) as revenue,
        sum(trip_count) as trip_count
    from {{ ref('agg_daily_zone') }}
    group by 1, 2, 3, 4
),

with_prior_month as (
    select
        *,
        lag(revenue) over (
            partition by location_id order by month
        ) as prior_month_revenue
    from monthly_zone_revenue
),

growth as (
    select
        *,
        case
            when prior_month_revenue > 0
                then round((revenue - prior_month_revenue) / prior_month_revenue * 100, 2)
        end as revenue_growth_pct
    from with_prior_month
)

select
    month,
    borough,
    zone,
    trip_count,
    revenue,
    revenue_growth_pct,
    rank() over (partition by month order by revenue_growth_pct desc nulls last) as growth_rank_in_month
from growth
order by month, growth_rank_in_month
