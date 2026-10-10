/*
PHARMAPOINT — SALES PRODUCTIVITY & PERFORMANCE ANALYSIS
Author  : Rizal Aji Wiguna
Purpose : End-to-end SQL analysis for the PharmaPoint portfolio project.

MAIN ANALYTICAL QUESTION
How can PharmaPoint distinguish business scale from true performance across
time, regions, products, and commercial indicators?

TABLE OF CONTENTS
01. Database Setup
02. Data Understanding
03. Data Quality Validation
04. Data Preparation & Analytical View
05. Metric Definition & Company Baseline
06. Sales Trend Analysis
07. Geographic Performance Analysis
08. Product Performance Analysis
09. Commercial Analysis
10. Inventory Reliability Analysis

ANALYTICAL GUARDRAILS
- One transaction row is not interpreted as quantity sold.
- customer_name is not treated as a stable customer ID.
- Gross-to-net difference is not labeled as lost revenue.
- Correlation is not interpreted as causation.
- Repeated inventory branch-product observations are not automatically called
  duplicates.
- Inventory is excluded from the sales analytical layer because no timestamp
  exists to establish observation chronology.
*/


/*
01. DATABASE SETUP
-------------------
*/
--create schema
CREATE SCHEMA portofolio_1;
SET search_path TO portofolio_1, public;

--create table
CREATE TABLE Portofolio_1.product (
	product_id VARCHAR (20) PRIMARY KEY,
	product_name TEXT NOT NULL,
	product_category VARCHAR (20),
	price INTEGER
);

---tabel inventory:
CREATE TABLE Portofolio_1.inventory (
	inventory_ID VARCHAR (20) PRIMARY KEY,
	branch_id INTEGER,
	product_id VARCHAR (20),
	product_name TEXT,
	opname_stock INTEGER
);

---tabel kantor_cabang:
CREATE TABLE Portofolio_1.kantor_cabang (
	branch_id INTEGER PRIMARY KEY,
	branch_category VARCHAR(50),
	branch_name VARCHAR(50),
	kota VARCHAR(20),
	provinsi VARCHAR(20),
	rating NUMERIC (2,1) CHECK (rating BETWEEN 0 AND 5)
);

---tabel final_transaction:
CREATE TABLE Portofolio_1.final_transaction (
	transaction_id VARCHAR (20) PRIMARY KEY,
	date DATE,
	branch_id INTEGER,
	customer_name VARCHAR (50),
	product_id VARCHAR (20),
	price INTEGER,
	discount_percentage NUMERIC (3,2),
	rating NUMERIC (2,1) CHECK (rating BETWEEN 0 AND 5)
);

--verify import dataset
SELECT
    table_schema,
    table_name
FROM information_schema.tables
WHERE table_schema = 'portofolio_1'
  AND table_name IN (
      'product',
      'kantor_cabang',
      'final_transaction',
      'inventory'
  )
ORDER BY table_name;

SELECT
    table_name,
    ordinal_position,
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'portofolio_1'
  AND table_name IN (
      'product',
      'kantor_cabang',
      'final_transaction',
      'inventory'
  )
ORDER BY table_name, ordinal_position;

--verify column
SELECT COUNT(*) AS jumlah_kolom
FROM information_schema.columns
WHERE 
    TABLE_SCHEMA = 'portofolio_1'
    AND TABLE_NAME = 'final_transaction';
	
SELECT COUNT(*) AS jumlah_kolom
FROM information_schema.columns
WHERE
	table_schema = 'portofolio_1'
	AND TABLE_NAME = 'kantor_cabang';

SELECT COUNT(*) AS jumlah_kolom
FROM information_schema.columns
WHERE
	table_schema = 'portofolio_1'
	AND TABLE_NAME = 'product';

SELECT COUNT(*) AS jumlah_kolom
FROM information_schema.columns
WHERE
	table_schema = 'portofolio_1'
	AND TABLE_NAME = 'inventory';

