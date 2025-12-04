# 🛒 Retail Sales Analytics Pipeline

A fully automated end-to-end data pipeline built using **Snowflake, Snowpipe, Streams & Tasks, Snowpark, dbt, and AWS S3**, designed to process large-scale retail sales datasets for business insights and analytics.

---

## 🚀 Architecture (Medallion)

| Layer | Technology | Purpose |
|------|------------|---------|
| **Bronze – Raw** | Snowpipe + S3 + Streams | Auto-ingest raw parquet data and track changes | 
| **Silver – Cleaned / Standardized** | Snowpark + dbt + Audit Logs | Data quality checks, dedupe, schema validation, cleansing |
| **Gold – Dimensional Model** | SCD-Type 2 + CDC + Tasks | Fact & Dim models with historical tracking and incremental loads |

📌 References:  
Bronze Layer Setup → :contentReference[oaicite:0]{index=0}  
Silver Layer ETL/DBT/Audit Logic → :contentReference[oaicite:1]{index=1}  
Gold SCD-2 & Streams/Tasks → (from Gold_layer.sql — full script truncated in preview)  
Time Travel Features → :contentReference[oaicite:2]{index=2}  

---

## 🧹 Data Quality Rules

✔ Null handling  
✔ Invalid number replacement  
✔ Phone formatting  
✔ Business rule enforcement (discount, pricing validation)  
✔ Deduplication using dbt  
✔ Row-level Audit Logging before/after every cleanup step  
✔ Referential validation in dbt tests  

Example: Silver audit log table created and updated during Snowpark execution  
→ :contentReference[oaicite:3]{index=3}

---

## 🧬 SCD Type-2 & Incremental Loads

| Entity | Method | Details |
|--------|--------|---------|
| Dimensions | Merge + history tracking | Maintain versioned customer/product details |
| Fact tables | Incremental mode | Only new or updated rows processed via Streams |

CDC + Scheduled automation via Streams & Tasks  
→ Configurations in Gold Layer SQL

---

## 📊 Analytics Outputs

Created Analytical Views for:

- Pricing Trends (Monthly, Quarterly, Yearly)
- Discount Effectiveness
- Returned Products
- Line-item Performance
- Customer and Market Segment insights  

Views Reference → Aggregated_Views.sql  
→ :contentReference[oaicite:4]{index=4}

---

## 🧠 Technology Stack

| Category | Tool |
|---------|------|
| Cloud DW | Snowflake |
| Storage | AWS S3 |
| Ingestion | Snowpipe |
| Change Data Capture | Streams |
| Orchestration | Tasks |
| Processing | Snowpark (Python) |
| Transformations | dbt |
| File Format | Parquet |

---

## 📁 Repo Contents

```text
├── Bronze_layer.sql        # Raw ingestion + Streams setup
├── Silver_layer.sql        # Snowpark cleaning + Staging loads + dbt merges
├── Gold_layer.sql          # Star schema + SCD Type-2 Dimensions + Fact Tables
├── Aggregated_Views.sql    # Analytical pricing & discount summaries
├── Time_Travel.sql         # Data retention & rollback configurations
└── Retail Sales Analysis.pdf # Case study documentation
