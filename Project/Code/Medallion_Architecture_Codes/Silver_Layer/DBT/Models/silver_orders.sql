{{ config(materialized="table",alias='ORDERS_DBT_TEMP') }}

-- 1. MEDIAN CUSTOMER KEY
with median_custkey AS (
    SELECT MEDIAN(O_CUSTKEY) AS MEDIAN_CUSTKEY
    FROM {{ source('silver_layer','silver_orders') }}
    WHERE O_CUSTKEY IS NOT NULL
),

-- 2. MODE ORDER STATUS
mode_status AS (
    SELECT O_ORDERSTATUS
    FROM {{ source('silver_layer','silver_orders') }}
    WHERE O_ORDERSTATUS IS NOT NULL
      AND TRIM(O_ORDERSTATUS) <> ''
    GROUP BY O_ORDERSTATUS
    ORDER BY COUNT(*) DESC
    LIMIT 1
),

-- 3. MODE ORDER DATE
mode_orderdate AS (
    SELECT O_ORDERDATE
    FROM {{ source('silver_layer','silver_orders') }}
    WHERE TRY_TO_DATE(O_ORDERDATE) IS NOT NULL
    GROUP BY O_ORDERDATE
    ORDER BY COUNT(*) DESC
    LIMIT 1
),

-- 4. MAIN CLEANING
cleaned AS (
    SELECT
        O_ORDERKEY,

        COALESCE(
            O_CUSTKEY,
            (SELECT MEDIAN_CUSTKEY FROM median_custkey)
        ) AS O_CUSTKEY,

        COALESCE(
            NULLIF(TRIM(O_ORDERSTATUS), ''),
            (SELECT O_ORDERSTATUS FROM mode_status)
        ) AS O_ORDERSTATUS,

        CASE 
            WHEN O_TOTALPRICE < 0 THEN 0
            ELSE COALESCE(O_TOTALPRICE, 0)
        END AS O_TOTALPRICE,

        COALESCE(
            TRY_TO_DATE(O_ORDERDATE),
            (SELECT O_ORDERDATE FROM mode_orderdate)
        ) AS O_ORDERDATE,

        COALESCE(NULLIF(TRIM(O_ORDERPRIORITY), ''), 'UNKNOWN') AS O_ORDERPRIORITY,
        COALESCE(NULLIF(TRIM(O_CLERK), ''), 'CLERK_UNKNOWN') AS O_CLERK,

        CASE 
            WHEN O_SHIPPRIORITY < 0 THEN 0
            ELSE COALESCE(O_SHIPPRIORITY, 0)
        END AS O_SHIPPRIORITY,

        COALESCE(NULLIF(TRIM(O_COMMENT), ''), 'DEFAULT COMMENT') AS O_COMMENT

    FROM {{ source('silver_layer','orders_stg') }}
),

-- 5. DEDUPLICATION
dedup AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY O_ORDERKEY ORDER BY O_ORDERKEY DESC) AS rn
    FROM cleaned
)

-- 6. FINAL OUTPUT
SELECT
    O_ORDERKEY,
    O_CUSTKEY,
    O_ORDERSTATUS,
    O_TOTALPRICE,
    O_ORDERDATE,
    O_ORDERPRIORITY,
    O_CLERK,
    O_SHIPPRIORITY,
    O_COMMENT
FROM dedup