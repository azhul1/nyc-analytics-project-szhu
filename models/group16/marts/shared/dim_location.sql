-- Conformed location dimension: one row per borough + ZIP code combination
-- found in either staging table, plus an Unknown row (location_key 0)
WITH stg_collisions AS (
    SELECT * FROM {{ ref('stg_nyc_collisions') }}
),

stg_311 AS (
    SELECT * FROM {{ ref('stg_nyc_311_requests') }}
),

all_locations AS (
    SELECT DISTINCT borough, zip_code FROM stg_collisions
    UNION DISTINCT
    SELECT DISTINCT borough, zip_code FROM stg_311
),

location_dimension AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY borough, zip_code) AS location_key,
        borough,
        zip_code
    FROM all_locations
    -- Unknown/Unknown gets its own placeholder row below
    WHERE NOT (borough = 'Unknown' AND zip_code = 'Unknown')
),

-- Placeholder row for locations with no borough and no ZIP code
unknown_placeholder AS (
    SELECT
        0 AS location_key,
        'Unknown' AS borough,
        'Unknown' AS zip_code
)

SELECT * FROM location_dimension
UNION ALL
SELECT * FROM unknown_placeholder