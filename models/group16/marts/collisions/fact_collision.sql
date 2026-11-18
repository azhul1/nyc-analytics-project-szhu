-- Fact table: NYC motor vehicle collisions
-- Grain: one row per crash (collision_id, deduped in staging)

-- Make sure you have access to staging and its grain
WITH stg_collisions AS (
    SELECT * FROM {{ ref('stg_nyc_collisions') }}
),

-- All the dimensions in their own CTEs for easy reference
dim_date AS (
    SELECT * FROM {{ ref('dim_date') }}
),

dim_time AS (
    SELECT * FROM {{ ref('dim_time') }}
),

dim_location AS (
    SELECT * FROM {{ ref('dim_location') }}
),

dim_crash_severity AS (
    SELECT * FROM {{ ref('dim_crash_severity') }}
),

-- Build initial CTE for fact table
fact_collision_data AS (
    SELECT
        -- Degenerate dimension (business identifier)
        s.collision_id,
        -- Keys to the dimensions
        d.date_key AS crash_date_key,
        -- Missing crash times -> Unknown time (time_key -1)
        CASE WHEN s.crash_time IS NULL THEN -1 ELSE t.time_key END AS crash_time_key,
        l.location_key,
        sev.severity_key,
        -- Measures
        s.collision_count,
        s.number_of_persons_injured,
        s.number_of_persons_killed,
        s.number_of_pedestrians_injured,
        s.number_of_pedestrians_killed,
        s.number_of_cyclist_injured,
        s.number_of_cyclist_killed,
        s.number_of_motorist_injured,
        s.number_of_motorist_killed,
        -- Metadata
        s.loaded_at_utc
    FROM stg_collisions s

    -- Left joins because you want all the rows from staging in the fact, with key information from dimensions
    -- JOIN ON the items that make up the key in the dimension
    LEFT JOIN dim_date d
        ON s.crash_date = d.full_date
    LEFT JOIN dim_time t
        ON  EXTRACT(HOUR FROM s.crash_time)   = t.hour
        AND EXTRACT(MINUTE FROM s.crash_time) = t.minute
    -- IS NOT DISTINCT FROM so the Unknown borough / ZIP matches the dim row
    LEFT JOIN dim_location l
        ON  s.borough  IS NOT DISTINCT FROM l.borough
        AND s.zip_code IS NOT DISTINCT FROM l.zip_code
    LEFT JOIN dim_crash_severity sev
        ON s.severity_key = sev.severity_key
)

SELECT * FROM fact_collision_data