--verify rows
SELECT 'product' AS table_name, COUNT(*) AS row_count
FROM portofolio_1.product
UNION ALL
SELECT 'kantor_cabang', COUNT(*)
FROM portofolio_1.kantor_cabang
UNION ALL
SELECT 'final_transaction', COUNT(*)
FROM portofolio_1.final_transaction
UNION ALL
SELECT 'inventory', COUNT(*)
FROM portofolio_1.inventory
ORDER BY table_name;

/*
02. DATA UNDERSTANDING
-------------------------------
*/

-- row table preview
SELECT * FROM portofolio_1.product LIMIT 10;
SELECT * FROM portofolio_1.kantor_cabang LIMIT 10;
SELECT * FROM portofolio_1.final_transaction LIMIT 10;
SELECT * FROM portofolio_1.inventory LIMIT 10;

-- transaction date coverage
SELECT
    MIN(date) AS min_transaction_date,
    MAX(date) AS max_transaction_date,
    COUNT(*) AS transaction_rows,
    COUNT(DISTINCT transaction_id) AS unique_transaction_ids
FROM portofolio_1.final_transaction;

-- master table cardinality
SELECT
    COUNT(*) AS product_rows,
    COUNT(DISTINCT product_id) AS unique_products,
    COUNT(DISTINCT product_category) AS product_categories
FROM portofolio_1.product;

SELECT
    COUNT(*) AS branch_rows,
    COUNT(DISTINCT branch_id) AS unique_branches,
    COUNT(DISTINCT provinsi) AS provinces,
    COUNT(DISTINCT kota) AS cities,
    COUNT(DISTINCT branch_category) AS branch_categories
FROM portofolio_1.kantor_cabang;

-- transaction grain
-----a. One row is treated as one transaction record for one product
-----b. Quantity sold and order/basket ID are not available.
SELECT
    COUNT(*) AS transaction_rows,
    COUNT(DISTINCT transaction_id) AS unique_transaction_ids,
    COUNT(DISTINCT branch_id) AS branches_in_transactions,
    COUNT(DISTINCT product_id) AS products_in_transactions
FROM portofolio_1.final_transaction;

-- Inventory Grain
-----a. Repeated branch-product observations are NOT automatically called duplicates.
-----b. Their chronology cannot be established because inventory has no timestamp.
SELECT
    COUNT(*) AS inventory_rows,
    COUNT(DISTINCT branch_id) AS inventory_branches,
    COUNT(DISTINCT product_id) AS inventory_products,
    COUNT(DISTINCT (branch_id, product_id)) AS unique_branch_product_pairs
FROM portofolio_1.inventory;

-- observation branch-product 
SELECT
    branch_id,
    product_id,
    COUNT(*) AS observation_count
FROM portofolio_1.inventory
GROUP BY branch_id, product_id
ORDER BY observation_count DESC, branch_id, product_id
LIMIT 25;

/*
03. DATA QUALITY VALIDATION
------------------------------------
*/

-- null check
SELECT
    COUNT(*) FILTER (WHERE product_id IS NULL) AS null_product_id,
    COUNT(*) FILTER (WHERE product_name IS NULL) AS null_product_name,
    COUNT(*) FILTER (WHERE product_category IS NULL) AS null_product_category,
    COUNT(*) FILTER (WHERE price IS NULL) AS null_price
FROM portofolio_1.product;

SELECT
    COUNT(*) FILTER (WHERE branch_id IS NULL) AS null_branch_id,
    COUNT(*) FILTER (WHERE branch_category IS NULL) AS null_branch_category,
    COUNT(*) FILTER (WHERE branch_name IS NULL) AS null_branch_name,
    COUNT(*) FILTER (WHERE kota IS NULL) AS null_kota,
    COUNT(*) FILTER (WHERE provinsi IS NULL) AS null_provinsi,
    COUNT(*) FILTER (WHERE rating IS NULL) AS null_rating
FROM portofolio_1.kantor_cabang;

SELECT
    COUNT(*) FILTER (WHERE transaction_id IS NULL) AS null_transaction_id,
    COUNT(*) FILTER (WHERE date IS NULL) AS null_date,
    COUNT(*) FILTER (WHERE branch_id IS NULL) AS null_branch_id,
    COUNT(*) FILTER (WHERE customer_name IS NULL) AS null_customer_name,
    COUNT(*) FILTER (WHERE product_id IS NULL) AS null_product_id,
    COUNT(*) FILTER (WHERE price IS NULL) AS null_price,
    COUNT(*) FILTER (WHERE discount_percentage IS NULL) AS null_discount,
    COUNT(*) FILTER (WHERE rating IS NULL) AS null_rating
