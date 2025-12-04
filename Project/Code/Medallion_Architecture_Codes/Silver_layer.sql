USE DATABASE RETAIL_DB;
USE SCHEMA SILVER_LAYER;



CREATE OR REPLACE TABLE AUDIT_LOGS (
    LOG_TIME TIMESTAMP,
    PROCESS_NAME STRING,
    STEP_NAME STRING,
    DATASET_NAME STRING,
    ROW_COUNT_BEFORE NUMBER,
    ROW_COUNT_AFTER NUMBER,
    STATUS STRING,
    MESSAGE STRING
);

select * from audit_logs;

select * from bronze_raw.customer_bronze_stream;


CREATE OR REPLACE PROCEDURE RETAIL_DB.SILVER_LAYER.CREATE_STG_TABLES_AND_STREAMS()
RETURNS STRING
LANGUAGE SQL
AS
$$
BEGIN
-- CREATE STG TABLES
CREATE OR REPLACE TABLE SILVER_LAYER.CUSTOMER_STG LIKE BRONZE_RAW.CUSTOMER_RAW;
CREATE OR REPLACE TABLE SILVER_LAYER.ORDERS_STG LIKE BRONZE_RAW.ORDERS_RAW;
CREATE OR REPLACE TABLE SILVER_LAYER.LINEITEM_STG LIKE BRONZE_RAW.LINEITEM_RAW;
CREATE OR REPLACE TABLE SILVER_LAYER.SUPPLIER_STG LIKE BRONZE_RAW.SUPPLIER_RAW;
CREATE OR REPLACE TABLE SILVER_LAYER.PART_STG LIKE BRONZE_RAW.PART_RAW;
CREATE OR REPLACE TABLE SILVER_LAYER.PARTSUPP_STG LIKE BRONZE_RAW.PARTSUPP_RAW;
CREATE OR REPLACE TABLE SILVER_LAYER.NATION_STG LIKE BRONZE_RAW.NATION_RAW;
CREATE OR REPLACE TABLE SILVER_LAYER.REGION_STG LIKE BRONZE_RAW.REGION_RAW;

-- DROP OLD STREAMS
DROP STREAM IF EXISTS SILVER_LAYER.CUSTOMER_STG_STREAM;
DROP STREAM IF EXISTS SILVER_LAYER.ORDERS_STG_STREAM;
DROP STREAM IF EXISTS SILVER_LAYER.LINEITEM_STG_STREAM;
DROP STREAM IF EXISTS SILVER_LAYER.SUPPLIER_STG_STREAM;
DROP STREAM IF EXISTS SILVER_LAYER.PART_STG_STREAM;
DROP STREAM IF EXISTS SILVER_LAYER.PARTSUPP_STG_STREAM;
DROP STREAM IF EXISTS SILVER_LAYER.NATION_STG_STREAM;
DROP STREAM IF EXISTS SILVER_LAYER.REGION_STG_STREAM;

-- CREATE NEW STREAMS
CREATE OR REPLACE STREAM SILVER_LAYER.CUSTOMER_STG_STREAM ON TABLE SILVER_LAYER.CUSTOMER_STG;
CREATE OR REPLACE STREAM SILVER_LAYER.ORDERS_STG_STREAM ON TABLE SILVER_LAYER.ORDERS_STG;
CREATE OR REPLACE STREAM SILVER_LAYER.LINEITEM_STG_STREAM ON TABLE SILVER_LAYER.LINEITEM_STG;
CREATE OR REPLACE STREAM SILVER_LAYER.SUPPLIER_STG_STREAM ON TABLE SILVER_LAYER.SUPPLIER_STG;
CREATE OR REPLACE STREAM SILVER_LAYER.PART_STG_STREAM ON TABLE SILVER_LAYER.PART_STG;
CREATE OR REPLACE STREAM SILVER_LAYER.PARTSUPP_STG_STREAM ON TABLE SILVER_LAYER.PARTSUPP_STG;
CREATE OR REPLACE STREAM SILVER_LAYER.NATION_STG_STREAM ON TABLE SILVER_LAYER.NATION_STG;
CREATE OR REPLACE STREAM SILVER_LAYER.REGION_STG_STREAM ON TABLE SILVER_LAYER.REGION_STG;

RETURN 'Staging tables and streams created successfully in SILVER_LAYER.';
END;
$$;

CALL SILVER_LAYER.CREATE_STG_TABLES_AND_STREAMS();

SELECT * FROM CUSTOMER_STG;
-- USING STAGING TABLE TO GET THE NEWLY STREAMING DATA 

