-- Complaint dimension: one row per complaint type + descriptor + descriptor 2
WITH stg_311 AS (
    SELECT * FROM {{ ref('stg_nyc_311_requests') }}
),

all_complaints AS (
    SELECT DISTINCT complaint_type, descriptor, descriptor_2
    FROM stg_311
),

complaint_dimension AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY complaint_type, descriptor, descriptor_2) AS complaint_key,
        complaint_type,
        descriptor,
        descriptor_2
    FROM all_complaints
)

SELECT * FROM complaint_dimension