FROM portofolio_1.final_transaction;

SELECT
    COUNT(*) FILTER (WHERE inventory_id IS NULL) AS null_inventory_id,
    COUNT(*) FILTER (WHERE branch_id IS NULL) AS null_branch_id,
    COUNT(*) FILTER (WHERE product_id IS NULL) AS null_product_id,
    COUNT(*) FILTER (WHERE product_name IS NULL) AS null_product_name,
    COUNT(*) FILTER (WHERE opname_stock IS NULL) AS null_stock
FROM portofolio_1.inventory;

-- identifier unique value
--table product
SELECT COUNT(DISTINCT product_id) AS id_unik
FROM portofolio_1.product;

SELECT product_id, COUNT(*) AS row_count
FROM portofolio_1.product
GROUP BY product_id
HAVING COUNT(*) > 1;

--table kantor_cabang
SELECT COUNT(DISTINCT branch_id) AS id_unik
FROM portofolio_1.kantor_cabang;

SELECT branch_id, COUNT(*) AS row_count
FROM portofolio_1.kantor_cabang
GROUP BY branch_id
HAVING COUNT(*) > 1;

--table final_transaction
SELECT COUNT(DISTINCT transaction_id) AS id_unik
FROM portofolio_1.final_transaction;

SELECT transaction_id, COUNT(*) AS row_count
FROM portofolio_1.final_transaction
GROUP BY transaction_id
HAVING COUNT(*) > 1;

--table inventory
SELECT COUNT(DISTINCT inventory_id) AS id_unik
FROM portofolio_1.inventory;

SELECT inventory_id, COUNT(*) AS row_count
FROM portofolio_1.inventory
GROUP BY inventory_id
HAVING COUNT(*) > 1;

-- foreign key / orphan checks
SELECT COUNT(*) AS transaction_product_orphans
FROM portofolio_1.final_transaction ft
LEFT JOIN portofolio_1.product p
    ON ft.product_id = p.product_id
WHERE p.product_id IS NULL;

SELECT COUNT(*) AS transaction_branch_orphans
FROM portofolio_1.final_transaction ft
LEFT JOIN portofolio_1.kantor_cabang kc
    ON ft.branch_id = kc.branch_id
WHERE kc.branch_id IS NULL;

SELECT COUNT(*) AS inventory_product_orphans
FROM portofolio_1.inventory i
LEFT JOIN portofolio_1.product p
    ON i.product_id = p.product_id
WHERE p.product_id IS NULL;

SELECT COUNT(*) AS inventory_branch_orphans
FROM portofolio_1.inventory i
LEFT JOIN portofolio_1.kantor_cabang kc
    ON i.branch_id = kc.branch_id
WHERE kc.branch_id IS NULL;

-- cross table consistency
SELECT COUNT(*) AS inventory_product_name_mismatches
FROM portofolio_1.inventory i
JOIN portofolio_1.product p
    ON i.product_id = p.product_id
WHERE i.product_name <> p.product_name;

SELECT COUNT(*) AS transaction_price_mismatches
FROM portofolio_1.final_transaction ft
JOIN portofolio_1.product p
    ON ft.product_id = p.product_id
WHERE ft.price <> p.price;

SELECT
    product_id,
    COUNT(DISTINCT price) AS distinct_transaction_prices
FROM portofolio_1.final_transaction
GROUP BY product_id
HAVING COUNT(DISTINCT price) > 1;

-- range validation
SELECT COUNT(*) AS invalid_transaction_price
FROM portofolio_1.final_transaction
WHERE price <= 0;

SELECT COUNT(*) AS invalid_discount
FROM portofolio_1.final_transaction
WHERE discount_percentage < 0
   OR discount_percentage > 1;

SELECT COUNT(*) AS invalid_transaction_rating
FROM portofolio_1.final_transaction
WHERE rating < 1
   OR rating > 5;

