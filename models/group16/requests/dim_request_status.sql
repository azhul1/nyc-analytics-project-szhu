-- Request status dimension: one row per 311 status, plus an Unknown row (status_key 0)
-- Only Closed counts as closed
WITH stg_311 AS (
    SELECT * FROM {{ ref('stg_nyc_311_requests') }}
),

all_statuses AS (
    SELECT DISTINCT status
    FROM stg_311
    WHERE status != 'Unknown'
),

status_dimension AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY status) AS status_key,
        status,
        status = 'Closed' AS is_closed
    FROM all_statuses
),

-- Placeholder row for requests with no status
unknown_placeholder AS (
    SELECT
        0 AS status_key,
        'Unknown' AS status,
        FALSE AS is_closed
)

SELECT * FROM status_dimension
UNION ALL
SELECT * FROM unknown_placeholder