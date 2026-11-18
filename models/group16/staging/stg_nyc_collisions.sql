-- Staging for NYC Motor Vehicle Collisions data
-- One row per crash (collision_id), Jan 1, 2021 to Jun 30, 2026
WITH source AS (
    SELECT * FROM {{ source('group16_raw', 'source_nyc_mv_collisions') }}
), -- Easier to refer to the dbt reference to a long name table this way

cleaned AS (
    SELECT
        -- Identifiers
        collision_id,

        -- Date/Time (raw times are NYC local time stored as TIMESTAMP)
        DATE(crash_date) AS crash_date,
        COALESCE(
            SAFE.PARSE_TIME('%H:%M', NULLIF(TRIM(crash_time), '')),
            SAFE.PARSE_TIME('%H:%M:%S', NULLIF(TRIM(crash_time), ''))
        ) AS crash_time,

        -- Location - standardized borough
        CASE
            WHEN UPPER(TRIM(borough)) IN ('MANHATTAN', 'NEW YORK') THEN 'MANHATTAN'
            WHEN UPPER(TRIM(borough)) = 'BROOKLYN' THEN 'BROOKLYN'
            WHEN UPPER(TRIM(borough)) = 'QUEENS' THEN 'QUEENS'
            WHEN UPPER(TRIM(borough)) IN ('BRONX', 'THE BRONX') THEN 'BRONX'
            WHEN UPPER(TRIM(borough)) = 'STATEN ISLAND' THEN 'STATEN ISLAND'
            ELSE 'Unknown'
        END AS borough,

        -- Location - clean zip code (5 digits, or 5+4), anything else is Unknown
        CASE
            WHEN REGEXP_CONTAINS(TRIM(zip_code), r'^\d{5}(-\d{4})?$')
                 AND SUBSTR(TRIM(zip_code), 1, 5) != '00000'
                THEN SUBSTR(TRIM(zip_code), 1, 5)
            ELSE 'Unknown'
        END AS zip_code,

        -- Persons injured/killed: blank stays NULL (not recorded)
        number_of_persons_injured,
        number_of_persons_killed,

        -- Subgroup counts are STRING in raw: blank becomes 0, as in our model
        CASE WHEN NULLIF(TRIM(number_of_pedestrians_injured), '') IS NULL THEN 0
             ELSE SAFE_CAST(TRIM(number_of_pedestrians_injured) AS INT64) END AS number_of_pedestrians_injured,
        CASE WHEN NULLIF(TRIM(number_of_pedestrians_killed), '') IS NULL THEN 0
             ELSE SAFE_CAST(TRIM(number_of_pedestrians_killed) AS INT64) END AS number_of_pedestrians_killed,
        CASE WHEN NULLIF(TRIM(number_of_cyclist_injured), '') IS NULL THEN 0
             ELSE SAFE_CAST(TRIM(number_of_cyclist_injured) AS INT64) END AS number_of_cyclist_injured,
        CASE WHEN NULLIF(TRIM(number_of_cyclist_killed), '') IS NULL THEN 0
             ELSE SAFE_CAST(TRIM(number_of_cyclist_killed) AS INT64) END AS number_of_cyclist_killed,
        CASE WHEN NULLIF(TRIM(number_of_motorist_injured), '') IS NULL THEN 0
             ELSE SAFE_CAST(TRIM(number_of_motorist_injured) AS INT64) END AS number_of_motorist_injured,
        CASE WHEN NULLIF(TRIM(number_of_motorist_killed), '') IS NULL THEN 0
             ELSE SAFE_CAST(TRIM(number_of_motorist_killed) AS INT64) END AS number_of_motorist_killed,

        -- Severity rule from Milestone 3, applied in this order
        CASE
            WHEN number_of_persons_killed >= 1 THEN 4                                          -- Fatal
            WHEN number_of_persons_killed IS NULL OR number_of_persons_injured IS NULL THEN 0  -- Unknown
            WHEN number_of_persons_injured >= 2 THEN 3                                         -- Multiple Injuries
            WHEN number_of_persons_injured = 1 THEN 2                                          -- Single Injury
            ELSE 1                                                                             -- No Injury
        END AS severity_key,
        1 AS collision_count,

        -- Metadata
        crash_date AS raw_crash_timestamp,
        CURRENT_TIMESTAMP() AS loaded_at_utc
    FROM source
    -- Filters
    WHERE DATE(crash_date) >= '2021-01-01'
      AND DATE(crash_date) < '2026-07-01'
    -- Deduplicate (the Milestone 3 load added some chunks twice)
    QUALIFY ROW_NUMBER() OVER (PARTITION BY source.collision_id ORDER BY source.crash_date) = 1
)

SELECT * FROM cleaned