CREATE OR REPLACE PROCEDURE SILVER_LAYER.LOAD_STAGING_FROM_BRONZE()
RETURNS STRING
LANGUAGE SQL
AS
$$
BEGIN

    -------------------------------------------------------------------------
    -- CUSTOMER
    -------------------------------------------------------------------------
    INSERT INTO CUSTOMER_STG
    SELECT
        C_CUSTKEY, C_NAME, C_ADDRESS, C_NATIONKEY, C_PHONE,
        C_ACCTBAL, C_MKTSEGMENT, C_COMMENT
    FROM RETAIL_DB.BRONZE_RAW.CUSTOMER_BRONZE_STREAM
    WHERE METADATA$ACTION IN ('INSERT','UPDATE');

    -------------------------------------------------------------------------
    -- SUPPLIER
    -------------------------------------------------------------------------
    INSERT INTO SUPPLIER_STG
    SELECT
        S_SUPPKEY, S_NAME, S_ADDRESS, S_NATIONKEY,
        S_PHONE, S_ACCTBAL, S_COMMENT
    FROM RETAIL_DB.BRONZE_RAW.SUPPLIER_BRONZE_STREAM
    WHERE METADATA$ACTION IN ('INSERT','UPDATE');

    -------------------------------------------------------------------------
    -- PART
    -------------------------------------------------------------------------
    INSERT INTO PART_STG
    SELECT
        P_PARTKEY, P_NAME, P_MFGR, P_BRAND, P_TYPE,
        P_SIZE, P_CONTAINER, P_RETAILPRICE, P_COMMENT
    FROM RETAIL_DB.BRONZE_RAW.PART_BRONZE_STREAM
    WHERE METADATA$ACTION IN ('INSERT','UPDATE');

    -------------------------------------------------------------------------
    -- PARTSUPP
    -------------------------------------------------------------------------
    INSERT INTO PARTSUPP_STG
    SELECT
        PS_PARTKEY, PS_SUPPKEY, PS_AVAILQTY,
        PS_SUPPLYCOST, PS_COMMENT
    FROM RETAIL_DB.BRONZE_RAW.PARTSUPP_BRONZE_STREAM
    WHERE METADATA$ACTION IN ('INSERT','UPDATE');

    -------------------------------------------------------------------------
    -- ORDERS
    -------------------------------------------------------------------------
    INSERT INTO ORDERS_STG
    SELECT
        O_ORDERKEY, O_CUSTKEY, O_ORDERSTATUS, O_TOTALPRICE,
        O_ORDERDATE, O_ORDERPRIORITY, O_CLERK,
        O_SHIPPRIORITY, O_COMMENT
    FROM RETAIL_DB.BRONZE_RAW.ORDERS_BRONZE_STREAM
    WHERE METADATA$ACTION IN ('INSERT','UPDATE');

    -------------------------------------------------------------------------
    -- LINEITEM  (16 columns FIXED)
    -------------------------------------------------------------------------
    INSERT INTO LINEITEM_STG
    SELECT
        L_ORDERKEY, L_PARTKEY, L_SUPPKEY, L_LINENUMBER,
        L_QUANTITY, L_EXTENDEDPRICE, L_DISCOUNT, L_TAX,
        L_RETURNFLAG, L_LINESTATUS,
        L_SHIPDATE, L_COMMITDATE, L_RECEIPTDATE,
        L_SHIPINSTRUCT,         -- FIXED
        L_SHIPMODE,             -- FIXED
        L_COMMENT
    FROM RETAIL_DB.BRONZE_RAW.LINEITEM_BRONZE_STREAM
    WHERE METADATA$ACTION IN ('INSERT','UPDATE');

    RETURN 'STAGING_LOAD_COMPLETED';

END;
$$;



CALL LOAD_STAGING_FROM_BRONZE();

SELECT * FROM CUSTOMER_STG;

SELECT * FROM BRONZE_RAW.CUSTOMER_BRONZE_STREAM;

SELECT * FROM RETAIL_DB.BRONZE_RAW.CUSTOMER_RAW;
-- CRETING PROCEDURE FOR SNOWPARK IMPLEMENTATION

CREATE OR REPLACE PROCEDURE SILVER_LAYER.RUN_SNOWPARK_CLEAN()
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'main'
AS
$$
import snowflake.snowpark as snowpark
from snowflake.snowpark.functions import col, trim, nullif, when, lit, current_timestamp


