import streamlit as st
import altair as alt
import pandas as pd
from snowflake.snowpark.context import get_active_session

# SNOWFLAKE SESSION
session = get_active_session()

# PAGE CONFIG
st.set_page_config(
    page_title="Retail Sales Analytics Dashboard",
    layout="wide",
    initial_sidebar_state="collapsed",
)

st.markdown("""
    <h1 style='color:#E5ECF4; font-size:48px;'>📊 Retail Sales Analytics Dashboard</h1>
    <p style='color:#AAB2BD; font-size:18px;'>
        End-to-End Retail Analytics • Powered by Snowflake
    </p>
""", unsafe_allow_html=True)

# LOAD DATA
@st.cache_data(show_spinner=False)
def run_query(q):
    return session.sql(q).to_pandas()

fact = run_query("SELECT * FROM GOLD_LAYER.FACT_SALES")
missing = run_query("SELECT * FROM GOLD_LAYER.VW_MISSING_VALUE_SUMMARY")
outlier = run_query("SELECT * FROM GOLD_LAYER.VW_OUTLIER_SUMMARY")
qty_dist = run_query("SELECT * FROM GOLD_LAYER.VW_QUANTITY_DISTRIBUTION")
disc_bucket = run_query("SELECT * FROM GOLD_LAYER.VW_DISCOUNT_BUCKETS")
campaign_rate = run_query("SELECT * FROM GOLD_LAYER.VW_CAMPAIGN_SUCCESS_RATE")
campaign_drivers = run_query("SELECT * FROM GOLD_LAYER.VW_CAMPAIGN_DRIVERS")
monthly = run_query("SELECT * FROM GOLD_LAYER.VW_MONTHLY_PRICING_SUMMARY")
quarterly = run_query("SELECT * FROM GOLD_LAYER.VW_QUARTERLY_PRICING")
yearly = run_query("SELECT * FROM GOLD_LAYER.VW_YEARLY_PRICE_TRENDS")
returned = run_query("SELECT * FROM GOLD_LAYER.VW_RETURNED_PRODUCT_ANALYSIS")
disc_effect = run_query("SELECT * FROM GOLD_LAYER.VW_DISCOUNT_EFFECTIVENESS")
lineperf = run_query("SELECT * FROM GOLD_LAYER.VW_LINEITEM_PERFORMANCE")

# ========================================================
#                   TAB STRUCTURE
# ========================================================
tab1, tab2, tab3, tab4, tab5 = st.tabs([
    "📈 Overview",
    "📦 Data Quality",
    "🎯 Campaign Analysis",
    "💲 Pricing Trends",
    "🛒 Returns & Line Items"
])

# ========================================================
#                      TAB 1 — OVERVIEW
# ========================================================
with tab1:
    st.markdown("## 📈 Overall Sales Metrics")

    col1, col2, col3, col4 = st.columns(4)
    col1.metric("Total Revenue", f"$ {fact['EXTENDED_PRICE'].sum():,.2f}")
    col2.metric("Total Quantity", f"{fact['QUANTITY'].sum():,.0f}")
    col3.metric("Avg. Discount", f"{fact['DISCOUNT'].mean():.3f}")
    col4.metric("Total Sales", f"{len(fact):,}")


# ========================================================
#                    TAB 2 — DATA QUALITY
# ========================================================
with tab2:

    st.markdown("## 📦 Data Quality & Volume")
    st.markdown("### 🔍 Missing Value Summary")

    mv = missing.iloc[0]
    c1, c2, c3, c4, c5 = st.columns(5)
    c1.metric("Missing Qty", mv["MISSING_QTY"])
    c2.metric("Missing Ext Price", mv["MISSING_EXT_PRICE"])
    c3.metric("Missing Discount", mv["MISSING_DISC"])
    c4.metric("Missing Tax", mv["MISSING_TAX"])
    c5.metric("Missing Net Price", mv["MISSING_NET_PRICE"])

    st.markdown("### 📊 Quantity Distribution")
    qty_chart = alt.Chart(qty_dist).mark_bar(color="#74B9FF").encode(
        x=alt.X("QUANTITY:Q", title="Quantity"),
        y=alt.Y("CNT:Q", title="Number of rows")
    ).properties(height=300)
    st.altair_chart(qty_chart, use_container_width=True)

    st.markdown("### 🚨 Outlier Summary")
    o = outlier.iloc[0]
    oc1, oc2, oc3 = st.columns(3)
    oc1.metric("Max Qty", o["MAX_QTY"])
    oc2.metric("Max Price", f"{o['MAX_PRICE']:,.2f}")
    oc3.metric("Max Discount", o["MAX_DISC"])

    st.markdown("### 💰 Discount Bucket Summary")
    disc_chart = alt.Chart(disc_bucket).mark_bar(color="#74B9FF").encode(
        x=alt.X("DISCOUNT_BUCKET:N", title="Discount Bucket"),
        y=alt.Y("CNT:Q", title="Count")
    ).properties(height=300)
    st.altair_chart(disc_chart, use_container_width=True)


