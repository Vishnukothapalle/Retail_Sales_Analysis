<h1 align="center">❄️ Retail Sales Analytics Pipeline</h1>

<p align="center">
  <img src="https://img.shields.io/badge/Snowflake-Data%20Cloud-blue" />
  <img src="https://img.shields.io/badge/dbt-Transformations-orange" />
  <img src="https://img.shields.io/badge/Snowpark-Python-yellow" />
  <img src="https://img.shields.io/badge/AWS-S3-ff9900" />
  <img src="https://img.shields.io/badge/PySpark-Big%20Data-red" />
</p>

<hr>

<h2>📌 Overview</h2>
<p>
A fully automated <strong>Event-Driven Retail Sales Data Pipeline</strong> built using 
<strong>Snowflake, AWS S3, AWS GLUE, PySpark, Snowpipe, Streams & Tasks, Snowpark, and dbt</strong>.  
The system ingests retail data in near real-time, cleans and validates it in the Silver layer,  
builds analytics-ready star schema models in the Gold layer, and generates
business insights supporting decisions like pricing optimization, customer segmentation,
discount effectiveness, and return analysis.
</p>

<h3>🎯 Key Goals</h3>
<ul>
  <li>Build enterprise-grade medallion architecture (Bronze → Silver → Gold)</li>
  <li>Automate ingestion, transformation & incremental CDC processing</li>
  <li>Ensure trustable data using data-quality checks + audit logs</li>
  <li>Enable fast analytical/reporting performance with star schema</li>
</ul>

<hr>

<h2>⚙️ Features</h2>
<ul>
  <li><strong>Real-time Auto-Ingestion:</strong> via Snowpipe from AWS S3 buckets</li>
  <li><strong>CDC Handling:</strong> Snowflake Streams capture newly arrived or modified rows</li>
  <li><strong>Task-Orchestrated Pipelines:</strong> scheduled & dependency-driven workflows</li>
  <li><strong>Data Quality Enforcement:</strong>
    <ul>
      <li>Missing/invalid value handling (Snowpark)</li>
      <li>dbt tests (unique, not_null, relationships)</li>
      <li>Audit logs for tracking before/after row counts</li>
    </ul>
  </li>
  <li><strong>SCD-Type 2:</strong> Maintain historical dimension changes</li>
  <li><strong>Business Mart Creation:</strong> Pricing & Revenue KPI views</li>
  <li><strong>Time Travel Enabled:</strong> rollback + historical comparison</li>
</ul>

<hr>

<h2>📊 Data Modeling (Star Schema)</h2>
<p align="center">
  Project/Data_Modelling.jpg
</p>
<p align="center">
  <em>All dimensions link directly to FACT_SALES for fast aggregation</em>
</p>

<hr>

<h2>🏗️ Medallion Architecture</h2>

<h3>🟤 Bronze Layer (Raw)</h3>
<ul>
  <li>Converting raw csv files into Parquet files by creating job in AWS GLUE using PySpark Script </li>
  <li>Landing zone for unmodified Parquet files from S3</li>
  <li>Preserves lineage + source of truth</li>
  <li>Schematized into raw ingestion tables via Snowpipe</li>
</ul>

<h3>⚪ Silver Layer (Cleaned + Validated)</h3>
<ul>
  <li>Snowpark Python performs cleansing & standardization</li>
  <li>dbt performs complex incremental transformations & deduplication</li>
  <li>Audit logs recorded for every transformation</li>
</ul>

<h3>🟡 Gold Layer (Star Schema)</h3>
<ul>
  <li>Dimensional modeling optimized for BI/Analytics</li>
  <li>SCD2 applied on Customer, Supplier, and Part Dimensions</li>
  <li>Fact table supports incremental merge using Streams</li>
</ul>

<hr>

<h2>📈 Business Analytics Outputs</h2>
<ul>
  <li>Monthly, Quarterly & Annual Sales-Revenue Trends</li>
  <li>Campaign & Pricing Effectiveness Analysis</li>
  <li>Return vs Sales Performance</li>
  <li>Product Profitability & Discount Insights</li>
  <li>Customer Segmentation & Behavioral Metrics</li>
</ul>

<hr>

<h2>🧠 Tech Stack</h2>

<table>
<thead>
<tr><th>Category</th><th>Tools / Services</th></tr>
</thead>
<tbody>
<tr><td>Cloud Data Warehouse</td><td>Snowflake</td></tr>
<tr><td>Ingestion</td><td>Snowpipe + S3 External Stage</td></tr>
<tr><td>Streaming</td><td>Snowflake Streams</td></tr>
<tr><td>Orchestration</td><td>Snowflake Tasks</td></tr>
<tr><td>Transformation</td><td>dbt + SQL + Snowpark</td></tr>
<tr><td>Data Validation</td><td>Audit Logs + dbt Tests</td></tr>
<tr><td>Retention & Recovery</td><td>Time-Travel + Fail-safe</td></tr>
</tbody>
</table>

<hr>

<h2>🔄 Pipeline Flow</h2>
<pre>
AWS S3 (Parquet Files)
        ↓
Bronze Layer → Snowpipe → Raw Tables
        ↓
Snowpark Cleansing + dbt Models
        ↓
Silver Layer → Validated & Standardized Data
        ↓
Streams + Tasks + SCD2 Merges
        ↓
Gold Layer → Star Schema (Fact & Dimension Tables)
        ↓
BI Tools / Reports / KPIs
</pre>

<hr>

<h2>📁 Repo Structure</h2>
<pre>
├── Medallion Architecture
  ├── Bronze_layer
    ├── Bronze_layer.sql
  ├── Silver_layer
    ├── silver_layer.sql
    ├── Snowpark
    ├── Dbt_codes
      ├── Models
      ├── schema.yml
  ├── Gold_Layer
    ├── Gold_Layer.sql
    ├── Aggregated_views.sql
  ├── Time_Travel
├── aws_glue.py
</pre>

<hr>

<h2>🚀 Setup (How to Run)</h2>
<ul>
  <li>Configure Snowflake + S3 External Stage</li>
  <li>Execute Bronze scripts → enable auto-ingest</li>
  <li>Run Silver cleansing procedures + dbt models</li>
  <li>Schedule Gold incremental tasks</li>
</ul>

<hr>

<h2>📊 Outcomes & Learnings</h2>
<ul>
  <li>Efficient near real-time BI reporting</li>
  <li>100% automated CDC and SCD-2 transformations</li>
  <li>High data quality and governance via audit logs + dbt</li>
  <li>Low-maintenance and scalable pipeline</li>
</ul>

<hr>

<h2>🚀 Future Enhancements</h2>
<ul>
  <li>Add Power BI / Tableau Dashboards</li>
  <li>Include ML models for sales predictions</li>
  <li>Enable anomaly detection for fraudulent returns</li>
</ul>

<hr>

<h2>🤝 Contributing</h2>
<p>Fork → Modify → Pull Request. Issues welcome!</p>

<h2>📜 License</h2>
<p>MIT License</p>

<p align="center">
💡 Designed & Developed by <strong>Vishnu Vardhan</strong>  
<br/>Data Engineering Enthusiast | India 🇮🇳
</p>
