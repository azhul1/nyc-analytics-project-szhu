-- Staging for 311 Street Light and Traffic Signal requests
-- One row per request created from Jan 1, 2021 to Jun 30, 2026

WITH source AS (
    SELECT *
    FROM {{ source('group16_raw', 'source_nyc_311_streetlight_signal') }}
),

cleaned AS (
    SELECT
        unique_key,
        DATETIME(created_date) AS created_datetime,

        -- only Closed requests have a real closed date
        -- (all Pending requests have a closed_date earlier than created_date)
        CASE WHEN status = 'Closed' THEN DATETIME(closed_date) END AS closed_datetime,
        status,
        status = 'Closed' AS is_closed,
        CASE
            WHEN status = 'Closed' THEN TIMESTAMP_DIFF(closed_date, created_date, MINUTE) / 60.0
        END AS resolution_hours,

        -- complaint
        complaint_type,
        descriptor,
        descriptor_2,
        agency,

        -- location
        NULLIF(NULLIF(UPPER(TRIM(borough)), ''), 'UNSPECIFIED') AS borough,
        CASE
            WHEN REGEXP_CONTAINS(TRIM(incident_zip), r'^\d{5}') THEN SUBSTR(TRIM(incident_zip), 1, 5)
            ELSE NULL
        END AS zip_code,
        latitude,
        longitude,

        CURRENT_TIMESTAMP() AS loaded_at_utc
    FROM source
    WHERE DATE(created_date) BETWEEN '2021-01-01' AND '2026-06-30'
)

SELECT *
FROM cleaned
-- remove any duplicate requests
QUALIFY ROW_NUMBER() OVER (PARTITION BY unique_key ORDER BY unique_key) = 1