-- Staging for NYC Motor Vehicle Collisions
-- One row per crash from Jan 1, 2021 to Jun 30, 2026

WITH source AS (
    SELECT *
    FROM {{ source('group16_raw', 'source_nyc_mv_collisions') }}
),

cleaned AS (
    SELECT
        collision_id,
        DATE(crash_date) AS crash_date,
        SAFE.PARSE_TIME('%H:%M', TRIM(crash_time)) AS crash_time,

        -- location
        NULLIF(NULLIF(UPPER(TRIM(borough)), ''), 'UNSPECIFIED') AS borough,
        CASE
            WHEN REGEXP_CONTAINS(TRIM(zip_code), r'^\d{5}') THEN SUBSTR(TRIM(zip_code), 1, 5)
            ELSE NULL
        END AS zip_code,
        latitude,
        longitude,

        -- counts (the 6 role counts are STRING in raw)
        number_of_persons_injured,
        number_of_persons_killed,
        SAFE_CAST(number_of_pedestrians_injured AS INT64) AS number_of_pedestrians_injured,
        SAFE_CAST(number_of_pedestrians_killed AS INT64) AS number_of_pedestrians_killed,
        SAFE_CAST(number_of_cyclist_injured AS INT64) AS number_of_cyclist_injured,
        SAFE_CAST(number_of_cyclist_killed AS INT64) AS number_of_cyclist_killed,
        SAFE_CAST(number_of_motorist_injured AS INT64) AS number_of_motorist_injured,
        SAFE_CAST(number_of_motorist_killed AS INT64) AS number_of_motorist_killed,

        -- severity_level
        CASE
            WHEN number_of_persons_injured IS NULL OR number_of_persons_killed IS NULL THEN 0 -- Unknown
            WHEN number_of_persons_killed > 0 THEN 4 -- Fatal
            WHEN number_of_persons_injured > 1 THEN 3 -- Multiple Injuries
            WHEN number_of_persons_injured = 1 THEN 2 -- Single Injury
            ELSE 1 -- No Injury
        END AS severity_level,

        CURRENT_TIMESTAMP() AS loaded_at_utc
    FROM source
    WHERE DATE(crash_date) BETWEEN '2021-01-01' AND '2026-06-30'
)

SELECT *
FROM cleaned
-- remove duplicate crashes
QUALIFY ROW_NUMBER() OVER (PARTITION BY collision_id ORDER BY collision_id) = 1