SELECT COUNT(*) AS invalid_branch_rating
FROM portofolio_1.kantor_cabang
WHERE rating < 1
   OR rating > 5;

SELECT COUNT(*) AS negative_inventory_stock
FROM portofolio_1.inventory
WHERE opname_stock < 0;

-- exact inventory row duplicate 
SELECT
    branch_id,
    product_id,
    product_name,
    opname_stock,
    COUNT(*) AS exact_row_count
FROM portofolio_1.inventory
GROUP BY branch_id, product_id, product_name, opname_stock
HAVING COUNT(*) > 1
ORDER BY exact_row_count DESC;

/*
04. DATA PREPARATION & ANALYTICAL VIEW
-----------------------------------------------
*/

-- create postgresql analytical view
CREATE OR REPLACE VIEW portofolio_1.vw_transaction_enriched AS
SELECT
    ft.transaction_id,
    ft.date AS transaction_date,
    ft.customer_name,
    ft.branch_id,
    kc.branch_name,
    kc.branch_category,
    kc.kota,
    kc.provinsi,
    kc.rating AS branch_rating,
    ft.product_id,
    p.product_name,
    p.product_category,
    ft.price,
    ft.discount_percentage,
    ft.price*(1-ft.discount_percentage) AS net_sales,
    ft.rating AS transaction_rating
FROM portofolio_1.final_transaction ft
LEFT JOIN portofolio_1.kantor_cabang kc
    ON ft.branch_id = kc.branch_id
LEFT JOIN portofolio_1.product p
    ON ft.product_id = p.product_id;

-- Validate one-row-per-transaction grain after the joins.
SELECT
    COUNT(*) AS row_count,
    COUNT(DISTINCT transaction_id) AS unique_transactions,
    COUNT(DISTINCT branch_id) AS unique_branches,
    COUNT(DISTINCT product_id) AS unique_products,
    SUM(net_sales) AS total_net_sales
FROM portofolio_1.vw_transaction_enriched;

-- create bigquery analytical view 
CREATE OR REPLACE VIEW
  `pharmapoint-portfolio.pharmapoint.vw_sales_enriched` AS
SELECT
  ft.transaction_id,
  ft.date AS transaction_date,
  ft.customer_name,
  ft.branch_id,
  kc.branch_name,
  kc.branch_category,
  kc.kota,
  kc.provinsi,
  kc.rating AS branch_rating,
  ft.product_id,
  p.product_name,
  p.product_category,
  ft.price,
  ft.discount_percentage,
  CAST(ft.price AS NUMERIC)*(1-CAST(ft.discount_percentage AS NUMERIC)) AS net_sales,
  ft.rating AS transaction_rating
FROM `pharmapoint-portfolio.pharmapoint.final_transaction` ft
LEFT JOIN `pharmapoint-portfolio.pharmapoint.kantor_cabang` kc
  ON ft.branch_id = kc.branch_id
LEFT JOIN `pharmapoint-portfolio.pharmapoint.product` p
  ON ft.product_id = p.product_id;

-- BigQuery validation:
SELECT
  COUNT(*) AS row_count,
  COUNT(DISTINCT transaction_id) AS unique_transactions,
  COUNT(DISTINCT branch_id) AS unique_branches,
  COUNT(DISTINCT product_id) AS unique_products,
  SUM(net_sales) AS total_net_sales
FROM `pharmapoint-portfolio.pharmapoint.vw_sales_enriched`;


/*
05. METRIC DEFINITION & COMPANY BASELINE
-----------------------------------------
*/

WITH baseline AS (
    SELECT
        SUM(price) AS gross_sales,
        SUM(net_sales) AS net_sales,
        COUNT(DISTINCT transaction_id) AS total_transactions,
        COUNT(DISTINCT branch_id) AS total_branches,
        COUNT(DISTINCT product_id) AS total_sku,
        AVG(discount_percentage) AS avg_discount
    FROM portofolio_1.vw_transaction_enriched
)
SELECT
    gross_sales,
    net_sales,
    gross_sales - net_sales AS gross_to_net_discount_value,
    total_transactions,
    total_branches,
    total_sku,
    net_sales / NULLIF(total_transactions, 0) AS avg_sales_per_transaction,
    net_sales / NULLIF(total_branches, 0) AS net_sales_per_branch,
    total_transactions::numeric / NULLIF(total_branches, 0) AS transactions_per_branch,
    net_sales / NULLIF(total_sku, 0) AS net_sales_per_sku,
    total_transactions::numeric / NULLIF(total_sku, 0) AS transactions_per_sku,
    avg_discount