# ========================================================
#                 TAB 3 — CAMPAIGN ANALYSIS
# ========================================================
with tab3:

    st.markdown("## 🎯 Campaign Analysis")
    st.markdown("### Campaign Success Rate (%)")

    pie = alt.Chart(campaign_rate).mark_arc().encode(
        theta="PERCENTAGE",
        color="CAMPAIGN_STATUS"
    )
    st.altair_chart(pie, use_container_width=True)

    st.markdown("### 📊 Campaign Performance Metrics")

    # SUCCESS METRICS
    if "SUCCESS" in campaign_drivers["CAMPAIGN_STATUS"].values:
        succ = campaign_drivers[campaign_drivers["CAMPAIGN_STATUS"] == "SUCCESS"].iloc[0]
        c1, c2, c3 = st.columns(3)
        c1.metric("Avg Net Price (Success)", f"{succ['AVG_NET_PRICE']:,.2f}")
        c2.metric("Avg Discount (Success)", f"{succ['AVG_DISCOUNT']:.3f}")
        c3.metric("Avg Quantity (Success)", f"{succ['AVG_QUANTITY']:,.2f}")

    # FAILED METRICS
    if "FAILED" in campaign_drivers["CAMPAIGN_STATUS"].values:
        fail = campaign_drivers[campaign_drivers["CAMPAIGN_STATUS"] == "FAILED"].iloc[0]
        f1, f2, f3 = st.columns(3)
        f1.metric("Avg Net Price (Failed)", f"{fail['AVG_NET_PRICE']:,.2f}")
        f2.metric("Avg Discount (Failed)", f"{fail['AVG_DISCOUNT']:.3f}")
        f3.metric("Avg Quantity (Failed)", f"{fail['AVG_QUANTITY']:,.2f}")


# ========================================================
#                 TAB 4 — PRICING TRENDS
# ========================================================
with tab4:

    st.markdown("## 💲 Pricing Trends")

    st.markdown("### 📅 Monthly Pricing Summary")
    monthly.rename(columns={"YEAR": "YEAR_NUM"}, inplace=True)

    monthly_chart = alt.Chart(monthly).mark_line(point=True).encode(
        x=alt.X("MONTH_NAME:N", title="Month"),
        y=alt.Y("AVG_NET_PRICE:Q", title="Avg Net Price"),
        color=alt.Color("YEAR_NUM:N", title="Year")
    ).properties(height=300)
    st.altair_chart(monthly_chart, use_container_width=True)

    st.markdown("### 📅 Quarterly Pricing Analysis")
    quarter_chart = alt.Chart(quarterly).mark_bar().encode(
        x="QUARTER:O",
        y="AVG_NET_PRICE:Q",
        color="YEAR_:N"
    ).properties(height=350)
    st.altair_chart(quarter_chart, use_container_width=True)

    st.markdown("### 📉 Yearly Price Trends")
    year_chart = alt.Chart(yearly).mark_line(point=True).encode(
        x="YEAR_:O",
        y="AVG_NET_PRICE:Q",
        color="RETURNFLAG:N"
    ).properties(height=300)
    st.altair_chart(year_chart, use_container_width=True)


# ========================================================
#              TAB 5 — RETURNS & LINE ITEMS
# ========================================================
with tab5:

    st.markdown("## 🛒 Returns & Line Item Insights")

    st.subheader("📦 Returned Product Summary")
    chart_return = alt.Chart(returned).mark_arc(innerRadius=70).encode(
        theta="TOTAL_RETURNS:Q",
        color="RETURNFLAG:N",
        tooltip=["RETURNFLAG", "TOTAL_RETURNS", "AVG_RETURN_PRICE", "AVG_DISCOUNT"]
    ).properties(height=300)
    st.altair_chart(chart_return, use_container_width=True)

    st.subheader("📉 Discount Effectiveness Analysis")
    chart_disc_eff = alt.Chart(disc_effect).mark_bar().encode(
        x="RETURNFLAG:N",
        y="AVG_NET_PRICE:Q",
        color="LINESTATUS:N",
        tooltip=["RETURNFLAG", "LINESTATUS", "AVG_NET_PRICE", "TOTAL_QTY"]
    ).properties(height=350)
    st.altair_chart(chart_disc_eff, use_container_width=True)

    st.subheader("📦 Line Item Performance Comparison")
    chart_perf = alt.Chart(lineperf).mark_bar().encode(
        x="RETURNFLAG:N",
        y="TOTAL_REVENUE:Q",
        color="LINESTATUS:N",
        tooltip=["RETURNFLAG", "LINESTATUS", "TOTAL_QTY", "TOTAL_REVENUE", "AVG_NET_PRICE", "AVG_DISCOUNT"]
    ).properties(height=350)
    st.altair_chart(chart_perf, use_container_width=True)


#st.markdown("<hr><p style='text-align:center;'>Powered by Snowflake • Retail Data Analysis</p>", unsafe_allow_html=True)