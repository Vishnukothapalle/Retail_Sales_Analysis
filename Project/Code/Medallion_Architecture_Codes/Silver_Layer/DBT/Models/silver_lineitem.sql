{{ config(materialized="table", alias='LINEITEM_DBT_TEMP') }}

-- 1. MODE & MEDIAN CALCULATIONS
with mode_partkey AS (
    SELECT L_PARTKEY
    FROM {{ source('silver_layer','silver_lineitem') }}
    WHERE L_PARTKEY IS NOT NULL
    GROUP BY L_PARTKEY
    ORDER BY COUNT(*) DESC
    LIMIT 1
),

mode_suppkey AS (
    SELECT L_SUPPKEY
    FROM {{ source('silver_layer','silver_lineitem') }}
    WHERE L_SUPPKEY IS NOT NULL
    GROUP BY L_SUPPKEY
    ORDER BY COUNT(*) DESC
    LIMIT 1
),

median_linenum AS (
    SELECT MEDIAN(L_LINENUMBER) AS MED_LINENUM
    FROM {{ source('silver_layer','silver_lineitem') }}
    WHERE L_LINENUMBER IS NOT NULL
),

mode_shipdate AS (
    SELECT L_SHIPDATE
    FROM {{ source('silver_layer','silver_lineitem') }}
    WHERE TRY_TO_DATE(L_SHIPDATE) IS NOT NULL
    GROUP BY L_SHIPDATE
    ORDER BY COUNT(*) DESC
    LIMIT 1
),

mode_commitdate AS (
    SELECT L_COMMITDATE
    FROM {{ source('silver_layer','silver_lineitem') }}
    WHERE TRY_TO_DATE(L_COMMITDATE) IS NOT NULL
    GROUP BY L_COMMITDATE
    ORDER BY COUNT(*) DESC
    LIMIT 1
),

mode_receiptdate AS (
    SELECT L_RECEIPTDATE
    FROM {{ source('silver_layer','silver_lineitem') }}
    WHERE TRY_TO_DATE(L_RECEIPTDATE) IS NOT NULL
    GROUP BY L_RECEIPTDATE
    ORDER BY COUNT(*) DESC
    LIMIT 1
),

-- 2. CLEANING LOGIC
cleaned AS (
    SELECT
        L_ORDERKEY,
        COALESCE(L_PARTKEY, (SELECT L_PARTKEY FROM mode_partkey)) AS L_PARTKEY,
        COALESCE(L_SUPPKEY, (SELECT L_SUPPKEY FROM mode_suppkey)) AS L_SUPPKEY,
        COALESCE(L_LINENUMBER, (SELECT MED_LINENUM FROM median_linenum)) AS L_LINENUMBER,

        COALESCE(L_QUANTITY, 0) AS L_QUANTITY,
        COALESCE(L_EXTENDEDPRICE, 0) AS L_EXTENDEDPRICE,

        CASE
            WHEN L_DISCOUNT IS NULL THEN 0
            WHEN L_DISCOUNT < 0 THEN 0
            WHEN L_DISCOUNT > 1 THEN 1
            ELSE L_DISCOUNT
        END AS CLEAN_DISCOUNT,

        CASE
            WHEN L_TAX IS NULL THEN 0
            WHEN L_TAX < 0 THEN 0
            WHEN L_TAX > 1 THEN 1
            ELSE L_TAX
        END AS CLEAN_TAX,

        COALESCE(NULLIF(TRIM(L_RETURNFLAG), ''), 'N') AS L_RETURNFLAG,
        COALESCE(NULLIF(TRIM(L_LINESTATUS), ''), 'O') AS L_LINESTATUS,

        COALESCE(TRY_TO_DATE(L_SHIPDATE), (SELECT L_SHIPDATE FROM mode_shipdate)) AS L_SHIPDATE,
        COALESCE(TRY_TO_DATE(L_COMMITDATE), (SELECT L_COMMITDATE FROM mode_commitdate)) AS L_COMMITDATE,
        COALESCE(TRY_TO_DATE(L_RECEIPTDATE), (SELECT L_RECEIPTDATE FROM mode_receiptdate)) AS L_RECEIPTDATE,

        COALESCE(NULLIF(TRIM(L_COMMENT), ''), 'DEFAULT COMMENT') AS L_COMMENT,

        -- Correct NET_PRICE using cleaned discount
        COALESCE(L_EXTENDEDPRICE, 0) * 
        (1 - CASE
                WHEN L_DISCOUNT IS NULL THEN 0
                WHEN L_DISCOUNT < 0 THEN 0
                WHEN L_DISCOUNT > 1 THEN 1
                ELSE L_DISCOUNT
             END
        ) AS NET_PRICE
    FROM {{ source('silver_layer','lineitem_stg') }}
    WHERE L_ORDERKEY IS NOT NULL
),

-- 3. FOREIGN-KEY VALIDATION (Remove invalid references)
valid_fk AS (
    SELECT c.*
    FROM cleaned c
    INNER JOIN {{ source('silver_layer','silver_orders') }}  o ON c.L_ORDERKEY = o.O_ORDERKEY
    INNER JOIN {{ source('silver_layer','silver_part') }}    p ON c.L_PARTKEY  = p.P_PARTKEY
    INNER JOIN {{ source('silver_layer','silver_supplier') }} s ON c.L_SUPPKEY = s.S_SUPPKEY
),

-- 4. REMOVE DUPLICATES
dedup AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY L_ORDERKEY, L_LINENUMBER
            ORDER BY L_ORDERKEY DESC
        ) AS rn
    FROM valid_fk
)

-- 5. FINAL OUTPUT
SELECT
    L_ORDERKEY,
    L_PARTKEY,
    L_SUPPKEY,
    L_LINENUMBER,
    L_QUANTITY,
    L_EXTENDEDPRICE,
    CLEAN_DISCOUNT AS L_DISCOUNT,
    CLEAN_TAX AS L_TAX,
    L_RETURNFLAG,
    L_LINESTATUS,
    L_SHIPDATE,
    L_COMMITDATE,
    L_RECEIPTDATE,
    L_COMMENT,
    NET_PRICE
FROM dedup