FROM baseline;

/*
Gross Sales               = Rp347,222,312,800
Net Sales                 = Rp321,171,190,319
Gross-to-Net Difference   = Rp26.05B
Total Transactions        = 672,458
Total Branches            = 1,725
Total SKU                 = 150
Avg Sales / Transaction   = Rp477,608
Net Sales / Branch        = Rp186,186,197
Transactions / Branch     = 389.83
Net Sales / SKU           = Rp2,141,141,269
Transactions / SKU        = 4,483.05
Avg Discount              = 7.50%
*/

/*
06. SALES TREND ANALYSIS
------------------------
*/

-- sales and year-over-year change
WITH yearly AS (
    SELECT
        EXTRACT(YEAR FROM transaction_date)::int AS year,
        SUM(net_sales) AS net_sales,
        COUNT(DISTINCT transaction_id) AS total_transactions
    FROM portofolio_1.vw_transaction_enriched
    GROUP BY 1
)
SELECT
    year,
    net_sales,
    total_transactions,
    ROUND(100.0*(net_sales / NULLIF(LAG(net_sales) OVER (ORDER BY year), 0)-1),2) AS yoy_net_sales_pct,
    ROUND(100.0*(total_transactions::numeric / NULLIF(LAG(total_transactions) OVER (ORDER BY year),0)-1),2) AS yoy_transactions_pct
FROM yearly
ORDER BY 1;

/*
Net Sales:
2020 = Rp80.438B
2021 = Rp80.038B
2022 = Rp80.578B
2023 = Rp80.117B
*/

-- quarterly sales
SELECT
    DATE_TRUNC('quarter', transaction_date)::date AS quarter,
    SUM(net_sales) AS net_sales,
    COUNT(DISTINCT transaction_id) AS total_transactions,
    SUM(net_sales) / NULLIF(COUNT(DISTINCT transaction_id),0)AS avg_sales_per_transaction
FROM portofolio_1.vw_transaction_enriched
GROUP BY 1
ORDER BY 1;

-- monthly sales
SELECT
    DATE_TRUNC('month', transaction_date)::date AS month,
    SUM(net_sales) AS net_sales,
    COUNT(DISTINCT transaction_id) AS total_transactions,
    SUM(net_sales) / NULLIF(COUNT(DISTINCT transaction_id), 0)
        AS avg_sales_per_transaction
FROM portofolio_1.vw_transaction_enriched
GROUP BY 1
ORDER BY 1;


/*
07. GEOGRAPHIC PERFORMANCE ANALYSIS
-----------------------------------
*/

-- dompany producttivity benchmark
SELECT
    SUM(net_sales) / COUNT(DISTINCT branch_id) AS company_sales_per_branch,
    COUNT(DISTINCT transaction_id)::numeric / COUNT(DISTINCT branch_id) AS company_transactions_per_branch
FROM portofolio_1.vw_transaction_enriched;

/* Net Sales / Branch ≈ Rp186.186M. */

-- province performance, scale and productivity
WITH company AS (
    SELECT
        SUM(net_sales) / COUNT(DISTINCT branch_id) AS company_sales_per_branch
    FROM portofolio_1.vw_transaction_enriched
),
province AS (
    SELECT
        provinsi,
        COUNT(DISTINCT branch_id) AS total_branches,
        COUNT(DISTINCT transaction_id) AS total_transactions,
        SUM(net_sales) AS net_sales,
        SUM(net_sales) / COUNT(DISTINCT branch_id) AS net_sales_per_branch,
        COUNT(DISTINCT transaction_id)::numeric / COUNT(DISTINCT branch_id) AS transactions_per_branch,
        SUM(net_sales) / COUNT(DISTINCT transaction_id) AS avg_sales_per_transaction
    FROM portofolio_1.vw_transaction_enriched
    GROUP BY provinsi
)
SELECT
    p.*,
    c.company_sales_per_branch,
    ROUND(100.0 * (p.net_sales_per_branch / c.company_sales_per_branch - 1),2) AS pct_vs_company_avg
