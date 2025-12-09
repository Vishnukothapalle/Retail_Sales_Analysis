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