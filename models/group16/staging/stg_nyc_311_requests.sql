-- Staging for 311 Street Light and Traffic Signal requests
-- One row per request created from Jan 1, 2021 to Jun 30, 2026

WITH source AS (
    SELECT * FROM {{ source('group16_raw', 'source_nyc_311_streetlight_signal') }}
), -- Easier to refer to the dbt reference to a long name table this way

cleaned AS (
    SELECT
        -- Identifiers (INT in our model, original text kept for tracing)
        SAFE_CAST(NULLIF(TRIM(unique_key), '') AS INT64) AS unique_key,
        NULLIF(TRIM(unique_key), '') AS raw_unique_key,

        -- Date/Time (raw times are NYC local time stored as TIMESTAMP)
        DATETIME(created_date) AS created_datetime,
        -- Only Closed requests have a real closed date: every Pending request
        -- has a closed_date earlier than its created_date
        CASE WHEN UPPER(TRIM(status)) = 'CLOSED' THEN DATETIME(closed_date) END AS closed_datetime,

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
            WHEN REGEXP_CONTAINS(TRIM(incident_zip), r'^\d{5}(-\d{4})?$')
                 AND SUBSTR(TRIM(incident_zip), 1, 5) != '00000'
                THEN SUBSTR(TRIM(incident_zip), 1, 5)
            ELSE 'Unknown'
        END AS zip_code,

        -- Request details
        CASE
            WHEN UPPER(TRIM(complaint_type)) = 'STREET LIGHT CONDITION' THEN 'Street Light Condition'
            WHEN UPPER(TRIM(complaint_type)) = 'TRAFFIC SIGNAL CONDITION' THEN 'Traffic Signal Condition'
        END AS complaint_type,
        COALESCE(NULLIF(TRIM(descriptor), ''), 'Not specified') AS descriptor,
        NULLIF(TRIM(descriptor_2), '') AS descriptor_2,
        COALESCE(INITCAP(NULLIF(TRIM(status), '')), 'Unknown') AS status,
        1 AS request_count,

        -- Metadata
        created_date AS raw_created_timestamp,
        closed_date AS raw_closed_timestamp,
        CURRENT_TIMESTAMP() AS loaded_at_utc
    FROM source
    -- Filters (on created date only: a request can close after June 2026)
    WHERE DATETIME(created_date) >= DATETIME '2021-01-01 00:00:00'
      AND DATETIME(created_date) < DATETIME '2026-07-01 00:00:00'
      AND UPPER(TRIM(complaint_type)) IN ('STREET LIGHT CONDITION', 'TRAFFIC SIGNAL CONDITION')
    -- Deduplicate
    QUALIFY ROW_NUMBER() OVER (PARTITION BY source.unique_key ORDER BY source.created_date) = 1
)

SELECT * FROM cleaned