FROM province p
CROSS JOIN company c
ORDER BY p.net_sales DESC;
/*
Jawa Barat:
Net Sales         = Rp94.87B
Branches          = 510
Net Sales/Branch  = Rp186.02M
vs Company Avg    = -0.09%

Interpretation:
High aggregate revenue reflects network scale, not materially higher branch
productivity.
*/

-- province productivity ranking
WITH company AS (
    SELECT
        SUM(net_sales) / COUNT(DISTINCT branch_id) AS company_sales_per_branch
    FROM portofolio_1.vw_transaction_enriched
),
province AS (
    SELECT
        provinsi,
        SUM(net_sales) / COUNT(DISTINCT branch_id) AS net_sales_per_branch
    FROM portofolio_1.vw_transaction_enriched
    GROUP BY provinsi
)
SELECT
    provinsi,
    net_sales_per_branch,
    ROUND(
        100.0 * (net_sales_per_branch / company_sales_per_branch - 1),
        2
    ) AS pct_vs_company_avg
FROM province
CROSS JOIN company
ORDER BY net_sales_per_branch DESC;
/*
Observed province range:
Kalimantan Selatan = +1.85%
Sulawesi Selatan   = -1.85%
Total spread       = 3.7 percentage points
*/

-- city performance and driver diagnosis
WITH company AS (
    SELECT
        SUM(net_sales) / COUNT(DISTINCT branch_id) AS company_sales_per_branch
    FROM portofolio_1.vw_transaction_enriched
),
city AS (
    SELECT
        provinsi,
        kota,
        COUNT(DISTINCT branch_id) AS total_branches,
        COUNT(DISTINCT transaction_id) AS total_transactions,
        SUM(net_sales) AS net_sales,
        SUM(net_sales) / COUNT(DISTINCT branch_id) AS net_sales_per_branch,
        COUNT(DISTINCT transaction_id)::numeric
            / COUNT(DISTINCT branch_id) AS transactions_per_branch,
        SUM(net_sales) / COUNT(DISTINCT transaction_id)
            AS avg_sales_per_transaction
    FROM portofolio_1.vw_transaction_enriched
    GROUP BY provinsi, kota
)
SELECT
    c.*,
    ROUND(100.0 * (c.net_sales_per_branch / company_sales_per_branch - 1),2) AS pct_vs_company_avg
FROM city c
CROSS JOIN company
ORDER BY c.net_sales_per_branch DESC;

/*
findings:
Bogor   = Rp192.12M/branch | 403.47 tx/branch | Rp476.17K avg transaction
Cianjur = Rp181.54M/branch | 379.38 tx/branch | Rp478.50K avg transaction

The difference is driven more by transaction activity than transaction value.
*/

/*
08. PRODUCT PERFORMANCE ANALYSIS
-----------------------------------------
*/

-- category performance
SELECT
    product_category,
    COUNT(DISTINCT product_id) AS total_sku,
    COUNT(DISTINCT transaction_id) AS total_transactions,
    SUM(net_sales) AS net_sales,
    COUNT(DISTINCT transaction_id)::numeric / COUNT(DISTINCT product_id) AS transactions_per_sku,
    SUM(net_sales) / COUNT(DISTINCT product_id) AS net_sales_per_sku,
    SUM(net_sales) / COUNT(DISTINCT transaction_id) AS avg_sales_per_transaction,
    AVG(price) AS avg_transaction_price,
    AVG(discount_percentage) AS avg_discount
FROM portofolio_1.vw_transaction_enriched
GROUP BY 1
ORDER BY net_sales DESC;