# -----------------------------------------------------------------------------
# AUDIT LOG FUNCTION
# -----------------------------------------------------------------------------
def log_audit(session, step_name, dataset_name, before_count, after_count, status, message):
    message_clean = (message or "").replace("'", "''")
    session.sql(f"""
        INSERT INTO RETAIL_DB.SILVER_LAYER.AUDIT_LOGS
        (LOG_TIME, PROCESS_NAME, STEP_NAME, DATASET_NAME,
         ROW_COUNT_BEFORE, ROW_COUNT_AFTER, STATUS, MESSAGE)
        VALUES (
            CURRENT_TIMESTAMP(),
            'SNOWPARK_SILVER_CLEAN',
            '{step_name}',
            '{dataset_name}',
            {before_count},
            {after_count},
            '{status}',
            '{message_clean}'
        )
    """).collect()



# -----------------------------------------------------------------------------
# CUSTOMER CLEANING
# -----------------------------------------------------------------------------
def process_customer(session):
    df = session.table("RETAIL_DB.SILVER_LAYER.CUSTOMER_STG")
    before = df.count()

    df2 = df.select(
        col("C_CUSTKEY"),
        nullif(trim(col("C_NAME")), lit("")).alias("C_NAME"),
        nullif(trim(col("C_ADDRESS")), lit("")).alias("C_ADDRESS"),
        col("C_NATIONKEY"),
        when(nullif(trim(col("C_PHONE")), lit("")).is_null(), lit("NOT PROVIDED"))
            .otherwise(nullif(trim(col("C_PHONE")), lit(""))).alias("C_PHONE"),
        when(col("C_ACCTBAL").is_null() | (col("C_ACCTBAL") < 0), 0).otherwise(col("C_ACCTBAL")).alias("C_ACCTBAL"),
        nullif(trim(col("C_MKTSEGMENT")), lit("")).alias("C_MKTSEGMENT"),
        nullif(trim(col("C_COMMENT")), lit("")).alias("C_COMMENT"),
        current_timestamp().alias("CREATED_AT"),
        lit("PARQUET").alias("SOURCE_SYSTEM")
    )

    df2.write.mode("overwrite").save_as_table("RETAIL_DB.SILVER_LAYER.CUSTOMER_STG")
    after = session.table("RETAIL_DB.SILVER_LAYER.CUSTOMER_STG").count()
    log_audit(session, "CLEAN_CUSTOMER", "CUSTOMER_STG", before, after, "SUCCESS", "")



# -----------------------------------------------------------------------------
# SUPPLIER CLEANING
# -----------------------------------------------------------------------------
def process_supplier(session):
    df = session.table("RETAIL_DB.SILVER_LAYER.SUPPLIER_STG")
    before = df.count()

    df2 = df.select(
        col("S_SUPPKEY"),
        nullif(trim(col("S_NAME")), lit("")).alias("S_NAME"),
        nullif(trim(col("S_ADDRESS")), lit("")).alias("S_ADDRESS"),
        col("S_NATIONKEY"),
        when(nullif(trim(col("S_PHONE")), lit("")).is_null(), lit("9999999999"))
            .otherwise(nullif(trim(col("S_PHONE")), lit(""))).alias("S_PHONE"),
        when(col("S_ACCTBAL").is_null() | (col("S_ACCTBAL") < 0), 0).otherwise(col("S_ACCTBAL")).alias("S_ACCTBAL"),
        when(nullif(trim(col("S_COMMENT")), lit("")).is_null(), lit("DEFAULT COMMENT"))
            .otherwise(nullif(trim(col("S_COMMENT")), lit(""))).alias("S_COMMENT"),
        current_timestamp().alias("CREATED_AT"),
        lit("PARQUET").alias("SOURCE_SYSTEM")
    )

    df2 = df2.filter(col("S_NATIONKEY").is_not_null())
    df2.write.mode("overwrite").save_as_table("RETAIL_DB.SILVER_LAYER.SUPPLIER_STG")

    after = session.table("RETAIL_DB.SILVER_LAYER.SUPPLIER_STG").count()
    log_audit(session, "CLEAN_SUPPLIER", "SUPPLIER_STG", before, after, "SUCCESS", "")



