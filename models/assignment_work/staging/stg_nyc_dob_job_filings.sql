-- Clean and standardize DOB NOW: Build job application filings
-- One row per job filing
 
WITH source AS (
    SELECT * FROM {{ source('raw', 'source_nyc_dob_job_apps') }}
),
 
cleaned AS (
    SELECT
        -- Keep every other raw column as-is (applicant, owner, filing rep,
        -- work type flags, lot, floor area, etc. are needed by our dims),
        -- except the ones we transform below
        * EXCEPT (
            job_filing_number,
            filing_date,
            current_status_date,
            first_permit_date,
            approved_date,
            signoff_date,
            filing_status,
            job_type,
            building_type,
            initial_cost,
            existing_dwelling_units,
            proposed_dwelling_units,
            existing_stories,
            proposed_no_of_stories,
            total_construction_floor_area,
            borough,
            postcode,
            commmunity_board,
            latitude,
            longitude,
            city,    -- owner's address in raw, renamed below
            state,
            zip      -- owner's zip, NOT the job site, would clash with conformed zip
        ),
 
        -- Owner address - renamed so it isn't confused with the job site location
        TRIM(city) AS owner_city,
        TRIM(state) AS owner_state,
        TRIM(CAST(zip AS STRING)) AS owner_zip,
 
        -- Identifier
        TRIM(job_filing_number) AS job_filing_number,
 
        -- Dates - feed dim_date keys in the fact table
        CAST(filing_date AS TIMESTAMP) AS filing_date,
        CAST(current_status_date AS TIMESTAMP) AS current_status_date,
        CAST(first_permit_date AS TIMESTAMP) AS first_permit_date,
        CAST(approved_date AS TIMESTAMP) AS approved_date,
        CAST(signoff_date AS TIMESTAMP) AS signoff_date,
 
        -- Categories - dim_filing_status_history, dim_job_type (standardized so "Approved" and "APPROVED " don't become two rows)
        UPPER(TRIM(filing_status)) AS filing_status,
        UPPER(TRIM(job_type)) AS job_type,
        UPPER(TRIM(building_type)) AS building_type,
 
        -- Conformed location columns - dim_location (same names as 311 staging)
        CASE
            WHEN UPPER(TRIM(postcode)) IN ('N/A', 'NA', '') THEN NULL
            WHEN REGEXP_CONTAINS(TRIM(postcode), r'^\d{5}$') THEN TRIM(postcode)
            WHEN REGEXP_CONTAINS(TRIM(postcode), r'^\d{5}-?\d{4}$') THEN LEFT(TRIM(postcode), 5)
            ELSE NULL
        END AS zip,
 
        CASE
            WHEN UPPER(TRIM(borough)) IN ('MANHATTAN', 'NEW YORK COUNTY') THEN 'Manhattan'
            WHEN UPPER(TRIM(borough)) IN ('BRONX', 'THE BRONX') THEN 'Bronx'
            WHEN UPPER(TRIM(borough)) IN ('BROOKLYN', 'KINGS COUNTY') THEN 'Brooklyn'
            WHEN UPPER(TRIM(borough)) IN ('QUEENS', 'QUEEN', 'QUEENS COUNTY') THEN 'Queens'
            WHEN UPPER(TRIM(borough)) IN ('STATEN ISLAND', 'RICHMOND COUNTY') THEN 'Staten Island'
            ELSE 'UNKNOWN or CITYWIDE'
        END  AS borough,
 
        TRIM(commmunity_board) AS community_board,
        CAST(latitude AS DECIMAL) AS latitude,
        CAST(longitude AS DECIMAL) AS longitude,
 
        -- Measures for the fact table (types match the model)
        CAST(initial_cost AS NUMERIC) AS initial_cost,
        SAFE_CAST(total_construction_floor_area AS NUMERIC) AS total_construction_floor_area, -- STRING in raw
        SAFE_CAST(existing_dwelling_units AS INT64) AS existing_dwelling_units, -- STRING in raw
        SAFE_CAST(proposed_dwelling_units AS INT64) AS proposed_dwelling_units, -- FLOAT in raw
        SAFE_CAST(existing_stories AS INT64) AS existing_stories, -- STRING in raw
        SAFE_CAST(proposed_no_of_stories AS INT64) AS proposed_no_of_stories, -- FLOAT in raw
 
        -- Metadata
        CURRENT_TIMESTAMP() AS _stg_loaded_at
 
    FROM source
 
    -- Filters: drop rows that can't be used, without over-filtering
    WHERE job_filing_number IS NOT NULL
      AND filing_date IS NOT NULL
 
    -- Deduplicate: one row per filing (the fact table's grain), latest status wins
    QUALIFY ROW_NUMBER() OVER (PARTITION BY job_filing_number ORDER BY current_status_date DESC) = 1
)
 
SELECT * FROM cleaned