/*
Examples:
R06   : Rp64.86B | 134,799 tx | 30 SKU | 4,493.30 tx/SKU
M01AE : Rp57.11B | 103,299 tx | 23 SKU | 4,491.26 tx/SKU
M01AB : Rp35.25B |  62,590 tx | 14 SKU | 4,470.71 tx/SKU

Across categories, Transactions/SKU ≈ 4,461 – 4,497.
*/

-- product performance
WITH product_performance AS (
    SELECT
        product_id,
        MAX(product_name) AS product_name,
        MAX(product_category) AS product_category,
        AVG(price) AS product_price,
        COUNT(DISTINCT transaction_id) AS total_transactions,
        SUM(net_sales) AS net_sales,
        AVG(discount_percentage) AS avg_discount
    FROM portofolio_1.vw_transaction_enriched
    GROUP BY product_id
)
SELECT *
FROM product_performance
ORDER BY net_sales DESC;

-- product transaction frequency
WITH product_performance AS (
    SELECT
        product_id,
        COUNT(DISTINCT transaction_id) AS total_transactions
    FROM portofolio_1.vw_transaction_enriched
    GROUP BY product_id
)
SELECT
    MIN(total_transactions) AS min_transactions_per_product,
    MAX(total_transactions) AS max_transactions_per_product,
    AVG(total_transactions) AS avg_transactions_per_product,
    STDDEV_POP(total_transactions) AS stddev_transactions_per_product,
    STDDEV_POP(total_transactions) / NULLIF(AVG(total_transactions), 0) AS coefficient_of_variation
FROM product_performance;

/*
Observed approximately:
Min / Max transactions per product = 4,330  – 4,608
Average transactions per product   = 4,483
Coefficient of variation           = 1.3%
*/

-- price vs revenue and transactions cs revenue
WITH product_performance AS (
    SELECT
        product_id,
        AVG(price) AS product_price,
        COUNT(DISTINCT transaction_id) AS total_transactions,
        SUM(net_sales) AS net_sales
    FROM portofolio_1.vw_transaction_enriched
    GROUP BY product_id
)
SELECT
    CORR(product_price, net_sales) AS corr_price_vs_net_sales,
    CORR(total_transactions, net_sales) AS corr_transactions_vs_net_sales
FROM product_performance;

/*
Observed:
Price ↔ Net Sales        = +0.9996
Transactions ↔ Net Sales = -0.1604

Interpretation:
Product revenue differences are overwhelmingly price-driven in this dataset.
Use "Highest-Revenue Product", not "Best-Selling Product", when quantity is
not available.
*/

/*
09. COMMERCIAL ANALYSIS
-----------------------
*/

-- discount vs transaction frequency - product level
WITH product_commercial AS (
    SELECT
        product_id,
        AVG(discount_percentage) AS avg_discount,
        COUNT(DISTINCT transaction_id) AS total_transactions,
        SUM(net_sales) AS net_sales
    FROM portofolio_1.vw_transaction_enriched
    GROUP BY product_id
)
SELECT
    CORR(avg_discount, total_transactions) AS corr_discount_vs_transactions,
    CORR(avg_discount, net_sales) AS corr_discount_vs_net_sales
FROM product_commercial;

/*
Observed:
Avg Discount ↔ Total Transactions = -0.131
Avg Discount ↔ Net Sales          = +0.087
*/

-- product level daya for the scatter plot
SELECT
    product_id,
    MAX(product_name) AS product_name,
    MAX(product_category) AS product_category,
    AVG(discount_percentage) AS avg_discount,
    COUNT(DISTINCT transaction_id) AS total_transactions,
    SUM(net_sales) AS net_sales
FROM portofolio_1.vw_transaction_enriched
GROUP BY product_id
ORDER BY product_id;


-- discount level
SELECT
    ROUND(discount_percentage * 100, 0) AS discount_pct,
    COUNT(DISTINCT transaction_id) AS total_transactions,
    SUM(net_sales) AS net_sales,
    SUM(net_sales) / COUNT(DISTINCT transaction_id) AS avg_sales_per_transaction
FROM portofolio_1.vw_transaction_enriched
GROUP BY ROUND(discount_percentage * 100, 0)
ORDER BY discount_pct;