# -----------------------------------------------------------------------------
# PART CLEANING
# -----------------------------------------------------------------------------
def process_part(session):
    df = session.table("RETAIL_DB.SILVER_LAYER.PART_STG")
    before = df.count()

    df2 = df.select(
        col("P_PARTKEY"),
        nullif(trim(col("P_NAME")), lit("")).alias("P_NAME"),
        nullif(trim(col("P_MFGR")), lit("")).alias("P_MFGR"),
        nullif(trim(col("P_BRAND")), lit("")).alias("P_BRAND"),
        nullif(trim(col("P_TYPE")), lit("")).alias("P_TYPE"),
        col("P_SIZE"),
        nullif(trim(col("P_CONTAINER")), lit("")).alias("P_CONTAINER"),
        when(col("P_RETAILPRICE").is_null() | (col("P_RETAILPRICE") < 0), 0)
            .otherwise(col("P_RETAILPRICE")).alias("P_RETAILPRICE"),
        nullif(trim(col("P_COMMENT")), lit("")).alias("P_COMMENT"),
        current_timestamp().alias("CREATED_AT"),
        lit("PARQUET").alias("SOURCE_SYSTEM")
    )

    df2.write.mode("overwrite").save_as_table("RETAIL_DB.SILVER_LAYER.PART_STG")
    after = session.table("RETAIL_DB.SILVER_LAYER.PART_STG").count()
    log_audit(session, "CLEAN_PART", "PART_STG", before, after, "SUCCESS", "")



# -----------------------------------------------------------------------------
# PARTSUPP CLEANING
# -----------------------------------------------------------------------------
def process_partsupp(session):
    df = session.table("RETAIL_DB.SILVER_LAYER.PARTSUPP_STG")
    before = df.count()

    df2 = df.select(
        col("PS_PARTKEY"),
        col("PS_SUPPKEY"),
        col("PS_AVAILQTY"),
        when(col("PS_SUPPLYCOST").is_null() | (col("PS_SUPPLYCOST") < 0), 0)
            .otherwise(col("PS_SUPPLYCOST")).alias("PS_SUPPLYCOST"),
        nullif(trim(col("PS_COMMENT")), lit("")).alias("PS_COMMENT"),
        current_timestamp().alias("CREATED_AT"),
        lit("PARQUET").alias("SOURCE_SYSTEM")
    )

    df2.write.mode("overwrite").save_as_table("RETAIL_DB.SILVER_LAYER.PARTSUPP_STG")
    after = session.table("RETAIL_DB.SILVER_LAYER.PARTSUPP_STG").count()
    log_audit(session, "CLEAN_PARTSUPP", "PARTSUPP_STG", before, after, "SUCCESS", "")



# -----------------------------------------------------------------------------
# ORDERS CLEANING
# -----------------------------------------------------------------------------
def process_orders(session):
    df = session.table("RETAIL_DB.SILVER_LAYER.ORDERS_STG")
    before = df.count()

    df2 = df.select(
        col("O_ORDERKEY"),
        col("O_CUSTKEY"),
        nullif(trim(col("O_ORDERSTATUS")), lit("")).alias("O_ORDERSTATUS"),
        when(col("O_TOTALPRICE").is_null() | (col("O_TOTALPRICE") < 0), 0)
            .otherwise(col("O_TOTALPRICE")).alias("O_TOTALPRICE"),
        col("O_ORDERDATE"),
        nullif(trim(col("O_ORDERPRIORITY")), lit("")).alias("O_ORDERPRIORITY"),
        nullif(trim(col("O_CLERK")), lit("")).alias("O_CLERK"),
        when(col("O_SHIPPRIORITY") < 0, 0).otherwise(col("O_SHIPPRIORITY")).alias("O_SHIPPRIORITY"),
        nullif(trim(col("O_COMMENT")), lit("")).alias("O_COMMENT"),
        current_timestamp().alias("CREATED_AT"),
        lit("PARQUET").alias("SOURCE_SYSTEM")
    )

    df2.write.mode("overwrite").save_as_table("RETAIL_DB.SILVER_LAYER.ORDERS_STG")
    after = session.table("RETAIL_DB.SILVER_LAYER.ORDERS_STG").count()
    log_audit(session, "CLEAN_ORDERS", "ORDERS_STG", before, after, "SUCCESS", "")



