select
    d::date as date_day,
    extract(year from d)::int as year,
    extract(month from d)::int as month,
    trim(to_char(d, 'Month')) as month_name,
    extract(day from d)::int as day_of_month,
    extract(dow from d)::int as day_of_week,
    extract(dow from d) in (0, 6) as is_weekend,
    extract(week from d)::int as week_of_year
from generate_series('2025-01-01'::date, '2025-12-31'::date, interval '1 day') as d