-- branch rating vs sales performance 
WITH branch_performance AS (
    SELECT
        branch_id,
        MAX(branch_rating) AS branch_rating,
        SUM(net_sales) AS net_sales,
        COUNT(DISTINCT transaction_id) AS total_transactions,
        SUM(net_sales) / COUNT(DISTINCT transaction_id) AS avg_sales_per_transaction
    FROM portofolio_1.vw_transaction_enriched
    GROUP BY branch_id
)
SELECT
    CORR(branch_rating, net_sales) AS corr_rating_vs_net_sales,
    CORR(branch_rating, total_transactions) AS corr_rating_vs_transactions,
    CORR(branch_rating, avg_sales_per_transaction) AS corr_rating_vs_avg_transaction
FROM branch_performance;

/*
Observed:
Rating ↔ Net Sales       = -0.0064
Rating ↔ Transactions    = -0.0153
Rating ↔ Avg Transaction = +0.0136

Interpretation:
No meaningful linear relationship is observed. This does not prove that rating
or discount has no causal effect in a real business environment.
*/

/*
10. INVENTORY RELIABILITY ANALYSIS
----------------------------------
*/
-- overall inventory rows
SELECT
    COUNT(*) AS inventory_rows,
    COUNT(DISTINCT branch_id) AS unique_branches,
    COUNT(DISTINCT product_id) AS unique_products,
    COUNT(DISTINCT (branch_id, product_id)) AS unique_branch_product_pairs
FROM portofolio_1.inventory;

-- number of observations per branch-product pair
WITH pair_counts AS (
    SELECT
        branch_id,
        product_id,
        COUNT(*) AS observation_count
    FROM portofolio_1.inventory
    GROUP BY branch_id, product_id
)
SELECT
    COUNT(*) AS unique_branch_product_pairs,
    COUNT(*) FILTER (WHERE observation_count = 1) AS single_record_pairs,
    COUNT(*) FILTER (WHERE observation_count > 1) AS repeated_pairs,
    ROUND(100.0 * COUNT(*) FILTER (WHERE observation_count > 1)/ NULLIF(COUNT(*),0),2) AS repeated_pair_pct,
    AVG(observation_count::numeric) AS avg_observations_per_pair,
    MAX(observation_count) AS max_observations_per_pair
FROM pair_counts;

/*
Observed:
Inventory rows             = 1,035,000
Unique branch-product      =   254,004
Single-record pairs        =    19,026
Repeated pairs             =   234,978
Repeated share             ≈     92.5%
Average observations/pair  ≈      4.07
Maximum observations/pair  =        17
*/

-- distribution of observations count
WITH pair_counts AS (
    SELECT
        branch_id,
        product_id,
        COUNT(*) AS observation_count
    FROM portofolio_1.inventory
    GROUP BY branch_id, product_id
)
SELECT
    observation_count,
    COUNT(*) AS pair_count
FROM pair_counts
GROUP BY observation_count
ORDER BY observation_count;

-- most repeated branch-product pairs
SELECT
    branch_id,
    product_id,
    MAX(product_name) AS product_name,
    COUNT(*) AS observation_count,
    MIN(opname_stock) AS min_observed_stock,
    MAX(opname_stock) AS max_observed_stock
FROM portofolio_1.inventory
GROUP BY branch_id, product_id
ORDER BY observation_count DESC, branch_id, product_id
LIMIT 50;

-- verify whether a temporal field exists
---- Expected project result: no usable timestamp/date column.
SELECT
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'portofolio_1'
  AND table_name = 'inventory'
  AND (
      LOWER(column_name) LIKE '%date%'
      OR LOWER(column_name) LIKE '%time%'
      OR LOWER(column_name) LIKE '%created%'
      OR LOWER(column_name) LIKE '%updated%'
      OR LOWER(column_name) LIKE '%snapshot%'
  )
ORDER BY ordinal_position;

/*
The current dataset has no snapshot_datetime field, so this logic cannot be
implemented defensibly.
-- recommended future inventory grain 
----- 1 row = branch + product + snapshot datetime
*/


/*
Once snapshot_datetime is available, latest stock, stock movement, stock
coverage, and stock-to-sales alignment become analytically defensible.
*/