# -----------------------------------------------------------------------------
# LINEITEM CLEANING
# -----------------------------------------------------------------------------
def process_lineitem(session):
    df = session.table("RETAIL_DB.SILVER_LAYER.LINEITEM_STG")
    before = df.count()

    df2 = df.select(
        col("L_ORDERKEY"), col("L_PARTKEY"), col("L_SUPPKEY"), col("L_LINENUMBER"),
        col("L_QUANTITY"), col("L_EXTENDEDPRICE"),
        when(col("L_DISCOUNT").is_null() | (col("L_DISCOUNT") < 0), 0).otherwise(col("L_DISCOUNT")).alias("L_DISCOUNT"),
        when(col("L_TAX").is_null() | (col("L_TAX") < 0), 0).otherwise(col("L_TAX")).alias("L_TAX"),
        nullif(trim(col("L_RETURNFLAG")), lit("")).alias("L_RETURNFLAG"),
        nullif(trim(col("L_LINESTATUS")), lit("")).alias("L_LINESTATUS"),
        col("L_SHIPDATE"), col("L_COMMITDATE"), col("L_RECEIPTDATE"),
        nullif(trim(col("L_SHIPINSTRUCT")), lit("")).alias("L_SHIPINSTRUCT"),
        nullif(trim(col("L_SHIPMODE")), lit("")).alias("L_SHIPMODE"),
        nullif(trim(col("L_COMMENT")), lit("")).alias("L_COMMENT"),
        (col("L_EXTENDEDPRICE") * (1 - col("L_DISCOUNT"))).alias("NET_PRICE"),
        current_timestamp().alias("CREATED_AT"),
        lit("PARQUET").alias("SOURCE_SYSTEM")
    )

    df2.write.mode("overwrite").save_as_table("RETAIL_DB.SILVER_LAYER.LINEITEM_STG")
    after = session.table("RETAIL_DB.SILVER_LAYER.LINEITEM_STG").count()
    log_audit(session, "CLEAN_LINEITEM", "LINEITEM_STG", before, after, "SUCCESS", "")



# -----------------------------------------------------------------------------
# NATION CLEANING
# -----------------------------------------------------------------------------
def process_nation(session):
    df = session.table("RETAIL_DB.SILVER_LAYER.NATION_STG")
    before = df.count()

    df2 = df.select(
        col("N_NATIONKEY"),
        when(nullif(trim(col("N_NAME")), lit("")).is_null(), lit("UNKNOWN_NATION"))
            .otherwise(nullif(trim(col("N_NAME")), lit(""))).alias("N_NAME"),
        col("N_REGIONKEY"),
        when(nullif(trim(col("N_COMMENT")), lit("")).is_null(), lit("DEFAULT COMMENT"))
            .otherwise(nullif(trim(col("N_COMMENT")), lit(""))).alias("N_COMMENT"),
        current_timestamp().alias("CREATED_AT"),
        lit("PARQUET").alias("SOURCE_SYSTEM")
    )

    df2 = df2.filter(col("N_REGIONKEY").is_not_null())
    df2.write.mode("overwrite").save_as_table("RETAIL_DB.SILVER_LAYER.NATION_STG")

    after = session.table("RETAIL_DB.SILVER_LAYER.NATION_STG").count()
    log_audit(session, "CLEAN_NATION", "NATION_STG", before, after, "SUCCESS", "")



# -----------------------------------------------------------------------------
# REGION CLEANING
# -----------------------------------------------------------------------------
def process_region(session):
    df = session.table("RETAIL_DB.SILVER_LAYER.REGION_STG")
    before = df.count()

    df2 = df.select(
        col("R_REGIONKEY"),
        nullif(trim(col("R_NAME")), lit("")).alias("R_NAME"),
        when(nullif(trim(col("R_COMMENT")), lit("")).is_null(), lit("DEFAULT COMMENT"))
            .otherwise(nullif(trim(col("R_COMMENT")), lit(""))).alias("R_COMMENT"),
        current_timestamp().alias("CREATED_AT"),
        lit("PARQUET").alias("SOURCE_SYSTEM")
    )

    df2.write.mode("overwrite").save_as_table("RETAIL_DB.SILVER_LAYER.REGION_STG")

    after = session.table("RETAIL_DB.SILVER_LAYER.REGION_STG").count()
    log_audit(session, "CLEAN_REGION", "REGION_STG", before, after, "SUCCESS", "")



# -----------------------------------------------------------------------------
# MAIN HANDLER
# -----------------------------------------------------------------------------
def main(session: snowpark.Session):
    try:
        process_customer(session)
        process_supplier(session)
        process_part(session)
        process_partsupp(session)
        process_orders(session)
        process_lineitem(session)
        process_nation(session)
        process_region(session)

        return "SNOWPARK_SILVER_CLEAN_SUCCESS"

    except Exception as e:
        return f"SNOWPARK_SILVER_CLEAN_FAILED: {str(e)}"
$$;




CALL SILVER_LAYER.RUN_SNOWPARK_CLEAN();


select * from silver_layer.customer_dbt_temp;

--MERGING WITH THE TANSFROMED DATA

