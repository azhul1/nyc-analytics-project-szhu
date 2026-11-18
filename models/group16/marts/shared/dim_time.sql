with minutes as (
    select minute_of_day
    from unnest(generate_array(0, 1439)) as minute_of_day
),

time_parts as (
    select
        div(minute_of_day, 60) as hour,
        mod(minute_of_day, 60) as minute
    from minutes
)

select
    hour * 100 + minute as time_key,
    hour,
    minute,
    case
        when hour between 6 and 11 then 'Morning'
        when hour between 12 and 16 then 'Afternoon'
        when hour between 17 and 20 then 'Evening'
        else 'Night'
    end as time_of_day
from time_parts

union all

select
    -1 as time_key,
    -1 as hour,
    -1 as minute,
    'Unknown' as time_of_day