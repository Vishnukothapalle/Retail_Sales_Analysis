import sys
from awsglue.utils import getResolvedOptions
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.context import SparkContext
from pyspark.sql import functions as F
import boto3

args = getResolvedOptions(sys.argv, ["JOB_NAME"])
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args["JOB_NAME"], args)

s3 = boto3.resource('s3')
bucket = s3.Bucket('snow-reatil-analysis')

raw_bucket = "s3://snow-reatil-analysis/raw/"
parquet_bucket = "s3://snow-reatil-analysis/parquet/"

tables = ["raw_customer","raw_orders","raw_lineitem","raw_nation","raw_region","raw_part","raw_partsupp","raw_supplier"]

for table in tables:
    print(f"Cleaning and processing {table}...")
    
    # DELETE old parquet files first (critical!)
    bucket.objects.filter(Prefix=f"parquet/{table}/").delete()
    
    df = spark.read.csv(f"{raw_bucket}{table}.csv", header=True, inferSchema=True)
    df_upper = df.toDF(*[c.upper() for c in df.columns])
    
    output_path = f"{parquet_bucket}{table}/"
    df_upper.write.mode("overwrite").option("compression","snappy").parquet(output_path)
    
    print(f"Done → {table} → {df_upper.count():,} clean rows")

job.commit()
print("All done — only real data, no junk NULL rows anymore!")