CREATE OR REPLACE PROCEDURE SILVER_LAYER.APPEND_DBT_RESULTS()
RETURNS STRING
LANGUAGE SQL
AS
$$
BEGIN

    -------------------------------------------------------------------------
    -- CUSTOMER MERGE (UPSERT)
    -------------------------------------------------------------------------
    MERGE INTO SILVER_CUSTOMER s
    USING (
        SELECT *
        FROM (
            SELECT *,
                ROW_NUMBER() OVER (
                   PARTITION BY C_CUSTKEY
                   ORDER BY C_CUSTKEY
                ) AS dedup_rn
            FROM CUSTOMER_DBT_TEMP
        ) x
        WHERE dedup_rn = 1
    ) t
    ON s.C_CUSTKEY = t.C_CUSTKEY
    WHEN MATCHED THEN UPDATE SET
        s.C_NAME       = t.C_NAME,
        s.C_ADDRESS    = t.C_ADDRESS,
        s.C_NATIONKEY  = t.C_NATIONKEY,
        s.C_PHONE      = t.C_PHONE,
        s.C_ACCTBAL    = t.C_ACCTBAL,
        s.C_MKTSEGMENT = t.C_MKTSEGMENT,
        s.C_COMMENT    = t.C_COMMENT
    WHEN NOT MATCHED THEN
        INSERT (
            C_CUSTKEY, C_NAME, C_ADDRESS, C_NATIONKEY,
            C_PHONE, C_ACCTBAL, C_MKTSEGMENT, C_COMMENT
        )
        VALUES (
            t.C_CUSTKEY, t.C_NAME, t.C_ADDRESS, t.C_NATIONKEY,
            t.C_PHONE, t.C_ACCTBAL, t.C_MKTSEGMENT, t.C_COMMENT
        );

    -------------------------------------------------------------------------
    -- SUPPLIER MERGE
    -------------------------------------------------------------------------
    MERGE INTO SILVER_SUPPLIER s
    USING (
        SELECT *
        FROM (
            SELECT *,
                ROW_NUMBER() OVER (
                   PARTITION BY S_SUPPKEY
                   ORDER BY S_SUPPKEY
                ) AS dedup_rn
            FROM SUPPLIER_DBT_TEMP
        ) x
        WHERE dedup_rn = 1
    ) t
    ON s.S_SUPPKEY = t.S_SUPPKEY
    WHEN MATCHED THEN UPDATE SET
        s.S_NAME      = t.S_NAME,
        s.S_ADDRESS   = t.S_ADDRESS,
        s.S_NATIONKEY = t.S_NATIONKEY,
        s.S_PHONE     = t.S_PHONE,
        s.S_ACCTBAL   = t.S_ACCTBAL,
        s.S_COMMENT   = t.S_COMMENT
    WHEN NOT MATCHED THEN
        INSERT (
            S_SUPPKEY, S_NAME, S_ADDRESS, S_NATIONKEY,
            S_PHONE, S_ACCTBAL, S_COMMENT
        )
        VALUES (
            t.S_SUPPKEY, t.S_NAME, t.S_ADDRESS, t.S_NATIONKEY,
            t.S_PHONE, t.S_ACCTBAL, t.S_COMMENT
        );

    -------------------------------------------------------------------------
    -- PART MERGE
    -------------------------------------------------------------------------
    MERGE INTO SILVER_PART s
    USING (
        SELECT *
        FROM (
            SELECT *,
                ROW_NUMBER() OVER (
                   PARTITION BY P_PARTKEY
                   ORDER BY P_PARTKEY
                ) AS dedup_rn
            FROM PART_DBT_TEMP
        ) x
        WHERE dedup_rn = 1
    ) t
    ON s.P_PARTKEY = t.P_PARTKEY
    WHEN MATCHED THEN UPDATE SET
        s.P_NAME        = t.P_NAME,
        s.P_MFGR        = t.P_MFGR,
        s.P_BRAND       = t.P_BRAND,
        s.P_TYPE        = t.P_TYPE,
        s.P_SIZE        = t.P_SIZE,
        s.P_CONTAINER   = t.P_CONTAINER,
        s.P_RETAILPRICE = t.P_RETAILPRICE,
        s.P_COMMENT     = t.P_COMMENT
    WHEN NOT MATCHED THEN
        INSERT (
            P_PARTKEY, P_NAME, P_MFGR, P_BRAND, P_TYPE,
            P_SIZE, P_CONTAINER, P_RETAILPRICE, P_COMMENT
        )
        VALUES (
            t.P_PARTKEY, t.P_NAME, t.P_MFGR, t.P_BRAND, t.P_TYPE,
            t.P_SIZE, t.P_CONTAINER, t.P_RETAILPRICE, t.P_COMMENT
        );

    -------------------------------------------------------------------------
    -- PARTSUPP MERGE
    -------------------------------------------------------------------------
    MERGE INTO SILVER_PARTSUPP s
    USING (
        SELECT *
        FROM (
            SELECT *,
                ROW_NUMBER() OVER (
                   PARTITION BY PS_PARTKEY, PS_SUPPKEY
                   ORDER BY PS_PARTKEY, PS_SUPPKEY
                ) AS dedup_rn
            FROM PARTSUPP_DBT_TEMP
        ) x
        WHERE dedup_rn = 1
    ) t
    ON s.PS_PARTKEY = t.PS_PARTKEY
   AND s.PS_SUPPKEY = t.PS_SUPPKEY
    WHEN MATCHED THEN UPDATE SET
        s.PS_AVAILQTY   = t.PS_AVAILQTY,
        s.PS_SUPPLYCOST = t.PS_SUPPLYCOST,
        s.PS_COMMENT    = t.PS_COMMENT
    WHEN NOT MATCHED THEN
        INSERT (
            PS_PARTKEY, PS_SUPPKEY, PS_AVAILQTY,
            PS_SUPPLYCOST, PS_COMMENT
        )
        VALUES (
            t.PS_PARTKEY, t.PS_SUPPKEY, t.PS_AVAILQTY,
            t.PS_SUPPLYCOST, t.PS_COMMENT
        );

    -------------------------------------------------------------------------
    -- ORDERS MERGE
    -------------------------------------------------------------------------
    MERGE INTO SILVER_ORDERS s
    USING (
        SELECT *
        FROM (
            SELECT *,
                ROW_NUMBER() OVER (
                   PARTITION BY O_ORDERKEY
                   ORDER BY O_ORDERKEY
                ) AS dedup_rn
            FROM ORDERS_DBT_TEMP
        ) x
        WHERE dedup_rn = 1
    ) t
    ON s.O_ORDERKEY = t.O_ORDERKEY
    WHEN MATCHED THEN UPDATE SET
        s.O_CUSTKEY      = t.O_CUSTKEY,
        s.O_ORDERSTATUS  = t.O_ORDERSTATUS,
        s.O_TOTALPRICE   = t.O_TOTALPRICE,
        s.O_ORDERDATE    = t.O_ORDERDATE,
        s.O_ORDERPRIORITY= t.O_ORDERPRIORITY,
        s.O_CLERK        = t.O_CLERK,
        s.O_SHIPPRIORITY = t.O_SHIPPRIORITY,
        s.O_COMMENT      = t.O_COMMENT
    WHEN NOT MATCHED THEN
        INSERT (
            O_ORDERKEY, O_CUSTKEY, O_ORDERSTATUS,
            O_TOTALPRICE, O_ORDERDATE, O_ORDERPRIORITY,
            O_CLERK, O_SHIPPRIORITY, O_COMMENT
        )
        VALUES (
            t.O_ORDERKEY, t.O_CUSTKEY, t.O_ORDERSTATUS,
            t.O_TOTALPRICE, t.O_ORDERDATE, t.O_ORDERPRIORITY,
            t.O_CLERK, t.O_SHIPPRIORITY, t.O_COMMENT
        );

    -------------------------------------------------------------------------
    -- LINEITEM MERGE
    -------------------------------------------------------------------------
    MERGE INTO SILVER_LINEITEM s
    USING (
        SELECT *
        FROM (
            SELECT *,
                ROW_NUMBER() OVER (
                   PARTITION BY L_ORDERKEY, L_LINENUMBER
                   ORDER BY L_ORDERKEY, L_LINENUMBER
                ) AS dedup_rn
            FROM LINEITEM_DBT_TEMP
        ) x
        WHERE dedup_rn = 1
    ) t
    ON s.L_ORDERKEY   = t.L_ORDERKEY
   AND s.L_LINENUMBER = t.L_LINENUMBER
    WHEN MATCHED THEN UPDATE SET
        s.L_PARTKEY      = t.L_PARTKEY,
        s.L_SUPPKEY      = t.L_SUPPKEY,
        s.L_QUANTITY     = t.L_QUANTITY,
        s.L_EXTENDEDPRICE= t.L_EXTENDEDPRICE,
        s.L_DISCOUNT     = t.L_DISCOUNT,
        s.L_TAX          = t.L_TAX,
        s.L_RETURNFLAG   = t.L_RETURNFLAG,
        s.L_LINESTATUS   = t.L_LINESTATUS,
        s.L_SHIPDATE     = t.L_SHIPDATE,
        s.L_COMMITDATE   = t.L_COMMITDATE,
        s.L_RECEIPTDATE  = t.L_RECEIPTDATE,
        s.L_COMMENT      = t.L_COMMENT,
        s.NET_PRICE      = t.NET_PRICE
    WHEN NOT MATCHED THEN
        INSERT (
            L_ORDERKEY, L_PARTKEY, L_SUPPKEY, L_LINENUMBER,
            L_QUANTITY, L_EXTENDEDPRICE, L_DISCOUNT, L_TAX,
            L_RETURNFLAG, L_LINESTATUS, L_SHIPDATE,
            L_COMMITDATE, L_RECEIPTDATE, L_COMMENT, NET_PRICE
        )
        VALUES (
            t.L_ORDERKEY, t.L_PARTKEY, t.L_SUPPKEY, t.L_LINENUMBER,
            t.L_QUANTITY, t.L_EXTENDEDPRICE, t.L_DISCOUNT, t.L_TAX,
            t.L_RETURNFLAG, t.L_LINESTATUS, t.L_SHIPDATE,
            t.L_COMMITDATE, t.L_RECEIPTDATE, t.L_COMMENT,
            t.NET_PRICE
        );

    -------------------------------------------------------------------------
    -- NATION MERGE
    -------------------------------------------------------------------------
    MERGE INTO SILVER_NATION s
    USING (
        SELECT *
        FROM (
            SELECT *,
                ROW_NUMBER() OVER (
                   PARTITION BY N_NATIONKEY
                   ORDER BY N_NATIONKEY
                ) AS dedup_rn
            FROM NATION_DBT_TEMP
        ) x
        WHERE dedup_rn = 1
    ) t
    ON s.N_NATIONKEY = t.N_NATIONKEY
    WHEN MATCHED THEN UPDATE SET
        s.N_NAME      = t.N_NAME,
        s.N_REGIONKEY = t.N_REGIONKEY,
        s.N_COMMENT   = t.N_COMMENT
    WHEN NOT MATCHED THEN
        INSERT (
            N_NATIONKEY, N_NAME, N_REGIONKEY, N_COMMENT
        )
        VALUES (
            t.N_NATIONKEY, t.N_NAME, t.N_REGIONKEY, t.N_COMMENT
        );

    -------------------------------------------------------------------------
    -- REGION MERGE
    -------------------------------------------------------------------------
    MERGE INTO SILVER_REGION s
    USING (
        SELECT *
        FROM (
            SELECT *,
                ROW_NUMBER() OVER (
                   PARTITION BY R_REGIONKEY
                   ORDER BY R_REGIONKEY
                ) AS dedup_rn
            FROM REGION_DBT_TEMP
        ) x
        WHERE dedup_rn = 1
    ) t
    ON s.R_REGIONKEY = t.R_REGIONKEY
    WHEN MATCHED THEN UPDATE SET
        s.R_NAME    = t.R_NAME,
        s.R_COMMENT = t.R_COMMENT
    WHEN NOT MATCHED THEN
        INSERT (
            R_REGIONKEY, R_NAME, R_COMMENT
        )
        VALUES (
            t.R_REGIONKEY, t.R_NAME, t.R_COMMENT
        );

    RETURN 'MERGE_COMPLETED';

