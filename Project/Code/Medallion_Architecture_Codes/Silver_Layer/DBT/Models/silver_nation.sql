{{ config(materialized="table",alias='NATION_DBT_TEMP') }}

-- Step 1: Clean fields
WITH cleaned AS (
    SELECT
        N_NATIONKEY,

        CASE 
            WHEN TRIM(N_NAME) IS NULL OR TRIM(N_NAME) = ''
                THEN 'UNKNOWN_NATION'
            ELSE TRIM(N_NAME)
        END AS N_NAME,

        N_REGIONKEY,

        CASE 
            WHEN TRIM(N_COMMENT) IS NULL OR TRIM(N_COMMENT) = ''
                THEN 'DEFAULT COMMENT'
            ELSE TRIM(N_COMMENT)
        END AS N_COMMENT
    FROM {{ source('silver_layer', 'nation_stg') }}
),

-- Step 2: Drop invalid rows
valid AS (
    SELECT *
    FROM cleaned
    WHERE N_REGIONKEY IS NOT NULL
),

-- Step 3: Deduplicate N_NATIONKEY (keep OLDEST ROW)
dedup AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY N_NATIONKEY
            ORDER BY N_NATIONKEY ASC    -- oldest first
        ) AS rn
    FROM valid
)

-- Step 4: Select only cleaned records
SELECT
    N_NATIONKEY,
    N_NAME,
    N_REGIONKEY,
    N_COMMENT,
FROM dedup
