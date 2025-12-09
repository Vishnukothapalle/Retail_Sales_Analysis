import snowflake.snowpark as snowpark
from snowflake.snowpark.functions import (
    col, trim, nullif, when, lit, current_timestamp
)

# ============================================================================
# AUDIT LOG FUNCTION
# ============================================================================
def log_audit(session, step_name, dataset_name, before_count, after_count, status, message):
    message_clean = message.replace("'", "''") if message else ""
    
    sql = f"""
        INSERT INTO RETAIL_DB.SILVER_LAYER.AUDIT_LOGS
        (LOG_TIME, PROCESS_NAME, STEP_NAME, DATASET_NAME,
         ROW_COUNT_BEFORE, ROW_COUNT_AFTER, STATUS, MESSAGE)
        VALUES (
            CURRENT_TIMESTAMP(),
            'SNOWPARK_SILVER_LOAD',
            '{step_name}',
            '{dataset_name}',
            {before_count},
            {after_count},
            '{status}',
            '{message_clean}'
        )
    """
    session.sql(sql).collect()


# ============================================================================
# MAIN TRANSFORMATION PIPELINE
# ============================================================================
def main(session: snowpark.Session):

    session.use_database("RETAIL_DB")
    session.use_schema("SILVER_LAYER")

    # ============================================================================
    # CUSTOMER
    # ============================================================================
    try:
        df = session.table("RETAIL_DB.BRONZE_RAW.CUSTOMER_RAW")
        before = df.count()

        df2 = df.select(
            col("C_CUSTKEY"),

            nullif(trim(col("C_NAME")), lit("")).alias("C_NAME"),
            nullif(trim(col("C_ADDRESS")), lit("")).alias("C_ADDRESS"),

            col("C_NATIONKEY"),

            when(
                nullif(trim(col("C_PHONE")), lit(""))  
                .is_null(),
                lit("NOT PROVIDED")
            ).otherwise(
                nullif(trim(col("C_PHONE")), lit(""))
            ).alias("C_PHONE"),

            when(col("C_ACCTBAL").is_null() | (col("C_ACCTBAL") < 0), 0)
                .otherwise(col("C_ACCTBAL")).alias("C_ACCTBAL"),

            nullif(trim(col("C_MKTSEGMENT")), lit("")).alias("C_MKTSEGMENT"),
            nullif(trim(col("C_COMMENT")), lit("")).alias("C_COMMENT"),

            current_timestamp().alias("CREATED_AT"),
            lit("PARQUET").alias("SOURCE_SYSTEM")
        )

        df2.write.mode("overwrite").save_as_table("SILVER_CUSTOMER")
        after = session.table("SILVER_CUSTOMER").count()

        log_audit(session, "LOAD_CUSTOMER", "CUSTOMER_RAW", before, after, "SUCCESS", "")
    except Exception as e:
        log_audit(session, "LOAD_CUSTOMER", "CUSTOMER_RAW", 0, 0, "FAILED", str(e))


    # ============================================================================
    # SUPPLIER
    # ============================================================================
    try:
        df = session.table("RETAIL_DB.BRONZE_RAW.SUPPLIER_RAW")
        before = df.count()

        df2 = df.select(
            col("S_SUPPKEY"),

            nullif(trim(col("S_NAME")), lit("")).alias("S_NAME"),
            nullif(trim(col("S_ADDRESS")), lit("")).alias("S_ADDRESS"),

            col("S_NATIONKEY"),

            when(
                nullif(trim(col("S_PHONE")), lit("")).is_null(),
                lit("9999999999")
            ).otherwise(nullif(trim(col("S_PHONE")), lit(""))).alias("S_PHONE"),

            when(col("S_ACCTBAL").is_null() | (col("S_ACCTBAL") < 0), 0)
                .otherwise(col("S_ACCTBAL")).alias("S_ACCTBAL"),

            when(
                nullif(trim(col("S_COMMENT")), lit("")).is_null(),
                lit("DEFAULT COMMENT")
            ).otherwise(nullif(trim(col("S_COMMENT")), lit(""))).alias("S_COMMENT"),

            current_timestamp().alias("CREATED_AT"),
            lit("PARQUET").alias("SOURCE_SYSTEM")
        )

        df2 = df2.filter(col("S_NATIONKEY").is_not_null())

        df2.write.mode("overwrite").save_as_table("SILVER_SUPPLIER")

        after = session.table("SILVER_SUPPLIER").count()
        log_audit(session, "LOAD_SUPPLIER", "SUPPLIER_RAW", before, after, "SUCCESS", "")
    except Exception as e:
        log_audit(session, "LOAD_SUPPLIER", "SUPPLIER_RAW", 0, 0, "FAILED", str(e))


    # ============================================================================
    # PART
    # ============================================================================
    try:
        df = session.table("RETAIL_DB.BRONZE_RAW.PART_RAW")
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

        df2.write.mode("overwrite").save_as_table("SILVER_PART")
        after = session.table("SILVER_PART").count()

        log_audit(session, "LOAD_PART", "PART_RAW", before, after, "SUCCESS", "")
    except Exception as e:
        log_audit(session, "LOAD_PART", "PART_RAW", 0, 0, "FAILED", str(e))


    # ============================================================================
    # PARTSUPP
    # ============================================================================
    try:
        df = session.table("RETAIL_DB.BRONZE_RAW.PARTSUPP_RAW")
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

        df2.write.mode("overwrite").save_as_table("SILVER_PARTSUPP")
        after = session.table("SILVER_PARTSUPP").count()

        log_audit(session, "LOAD_PARTSUPP", "PARTSUPP_RAW", before, after, "SUCCESS", "")
    except Exception as e:
        log_audit(session, "LOAD_PARTSUPP", "PARTSUPP_RAW", 0, 0, "FAILED", str(e))


    # ============================================================================
    # NATION
    # ============================================================================
    try:
        df = session.table("RETAIL_DB.BRONZE_RAW.NATION_RAW")
        before = df.count()

        df2 = df.select(
            col("N_NATIONKEY"),
            nullif(trim(col("N_NAME")), lit("")).alias("N_NAME"),
            col("N_REGIONKEY"),
            nullif(trim(col("N_COMMENT")), lit("")).alias("N_COMMENT"),
            current_timestamp().alias("CREATED_AT"),
            lit("PARQUET").alias("SOURCE_SYSTEM")
        )

        df2.write.mode("overwrite").save_as_table("SILVER_NATION")
        after = session.table("SILVER_NATION").count()

        log_audit(session, "LOAD_NATION", "NATION_RAW", before, after, "SUCCESS", "")
    except Exception as e:
        log_audit(session, "LOAD_NATION", "NATION_RAW", 0, 0, "FAILED", str(e))


    # ============================================================================
    # REGION
    # ============================================================================
    try:
        df = session.table("RETAIL_DB.BRONZE_RAW.REGION_RAW")
        before = df.count()

        df2 = df.select(
            col("R_REGIONKEY"),
            nullif(trim(col("R_NAME")), lit("")).alias("R_NAME"),

            when(
                nullif(trim(col("R_COMMENT")), lit("")).is_null(),
                lit("DEFAULT COMMENT")
            ).otherwise(nullif(trim(col("R_COMMENT")), lit(""))).alias("R_COMMENT"),

            current_timestamp().alias("CREATED_AT"),
            lit("PARQUET").alias("SOURCE_SYSTEM")
        )

        df2.write.mode("overwrite").save_as_table("SILVER_REGION")
        after = session.table("SILVER_REGION").count()

        log_audit(session, "LOAD_REGION", "REGION_RAW", before, after, "SUCCESS", "")
    except Exception as e:
        log_audit(session, "LOAD_REGION", "REGION_RAW", 0, 0, "FAILED", str(e))


    # ============================================================================
    # ORDERS
    # ============================================================================
    try:
        df = session.table("RETAIL_DB.BRONZE_RAW.ORDERS_RAW")
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

            when(col("O_SHIPPRIORITY") < 0, 0)
                .otherwise(col("O_SHIPPRIORITY")).alias("O_SHIPPRIORITY"),

            nullif(trim(col("O_COMMENT")), lit("")).alias("O_COMMENT"),

            current_timestamp().alias("CREATED_AT"),
            lit("PARQUET").alias("SOURCE_SYSTEM")
        )

        df2.write.mode("overwrite").save_as_table("SILVER_ORDERS")
        after = session.table("SILVER_ORDERS").count()

        log_audit(session, "LOAD_ORDERS", "ORDERS_RAW", before, after, "SUCCESS", "")
    except Exception as e:
        log_audit(session, "LOAD_ORDERS", "ORDERS_RAW", 0, 0, "FAILED", str(e))


    # ============================================================================
    # LINEITEM
    # ============================================================================
    try:
        df = session.table("RETAIL_DB.BRONZE_RAW.LINEITEM_RAW")
        before = df.count()

        df2 = df.select(
            col("L_ORDERKEY"),
            col("L_PARTKEY"),
            col("L_SUPPKEY"),
            col("L_LINENUMBER"),
            col("L_QUANTITY"),
            col("L_EXTENDEDPRICE"),

            when(col("L_DISCOUNT").is_null() | (col("L_DISCOUNT") < 0), 0)
                .otherwise(col("L_DISCOUNT")).alias("L_DISCOUNT"),

            when(col("L_TAX").is_null() | (col("L_TAX") < 0), 0)
                .otherwise(col("L_TAX")).alias("L_TAX"),

            nullif(trim(col("L_RETURNFLAG")), lit("")).alias("L_RETURNFLAG"),
            nullif(trim(col("L_LINESTATUS")), lit("")).alias("L_LINESTATUS"),

            col("L_SHIPDATE"),
            col("L_COMMITDATE"),
            col("L_RECEIPTDATE"),

            nullif(trim(col("L_SHIPINSTRUCT")), lit("")).alias("L_SHIPINSTRUCT"),
            nullif(trim(col("L_SHIPMODE")), lit("")).alias("L_SHIPMODE"),
            nullif(trim(col("L_COMMENT")), lit("")).alias("L_COMMENT"),

            (col("L_EXTENDEDPRICE") * (1 - col("L_DISCOUNT"))).alias("NET_PRICE"),

            current_timestamp().alias("CREATED_AT"),
            lit("PARQUET").alias("SOURCE_SYSTEM")
        )

        df2.write.mode("overwrite").save_as_table("SILVER_LINEITEM")
        after = session.table("SILVER_LINEITEM").count()

        log_audit(session, "LOAD_LINEITEM", "LINEITEM_RAW", before, after, "SUCCESS", "")
    except Exception as e:
        log_audit(session, "LOAD_LINEITEM", "LINEITEM_RAW", 0, 0, "FAILED", str(e))


    return session.create_dataframe([("SILVER LAYER COMPLETED",)], ["STATUS"])
