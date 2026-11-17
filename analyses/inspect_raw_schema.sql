select
    table_name,
    ordinal_position,
    column_name,
    data_type,
    is_nullable
from `szhu-baruch.group16_raw_data.INFORMATION_SCHEMA.COLUMNS`
where table_name in (
    'source_nyc_mv_collisions',
    'source_nyc_311_streetlight_signal'
)
order by
    table_name,
    ordinal_position