END;
$$;




CALL APPEND_DBT_RESULTS();



-- CREATING TASKS FOR PROCEDURES

--FOR TRUNCATING STAGING TABLE
CREATE OR REPLACE TASK TASK_1_CREATE_STG
  WAREHOUSE = COMPUTE_WH
  SCHEDULE = 'USING CRON */2 * * * * UTC'
AS
CALL SILVER_LAYER.CREATE_STG_TABLES_AND_STREAMS();

-- FOR LOADING FROM BRONZE STREAM TO STG TABLE
CREATE OR REPLACE TASK TASK_2_LOAD_STAGING
WAREHOUSE = COMPUTE_WH
AFTER TASK_1_CREATE_STG
AS
CALL SILVER_LAYER.LOAD_STAGING_FROM_BRONZE();

--FOR USING SNOWPARK CLEANING
CREATE OR REPLACE TASK TASK_3_SNOWPARK_CLEAN
WAREHOUSE = COMPUTE_WH
AFTER TASK_2_LOAD_STAGING
AS
CALL SILVER_LAYER.RUN_SNOWPARK_CLEAN();

--FOR MERGING THE DATA IN SILVER_MASTER
CREATE OR REPLACE TASK TASK_4_APPEND_DBT
WAREHOUSE = COMPUTE_WH
AFTER TASK_3_SNOWPARK_CLEAN
AS
CALL SILVER_LAYER.APPEND_DBT_RESULTS();


-- TO RUN THE TASKS AUTORESUME
ALTER TASK TASK_1_CREATE_STG RESUME;
ALTER TASK TASK_2_LOAD_STAGING RESUME;
ALTER TASK TASK_3_SNOWPARK_CLEAN RESUME;
ALTER TASK TASK_4_APPEND_DBT RESUME;
