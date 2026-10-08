# PharmaPoint: Sales Productivity & Performance Analysis

> **Distinguishing Business Scale from True Performance**  
> End-to-end data analytics project using **PostgreSQL, BigQuery, and Looker Studio** to evaluate sales performance across time, regions, products, and commercial indicators while explicitly accounting for data limitations.

---

## Table of Contents

1. [Business Understanding](#1-business-understanding)
2. [Data Source](#2-data-source)
3. [Environment & Tech Stack](#3-environment--tech-stack)
4. [Data Quality Assessment](#4-data-quality-assessment)
5. [Data Preparation & Metric Engineering](#5-data-preparation--metric-engineering)
6. [Key Findings](#6-key-findings)
7. [Interactive Dashboard](#7-interactive-dashboard)
8. [Business Recommendations](#8-business-recommendations)
9. [Limitations & Methodology Notes](#9-limitations--methodology-notes)
10. [Repository Structure](#10-repository-structure)
11. [Conclusion](#11-conclusion)
12. [Project Artifacts](#12-project-artifacts)

---

# 1. Business Understanding

## 1.1 Business Background

PharmaPoint is a fictional pharmacy retail network operating across multiple provinces and cities in Indonesia. The project uses transaction, branch, product, and inventory data covering **1 January 2020 to 30 December 2023**.

At first glance, revenue differs substantially across regions and product categories. However, aggregate revenue alone does not reveal whether those differences reflect genuinely stronger performance or simply differences in business scale such as:

- number of branches,
- number of products/SKUs,
- transaction volume,
- and product price.

This project therefore focuses on separating **business scale** from **true operating productivity** before making any performance judgment.

## 1.2 Business Problem

Management observes large differences in revenue across regions and product categories, but does not yet know whether those differences indicate better performance or merely reflect a larger business footprint.

The analysis is designed to answer one central question:

> **Who is actually more productive after differences in business scale are taken into account?**

This question is evaluated across geography, products, commercial indicators, and data reliability.

## 1.3 Project Objectives

| # | Objective | Analysis Focus |
|---|---|---|
| 1 | Evaluate whether sales performance materially changed over time | Sales Trend |
| 2 | Distinguish regional revenue scale from branch productivity | Geographic Performance |
| 3 | Identify the structural drivers of category and product revenue | Product Performance |
| 4 | Test whether discount and branch rating are meaningfully associated with sales performance | Commercial Indicators |
| 5 | Assess whether the inventory table can reliably support stock-performance analysis | Inventory Reliability |

## 1.4 Key Business Questions

1. Did sales performance materially grow or decline during 2020–2023?
2. Are high-revenue provinces genuinely more productive, or simply larger?
3. Does regional productivity remain different after normalizing by branch count?
4. Do product categories generate more revenue because of stronger transaction frequency, a larger assortment, or higher product prices?
5. Are high-revenue products also the most frequently transacted products?
6. Do discount and branch rating show meaningful relationships with transaction performance?
7. Can the available inventory data reliably support current-stock, stock-movement, or stock-to-sales analysis?

---

# 2. Data Source

The project uses four synthetic portfolio datasets.

## 2.1 Dataset Overview

| Table | Description | Rows | Columns |
|---|---|---:|---:|
| `product` | Product master data | 150 | 4 |
| `kantor_cabang` | Branch master data | 1,725 | 6 |
| `final_transaction` | Transaction records | 672,458 | 8 |
| `inventory` | Inventory observations | 1,035,000 | 5 |
| **Total** |  | **1,709,333** |  |

**Transaction period:** `2020-01-01` to `2023-12-30`

## 2.2 Table Grain

Understanding grain was treated as a prerequisite before joining or aggregating any table.

| Table | Analytical Grain |
|---|---|
| `product` | 1 row = 1 product |
| `kantor_cabang` | 1 row = 1 branch |
| `final_transaction` | 1 row = 1 transaction record for 1 product at 1 branch/date |
| `inventory` | 1 row = 1 inventory observation for a branch-product pair; observation time is unknown |

> **Important:** The transaction table does not contain quantity sold or order-basket identifiers. Therefore, this analysis uses **transaction records**, not units sold or basket size.

## 2.3 Core Relationships

```text
product
  └── product_id
          │
          ├──────────── final_transaction
          │                  ├── transaction_id
          │                  ├── branch_id
          │                  └── product_id
          │
          └──────────── inventory
                             ├── branch_id
                             └── product_id

kantor_cabang
  └── branch_id
          │
          ├──────────── final_transaction
          └──────────── inventory
```

The `inventory` table is intentionally excluded from the main sales analytical view because repeated branch-product observations would create a one-to-many join and duplicate transaction rows.

---

# 3. Environment & Tech Stack

## 3.1 Tools

| Tool | Role in the Project |
|---|---|
| **PostgreSQL** | Database setup, data validation, transformation, metric definition, and exploratory analysis |
| **pgAdmin 4** | PostgreSQL administration, CSV import, and SQL querying |
| **Google BigQuery** | Cloud analytical layer and serving source for Looker Studio |
| **Looker Studio** | Interactive dashboard and business storytelling |
| **GitHub** | Project documentation, SQL organization, and portfolio publishing |

## 3.2 Analysis Pipeline

```text
Raw CSV Files
      ↓
PostgreSQL
      ↓
Data Understanding & Quality Assessment
      ↓
SQL Transformation & Analytical View
      ↓
Exploratory Data Analysis
      ↓
BigQuery Analytical View
      ↓
Looker Studio
      ↓
Interactive Business Dashboard
      ↓
Business Findings & Recommendations
```

## 3.3 Analytical Views

Two enriched analytical layers were used during the project:

- PostgreSQL: `portofolio_1.vw_transaction_enriched`
- BigQuery: `pharmapoint.vw_sales_enriched`

Both combine transaction data with branch and product attributes while deliberately excluding inventory.

---

# 4. Data Quality Assessment

Data quality was assessed before any business analysis was performed.

## 4.1 Quality Checks

| Check | Result |
|---|---|
| Missing values | No missing values detected in the core tables |
| Primary identifier uniqueness | No issue identified in master/transaction identifiers |
| Transaction → Product integrity | 0 orphan records |
| Transaction → Branch integrity | 0 orphan records |
| Inventory → Product integrity | 0 orphan records |
| Inventory → Branch integrity | 0 orphan records |
| Inventory product name vs master product | 0 mismatches |
| Transaction price vs master product price | 0 mismatches |
| Products with multiple transaction prices | 0 |
| Invalid transaction price | 0 |
| Invalid discount | 0 |
| Invalid transaction rating | 0 |
| Invalid branch rating | 0 |
| Invalid inventory stock | 0 |
| Inventory branch-product uniqueness | **Major limitation identified** |

## 4.2 Numeric Validity

| Field | Observed Range |
|---|---:|
| Transaction price | Rp2,100 – Rp997,500 |
| Product master price | Rp2,100 – Rp997,500 |
| Discount | 0% – 15% |
| Transaction rating | 3.0 – 5.0 |
| Branch rating | 3.9 – 5.0 |
| Inventory stock | 0 – 100 |

All values are technically valid within their expected ranges.

However:

> **Valid values do not automatically imply realistic business variation.**

Several variables are highly homogeneous, which becomes important when interpreting the later findings.

## 4.3 Inventory Grain Issue

The inventory table contains:

- **1,035,000 inventory observations**
- **254,004 unique branch-product pairs**
- **234,978 repeated branch-product pairs**
- **92.5% of branch-product pairs appear more than once**
- **4.07 observations per pair on average**
- **17 observations for the most repeated pair**

But the table does **not** contain:

- `snapshot_date`
- `inventory_date`
- `created_at`
- `updated_at`

Therefore, repeated inventory observations cannot be placed in chronological order.

This becomes a major analytical limitation later in the project.

---

# 5. Data Preparation & Metric Engineering

## 5.1 Main Sales Analytical Layer

The primary analytical dataset combines:

```text
final_transaction
        +
kantor_cabang
        +
product
        ↓
sales_enriched
```

The enriched data includes:

- transaction date,
- branch and geographic information,
- product and category information,
- price,
- discount,
- ratings,
- and calculated net sales.

### Net Sales Definition

```text
Net Sales = Price × (1 - Discount Percentage)
```

Throughout this project, **Revenue** refers to recorded **Net Sales after discount** unless explicitly stated otherwise.

## 5.2 Why Inventory Was Not Joined

A direct join between sales and inventory on:

```text
branch_id + product_id
```

would create a one-to-many relationship because most branch-product combinations appear multiple times in inventory.

This would duplicate transaction rows and inflate:

- Net Sales,
- transaction counts,
- and other sales metrics.

Therefore:

> **Inventory was analyzed separately as a data-reliability problem rather than merged into the sales fact layer.**

## 5.3 Metric Framework

The project explicitly separates **Scale** from **Productivity**.

### Scale Metrics

| Metric | Definition |
|---|---|
| Gross Sales | `SUM(price)` |
| Net Sales | `SUM(price × (1 - discount))` |
| Total Transactions | Count of transaction records |
| Total Branches | Distinct branch count |
| Total SKU | Distinct product count |

### Productivity Metrics

| Metric | Definition |
|---|---|
| Avg Sales per Transaction | Net Sales / Total Transactions |
| Net Sales per Branch | Net Sales / Total Branches |
| Transactions per Branch | Total Transactions / Total Branches |
| Net Sales per SKU | Net Sales / Total SKU |
| Transactions per SKU | Total Transactions / Total SKU |

### Commercial Indicators

| Metric | Definition |
|---|---|
| Avg Discount | Average discount percentage |
| Branch Rating | Branch-level service/experience metric |
| Transaction Rating | Transaction-level rating metric |

## 5.4 Company-Level Baseline

| KPI | Value |
|---|---:|
| Gross Sales | **Rp347.22B** |
| Net Sales | **Rp321.17B** |
| Total Transactions | **672,458** |
| Total Branches | **1,725** |
| Total SKU | **150** |
| Avg Sales per Transaction | **≈ Rp477.61K** |
| Net Sales per Branch | **≈ Rp186.19M** |
| Transactions per Branch | **≈ 389.83** |
| Net Sales per SKU | **≈ Rp2.14B** |
| Transactions per SKU | **≈ 4,483.05** |
| Avg Discount | **≈ 7.50%** |

These normalized metrics are used as internal benchmarks throughout the analysis.

---

# 6. Key Findings

## Finding 1 — Sales Stayed Flat for Four Years: Time Is Not the Main Performance Driver

### Evidence

Annual Net Sales:

| Year | Net Sales | Transactions |
|---|---:|---:|
| 2020 | Rp80.44B | 168,651 |
| 2021 | Rp80.04B | 167,697 |
| 2022 | Rp80.58B | 168,642 |
| 2023 | Rp80.12B | 167,468 |

Year-over-year Net Sales movement:

- 2021: **≈ -0.50%**
- 2022: **≈ +0.68%**
- 2023: **≈ -0.57%**

Transaction volume also changed by less than approximately ±1% year over year.

Quarterly, monthly, and daily-normalized performance remained similarly stable.

### The Insight

> **PharmaPoint did not experience meaningful sales growth or decline during the observed period.**

The apparent month-to-month fluctuations are not large enough to support a strong growth, decline, or seasonality narrative.

### Why It Matters

Time is not the main source of performance variation in this dataset.

Management attention is better directed toward:

- geographic scale,
- branch productivity,
- product structure,
- and data quality.

---

## Finding 2 — High-Revenue Regions Are Larger, Not Meaningfully More Productive

### Evidence

**Jawa Barat** is the largest region by Net Sales:

| Metric | Jawa Barat | Company Benchmark |
|---|---:|---:|
| Net Sales | **Rp94.87B** | — |
| Branches | **510** | — |
| Net Sales per Branch | **Rp186.02M** | **Rp186.19M** |
| Difference vs Benchmark | **-0.09%** | — |

Jawa Barat dominates total revenue, but its average branch productivity is almost exactly equal to the company benchmark.

### The Insight

> **Regional revenue leadership primarily reflects network scale rather than superior branch productivity.**

A province with more branches naturally generates more aggregate revenue even when its average branch performs similarly to the rest of the company.

### Why It Matters

Using **Total Net Sales alone** can misclassify:

> **large market footprint** as **better performance**.

Regional reporting should always separate absolute scale from normalized productivity.

---

## Finding 3 — Regional Productivity Differs by Only a Few Percent

### Evidence

At province level:

- Highest: **Kalimantan Selatan ≈ +1.85%** vs company average
- Lowest: **Sulawesi Selatan ≈ -1.85%** vs company average

The full province-level productivity spread is therefore only about **3.7 percentage points**.

At city level:

- **Bogor ≈ Rp192.12M Net Sales/Branch**
- **Cianjur ≈ Rp181.54M Net Sales/Branch**

City-level variation is somewhat wider than province-level variation, but still not extreme.

### Driver Diagnosis

Examples:

**Bogor**
- Transactions/Branch: ≈ 403.47
- Avg Sales/Transaction: ≈ Rp476.17K

**Cianjur**
- Transactions/Branch: ≈ 379.38
- Avg Sales/Transaction: ≈ Rp478.50K

Bogor's higher branch productivity is mainly associated with **higher transaction activity**, not dramatically higher transaction value.

### The Insight

> **Branch productivity is highly homogeneous across regions.**

Ranking differences exist, but their magnitude is small.

### Why It Matters

A #1 ranking does not necessarily indicate a materially better business.

Management should evaluate:

- magnitude,
- benchmark deviation,
- and underlying drivers,

rather than ranking alone.

---

## Finding 4 — Category Revenue Is Driven by Assortment Size and Price Mix, Not Higher Transaction Frequency

### Evidence

Transactions per SKU across categories are extremely similar:

- Minimum: **≈ 4,461**
- Maximum: **≈ 4,497**

Examples:

| Category | Net Sales | Total Transactions | SKU | Transactions/SKU |
|---|---:|---:|---:|---:|
| R06 | Rp64.86B | 134,799 | 30 | 4,493.30 |
| M01AE | Rp57.11B | 103,299 | 23 | 4,491.26 |
| N05C | Rp49.33B | 120,911 | 27 | 4,478.19 |
| M01AB | Rp35.25B | 62,590 | 14 | 4,470.71 |

Despite similar Transactions/SKU, average transaction value differs substantially:

- **M01AB ≈ Rp563K**
- **M01AE ≈ Rp553K**
- **N05C ≈ Rp408K**

### The Insight

> **Category revenue differences are mainly explained by assortment scale and product value, not stronger transaction frequency per SKU.**

A category with more SKUs naturally captures more total transactions even when each individual SKU is transacted at roughly the same frequency.

### Why It Matters

High category revenue should not automatically be interpreted as stronger demand.

Product reporting should separate:

- assortment size,
- transaction frequency,
- and price/value mix.

---

## Finding 5 — Product Revenue Is Almost Perfectly Explained by Price

### Evidence

At product level:

```text
Correlation: Product Price ↔ Net Sales ≈ +0.9996
Correlation: Total Transactions ↔ Net Sales ≈ -0.1604
```

Transaction frequency is highly homogeneous across products:

- approximately **4,330–4,608 transactions per product**

Meanwhile, product prices range from:

- **Rp2,100**
- to **Rp997,500**

Example:

A high-priced product can generate billions in revenue with roughly the same number of transaction records as a very low-priced product.

### The Insight

> **Product-level revenue differences are overwhelmingly price-driven.**

Revenue ranking is therefore not equivalent to transaction-frequency ranking.

### Why It Matters

The label:

> **Highest-Revenue Product**

is analytically safer than:

> **Best-Selling Product**

because quantity sold is unavailable and transaction counts are nearly uniform.

---

## Finding 6 — Higher Discounts and Better Ratings Do Not Explain Better Sales Performance

### Discount Evidence

```text
Correlation:
Average Discount ↔ Total Transactions ≈ -0.131
```

Average discount is also highly consistent across product categories at roughly **7.5%**.

Transaction counts across discount levels are generally similar.

### Rating Evidence

At branch level:

```text
Branch Rating ↔ Net Sales             ≈ -0.006
Branch Rating ↔ Total Transactions    ≈ -0.015
Branch Rating ↔ Avg Transaction Value ≈ +0.014
```

All three relationships are effectively near zero.

### The Insight

> **Neither discount nor branch rating shows a meaningful linear relationship with sales performance in the available data.**

### Why It Matters

Management should not assume:

```text
higher discount → more transactions
higher rating   → higher sales
```

based on this dataset.

These findings are descriptive and correlational.

They do **not** prove that discount or rating has no causal effect.

---

## Finding 7 — 1.03M Inventory Records Still Cannot Support Reliable Stock Analysis

### Evidence

| Inventory Metric | Result |
|---|---:|
| Inventory Records | **1,035,000** |
| Unique Branch-Product Pairs | **254,004** |
| Single-Record Pairs | **19,026** |
| Repeated Pairs | **234,978** |
| Repeated Pair Share | **≈ 92.5%** |
| Avg Records per Pair | **4.07** |
| Max Records per Pair | **17** |
| Inventory Timestamp | **Not Available** |

### The Insight

> **Repeated inventory observations cannot be ordered chronologically.**

The records may represent different inventory snapshots, but the dataset does not contain the timestamp required to identify which observation is earlier or later.

### Why It Matters

The current inventory table cannot reliably determine:

- current stock,
- latest stock,
- stock movement,
- stock trend,
- inventory coverage,
- overstock,
- understock,
- replenishment timing,
- or stock-to-sales alignment.

Rather than forcing an unreliable stock analysis, the inventory table is treated as a **data reliability finding**.

---

# 7. Interactive Dashboard

## 7.1 Dashboard Purpose

The Looker Studio dashboard consolidates the project findings into a single interactive analytical view.

> **The dashboard is designed as an analytical narrative, not only as a monitoring interface.**

### Dashboard Structure

**Executive KPI Layer**
- Net Sales
- Total Transactions
- Total Branches
- Total SKU
- Net Sales per Branch
- Avg Sales per Transaction

**Sales Trend**
- Monthly Net Sales Trend

**Regional Performance**
- Net Sales by Province
- Branch Productivity / Net Sales per Branch

**Product Mix**
- Net Sales contribution by Product Category

**Commercial Signal**
- Discount vs Total Transactions

## 7.2 Interactive Filters

The dashboard supports interactive exploration through:

- Date Range
- Province
- Product Category

These filters dynamically update the KPI cards and relevant charts.

## 7.3 Dashboard Preview

> Replace the relative path below with the final exported dashboard screenshot.

![PharmaPoint Dashboard](images/dashboard.png)

## 7.4 Interactive Dashboard Link

> Replace the placeholder below with the final public Looker Studio URL.

[**Open Interactive PharmaPoint Dashboard**](PASTE_LOOKER_STUDIO_LINK_HERE)

---

# 8. Business Recommendations

The recommendations below are deliberately limited to actions supported by the available evidence.

## Recommendation 1 — Separate Market Scale from Productivity

Regional performance should be reported using paired metrics.

### Scale

- Total Net Sales
- Total Transactions
- Total Branches

### Productivity

- Net Sales per Branch
- Transactions per Branch
- Avg Sales per Transaction

### Why

A large branch network can create high aggregate revenue without materially higher branch productivity.

> **Do not interpret market size as superior operating performance.**

---

## Recommendation 2 — Use Benchmarks and Magnitude, Not Ranking Alone

Province-level Net Sales per Branch differs only a few percent around the company benchmark.

Therefore, performance reporting should include:

- Net Sales per Branch,
- company average,
- and `% difference vs company average`.

A ranking of #1 versus #10 can visually exaggerate a very small underlying performance gap.

> **Rank difference is not automatically performance significance.**

---

## Recommendation 3 — Evaluate Products Across Multiple Dimensions

Product and category performance should separate:

- Revenue Contribution
- Transaction Count
- SKU Count
- Transactions per SKU
- Avg Sales per Transaction
- Product Price

This prevents high revenue from being incorrectly interpreted as high transaction demand.

> **Highest revenue should not automatically mean highest demand.**

---

## Recommendation 4 — Do Not Treat Discount and Rating as Proven Sales Levers

The current dataset provides no meaningful evidence that:

- higher discount is associated with higher transaction frequency,
- or higher branch rating is associated with better commercial performance.

Therefore:

> **No major commercial intervention should be justified solely from these relationships.**

If discount effectiveness becomes a business priority, future data should support stronger evaluation through:

- promo vs non-promo periods,
- quantity,
- margin,
- exposure,
- control/treatment groups,
- and conversion outcomes.

---

## Recommendation 5 — Add an Inventory Snapshot Timestamp

The inventory grain should be redesigned as:

```text
1 row
=
1 branch
+
1 product
+
1 snapshot datetime
```

Recommended fields:

```text
branch_id
product_id
snapshot_datetime
opname_stock
```

This would enable the inventory observations to be ordered chronologically.

Only after temporal granularity is available should the business attempt reliable analysis of:

- latest stock,
- stock movement,
- stock coverage,
- and stock-to-sales alignment.

---

# 9. Limitations & Methodology Notes

## 9.1 Synthetic Dataset Characteristics

Several dimensions show unusually homogeneous behavior:

- transaction frequency per product,
- regional branch productivity,
- discount distribution,
- and ratings.

These patterns should be interpreted as characteristics of the portfolio dataset rather than assumed to represent real pharmacy operations.

## 9.2 No Quantity Sold

The transaction table does not contain quantity.

Therefore, this project cannot reliably calculate:

- units sold,
- unit demand,
- basket volume,
- or volume-based product popularity.

`Total Transactions` refers to transaction records, not product units.

## 9.3 No Cost or Margin Data

The dataset does not contain product cost or transaction margin.

Therefore, the analysis does not make claims about:

- profit,
- gross margin,
- contribution margin,
- or discount profitability.

## 9.4 Customer Name Is Not a Customer ID

`customer_name` cannot safely be treated as a unique customer identifier.

Therefore, this project deliberately avoids unsupported analyses such as:

- retention,
- loyalty,
- repeat-customer behavior,
- churn,
- customer lifetime value,
- or RFM segmentation.

## 9.5 Inventory Has No Timestamp

Repeated branch-product observations have no temporal identifier.

Therefore:

> Inventory chronology cannot be reconstructed reliably.

## 9.6 Correlation Does Not Imply Causation

The discount and rating analyses measure statistical association, not causal impact.

For example:

```text
Correlation(Discount, Transactions) ≈ -0.131
```

does **not** mean:

> discount causes transactions to decline.

It means only that no meaningful linear relationship is observed in the available data.

## 9.7 Revenue Is Not Demand

Because price varies dramatically while transaction frequency is highly uniform, revenue is strongly price-driven.

Therefore, this project explicitly separates:

```text
Revenue Contribution
≠
Transaction Frequency
≠
Unit Demand
```

---

# 10. Repository Structure

Recommended repository organization:

```text
pharmapoint-sales-performance-analysis/
│
├── README.md
│
├── sql/
│   ├── 01_database_setup.sql
│   ├── 02_data_understanding.sql
│   ├── 03_data_quality.sql
│   ├── 04_data_preparation.sql
│   ├── 05_metric_definition.sql
│   ├── 06_sales_trend.sql
│   ├── 07_geographic_analysis.sql
│   ├── 08_product_analysis.sql
│   ├── 09_commercial_analysis.sql
│   └── 10_inventory_reliability.sql
│
├── images/
│   ├── dashboard.png
│   ├── data_model.png
│   ├── sales_trend.png
│   ├── regional_performance.png
│   ├── product_performance.png
│   └── commercial_analysis.png
│
├── presentation/
│   └── PharmaPoint_Case_Study_Presentation.pptx
│
└── docs/
    └── PharmaPoint_Technical_Documentation.docx
```

### Why This Structure?

The `README.md` communicates the **business story**.

The `sql/` directory provides the **technical evidence and reproducibility**.

The `images/` directory provides the **visual evidence** used in the case study.

The `presentation/` directory contains the recruiter/interview-ready case study.

The `docs/` directory contains the full technical documentation and learning record.

---

# 11. Conclusion

PharmaPoint's apparent performance differences are primarily structural.

### Geography

High-revenue regions are generally larger because they operate more branches, while branch-level productivity remains highly consistent.

### Products

Category revenue is largely shaped by:

- assortment size,
- and price mix,

while transaction frequency per SKU remains highly homogeneous.

At product level, revenue is almost perfectly associated with price.

### Commercial Indicators

Discount and branch rating do not meaningfully explain transaction or sales performance in the available data.

### Inventory

The inventory dataset cannot reliably support stock-performance decisions until temporal information is added.

## Final Takeaway

> **Large does not necessarily mean productive. High revenue does not necessarily mean high demand. Good analysis begins by normalizing scale, testing assumptions, and refusing to draw conclusions that the data cannot support.**

---

# 12. Project Artifacts

Replace the placeholders below after publishing the final repository and dashboard.

### Interactive Dashboard

[Looker Studio Dashboard](PASTE_LOOKER_STUDIO_LINK_HERE)

### Case Study Presentation

[PharmaPoint Case Study Presentation](presentation/PharmaPoint_Case_Study_Presentation.pptx)

### SQL Analysis

[SQL Queries](sql/)

### Technical Documentation

[Technical Documentation](docs/PharmaPoint_Technical_Documentation.docx)

---

## Author

**Rizal Aji Wiguna**

Data Analyst Portfolio Project

**Tools:** PostgreSQL · pgAdmin 4 · Google BigQuery · Looker Studio · GitHub
