{{ config(materialized="table",alias='PARTSUPP_DBT_TEMP') }}

-- 1. CLEAN DATA

WITH cleaned AS (
    SELECT
        PS_PARTKEY,

        -- Drop if supplier key is null
        PS_SUPPKEY,

        -- Replace null quantities
        COALESCE(PS_AVAILQTY, 0) AS PS_AVAILQTY,

        -- Replace negative or null supply cost
        CASE 
            WHEN PS_SUPPLYCOST IS NULL OR PS_SUPPLYCOST < 0 THEN 0
            ELSE PS_SUPPLYCOST
        END AS PS_SUPPLYCOST,

        -- Replace empty/null comment with default
        COALESCE(NULLIF(TRIM(PS_COMMENT), ''), 'DEFAULT COMMENT') AS PS_COMMENT,

        CREATED_AT,
        SOURCE_SYSTEM
    FROM {{ source('silver_layer','partsupp_stg') }}
),

-- 2. DROP INVALID ROWS (SUPPLIER KEY IS REQUIRED)

filtered AS (
    SELECT *
    FROM cleaned
    WHERE PS_SUPPKEY IS NOT NULL
),

-- 3. REMOVE DUPLICATES USING LATEST CREATED_AT

dedup AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY PS_PARTKEY, PS_SUPPKEY
            ORDER BY CREATED_AT DESC
        ) AS rn
    FROM filtered
)

-- 4. FINAL RESULT

SELECT
    PS_PARTKEY,
    PS_SUPPKEY,
    PS_AVAILQTY,
    PS_SUPPLYCOST,
    PS_COMMENT,
    CREATED_AT,
    SOURCE_SYSTEM
FROM dedup
