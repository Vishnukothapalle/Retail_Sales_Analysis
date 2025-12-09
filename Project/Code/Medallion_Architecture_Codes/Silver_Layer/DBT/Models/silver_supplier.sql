{{ config(materialized="table",alias='SUPPLIER_DBT_TEMP') }}

WITH cleaned AS (
    SELECT
        S_SUPPKEY,

        -- Clean name: if null/blank → "SUPPLIER"
        COALESCE(NULLIF(TRIM(S_NAME), ''), 'SUPPLIER') AS S_NAME,

        -- Clean address: if null/blank → "ADDRESS NOT PROVIDED"
        COALESCE(NULLIF(TRIM(S_ADDRESS), ''), 'ADDRESS NOT PROVIDED') AS S_ADDRESS,

        -- Must not be NULL → will be filtered out later
        S_NATIONKEY,

        -- Phone: extract digits, if empty → default
        CASE
            WHEN REGEXP_REPLACE(S_PHONE, '[^0-9]', '') IS NULL
              OR REGEXP_REPLACE(S_PHONE, '[^0-9]', '') = ''
            THEN '9999999999'
            ELSE REGEXP_REPLACE(S_PHONE, '[^0-9]', '')
        END AS S_PHONE,

        -- Negative or null balance → 0
        CASE
            WHEN S_ACCTBAL IS NULL OR S_ACCTBAL < 0 THEN 0
            ELSE S_ACCTBAL
        END AS S_ACCTBAL,

        -- Null/blank comment → DEFAULT COMMENT
        COALESCE(NULLIF(TRIM(S_COMMENT), ''), 'DEFAULT COMMENT') AS S_COMMENT
    FROM {{ source('silver_layer','supplier_stg') }}
),

-- Remove invalid rows
filtered AS (
    SELECT *
    FROM cleaned
    WHERE S_NATIONKEY IS NOT NULL
),

-- Deduplicate suppliers
dedup AS (
    SELECT *,
        ROW_NUMBER() OVER (PARTITION BY S_SUPPKEY ORDER BY S_SUPPKEY DESC) AS rn
    FROM filtered
)

SELECT
    S_SUPPKEY,
    S_NAME,
    S_ADDRESS,
    S_NATIONKEY,
    S_PHONE,
    S_ACCTBAL,
    S_COMMENT
FROM dedup
