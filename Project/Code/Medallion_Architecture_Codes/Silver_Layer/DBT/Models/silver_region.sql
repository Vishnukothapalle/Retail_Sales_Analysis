{{ config(materialized="table",alias='REGION_DBT_TEMP') }}

WITH cleaned AS (
    SELECT
        R_REGIONKEY,

        -- Clean region name
        NULLIF(TRIM(R_NAME), '') AS R_NAME,

        -- Replace missing comment with DEFAULT COMMENT
        COALESCE(NULLIF(TRIM(R_COMMENT), ''), 'DEFAULT COMMENT') AS R_COMMENT

    FROM {{ source('silver_layer','region_stg') }}
),

dedup AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY R_REGIONKEY
            ORDER BY R_REGIONKEY DESC
        ) AS rn
    FROM cleaned
)

SELECT * FROM dedup
