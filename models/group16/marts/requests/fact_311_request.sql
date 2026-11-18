-- Fact table: 311 street light and traffic signal requests
-- Grain: one row per request (unique_key, deduped in staging)

-- Make sure you have access to staging and its grain
WITH stg_311 AS (
    SELECT * FROM {{ ref('stg_nyc_311_requests') }}
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

dim_complaint AS (
    SELECT * FROM {{ ref('dim_complaint') }}
),

dim_request_status AS (
    SELECT * FROM {{ ref('dim_request_status') }}
),

-- Build initial CTE for fact table
fact_311_request_data AS (
    SELECT
        -- Degenerate dimension (business identifier)
        s.unique_key,
        -- Keys to the dimensions
        created_d.date_key AS created_date_key,
        t.time_key AS created_time_key,
        -- Requests that are not Closed have no closed date -> Not closed (date_key 0)
        CASE WHEN s.closed_datetime IS NULL THEN 0 ELSE closed_d.date_key END AS closed_date_key,
        l.location_key,
        c.complaint_key,
        r.status_key,
        -- Measures
        s.request_count,
        s.created_datetime,
        s.closed_datetime,
        -- Calculated fields (NULL when the request is not Closed)
        CAST(ROUND(DATETIME_DIFF(s.closed_datetime, s.created_datetime, SECOND) / 3600.0, 2) AS NUMERIC) AS resolution_hours,
        -- Metadata
        s.loaded_at_utc
    FROM stg_311 s

    -- Left joins because you want all the rows from staging in the fact, with key information from dimensions
    -- JOIN ON the items that make up the key in the dimension
    LEFT JOIN dim_date created_d
        ON DATE(s.created_datetime) = created_d.full_date
    LEFT JOIN dim_date closed_d
        ON DATE(s.closed_datetime) = closed_d.full_date
    LEFT JOIN dim_time t
        ON  EXTRACT(HOUR FROM s.created_datetime)   = t.hour
        AND EXTRACT(MINUTE FROM s.created_datetime) = t.minute
    -- IS NOT DISTINCT FROM so the Unknown borough / ZIP and a blank descriptor 2 match the dim row
    LEFT JOIN dim_location l
        ON  s.borough  IS NOT DISTINCT FROM l.borough
        AND s.zip_code IS NOT DISTINCT FROM l.zip_code
    LEFT JOIN dim_complaint c
        ON  s.complaint_type IS NOT DISTINCT FROM c.complaint_type
        AND s.descriptor     IS NOT DISTINCT FROM c.descriptor
        AND s.descriptor_2   IS NOT DISTINCT FROM c.descriptor_2
    LEFT JOIN dim_request_status r
        ON s.status = r.status
)

SELECT * FROM fact_311_request_data