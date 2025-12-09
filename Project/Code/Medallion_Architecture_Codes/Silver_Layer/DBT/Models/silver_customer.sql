{{ config(materialized="table",alias='CUSTOMER_DBT_TEMP') }}

WITH cleaned AS (
    SELECT
        C_CUSTKEY,

        /* NAME: if NULL/empty → 'USER' */
        COALESCE(NULLIF(TRIM(C_NAME), ''), 'USER') AS C_NAME,

        /* ADDRESS: if NULL/empty → 'ADDRESS NOT PROVIDED' */
        COALESCE(NULLIF(TRIM(C_ADDRESS), ''), 'ADDRESS NOT PROVIDED') AS C_ADDRESS,

        /* NATION KEY → drop later if NULL */
        C_NATIONKEY,

        /* PHONE: keep only digits → if empty → 'NOT PROVIDED' */
        CASE 
            WHEN REGEXP_REPLACE(C_PHONE, '[^0-9]', '') IS NULL 
                 OR REGEXP_REPLACE(C_PHONE, '[^0-9]', '') = '' 
            THEN 'NOT PROVIDED'
            ELSE REGEXP_REPLACE(C_PHONE, '[^0-9]', '')
        END AS C_PHONE,

        /* ACCTBAL: negative or null → 0 */
        CASE 
            WHEN C_ACCTBAL IS NULL OR C_ACCTBAL < 0 THEN 0 
            ELSE C_ACCTBAL 
        END AS C_ACCTBAL,

        /* MKT SEGMENT: if NULL → random assignment */
        COALESCE(
            NULLIF(TRIM(C_MKTSEGMENT), ''),
            CASE 
                MOD(C_CUSTKEY, 4)
                WHEN 0 THEN 'MACHINERY'
                WHEN 1 THEN 'FURNITURE'
                WHEN 2 THEN 'BUILDING'
                ELSE 'AUTOMOBILE'
            END
        ) AS C_MKTSEGMENT,

        /* COMMENT: null → default comment */
        COALESCE(NULLIF(TRIM(C_COMMENT), ''), 'DEFAULT COMMENT') AS C_COMMENT

    FROM {{ source('silver_layer','customer_stg') }}
),

/* Remove records where NATIONKEY is NULL */
filtered AS (
    SELECT *
    FROM cleaned
    WHERE C_NATIONKEY IS NOT NULL
),

/* Deduplication */
dedup AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY C_CUSTKEY
            ORDER BY C_CUSTKEY DESC
        ) AS rn
    FROM filtered
)

SELECT
    C_CUSTKEY,
    C_NAME,
    C_ADDRESS,
    C_NATIONKEY,
    C_PHONE,
    C_ACCTBAL,
    C_MKTSEGMENT,
    C_COMMENT
FROM dedup
