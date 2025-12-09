{{ config(materialized="table",alias='PART_DBT_TEMP') }}

-- 1. MODE CALCULATIONS FOR MFGR, BRAND, TYPE, CONTAINER

with mode_mfgr AS (
    SELECT P_MFGR
    FROM {{ source('silver_layer','silver_part') }}
    WHERE P_MFGR IS NOT NULL AND TRIM(P_MFGR) <> ''
    GROUP BY P_MFGR
    ORDER BY COUNT(*) DESC
    LIMIT 1
),

mode_brand AS (
    SELECT P_BRAND
    FROM {{ source('silver_layer','silver_part') }}
    WHERE P_BRAND IS NOT NULL AND TRIM(P_BRAND) <> ''
    GROUP BY P_BRAND
    ORDER BY COUNT(*) DESC
    LIMIT 1
),

mode_type AS (
    SELECT P_TYPE
    FROM {{ source('silver_layer','silver_part') }}
    WHERE P_TYPE IS NOT NULL AND TRIM(P_TYPE) <> ''
    GROUP BY P_TYPE
    ORDER BY COUNT(*) DESC
    LIMIT 1
),

mode_container AS (
    SELECT P_CONTAINER
    FROM {{ source('silver_layer','silver_part') }}
    WHERE P_CONTAINER IS NOT NULL AND TRIM(P_CONTAINER) <> ''
    GROUP BY P_CONTAINER
    ORDER BY COUNT(*) DESC
    LIMIT 1
),

-- 2. CLEANING LOGIC

cleaned AS (
    SELECT
        P_PARTKEY,

        -- FIXED: SAFE fallback for P_NAME  
        COALESCE(
            NULLIF(TRIM(P_NAME), ''),
            'UNKNOWN_PART'
        ) AS P_NAME,

        -- P_MFGR cleaned
        COALESCE(
            NULLIF(TRIM(P_MFGR), ''),
            (SELECT P_MFGR FROM mode_mfgr)
        ) AS P_MFGR,

        -- P_BRAND cleaned
        COALESCE(
            NULLIF(TRIM(P_BRAND), ''),
            (SELECT P_BRAND FROM mode_brand)
        ) AS P_BRAND,

        -- P_TYPE cleaned
        COALESCE(
            NULLIF(TRIM(P_TYPE), ''),
            (SELECT P_TYPE FROM mode_type)
        ) AS P_TYPE,

        -- SIZE cleaned
        COALESCE(P_SIZE, 0) AS P_SIZE,

        -- CONTAINER cleaned
        COALESCE(
            NULLIF(TRIM(P_CONTAINER), ''),
            (SELECT P_CONTAINER FROM mode_container)
        ) AS P_CONTAINER,

        -- PRICE cleaned
        CASE
            WHEN P_RETAILPRICE IS NULL OR P_RETAILPRICE < 0 THEN 0
            ELSE P_RETAILPRICE
        END AS P_RETAILPRICE,

        -- COMMENT cleaned
        COALESCE(
            NULLIF(TRIM(P_COMMENT), ''),
            'DEFAULT COMMENT'
        ) AS P_COMMENT,

        CREATED_AT,
        SOURCE_SYSTEM

    FROM {{ source('silver_layer','part_stg') }}
),

-- 3. REMOVE DUPLICATES (KEEP latest row)
dedup AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY P_PARTKEY
            ORDER BY CREATED_AT DESC
        ) AS rn
    FROM cleaned
)

-- FINAL OUTPUT
SELECT
    P_PARTKEY,
    P_NAME,
    P_MFGR,
    P_BRAND,
    P_TYPE,
    P_SIZE,
    P_CONTAINER,
    P_RETAILPRICE,
    P_COMMENT,
    CREATED_AT,
    SOURCE_SYSTEM
FROM dedup