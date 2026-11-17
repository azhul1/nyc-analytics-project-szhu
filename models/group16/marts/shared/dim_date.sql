with calendar as (
    select full_date
    from unnest(
        generate_date_array(
            date '2021-01-01',
            current_date('America/New_York')
        )
    ) as full_date
)

select
    cast(format_date('%Y%m%d', full_date) as int64) as date_key,
    full_date,
    extract(year from full_date) as year,
    extract(quarter from full_date) as quarter,
    extract(month from full_date) as month_number,
    format_date('%B', full_date) as month_name,
    extract(day from full_date) as day_of_month,
    format_date('%A', full_date) as day_of_week,
    case
        when extract(month from full_date) in (12, 1, 2)
            then 'Winter'
        when extract(month from full_date) in (3, 4, 5)
            then 'Spring'
        when extract(month from full_date) in (6, 7, 8)
            then 'Summer'
        else 'Fall'
    end as season
from calendar

union all

select
    0 as date_key,
    cast(null as date) as full_date,
    0 as year,
    0 as quarter,
    0 as month_number,
    'Not closed' as month_name,
    0 as day_of_month,
    'Not closed' as day_of_week,
    'Not closed' as season