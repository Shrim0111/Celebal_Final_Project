# Online Bookstore & Library Management System
## Data Engineering Capstone Project — Medallion Pipeline

**Author:** Shrim Sethi
**Internship:** Celebal Technology — Data Engineering Track
**Database:** MySQL 8 (celebal)
**Architecture:** Medallion (Bronze → Silver → Gold)

---

## 1. What this project is about

This project is about building a full data pipeline for a company that runs both an online bookstore and a public library. The company has raw data sitting in 5 operational tables (books, customers, orders, loans, reviews) and the goal is to turn that raw data into clean, trusted, business-ready data that an executive dashboard can use.

To do this, I used the **Medallion Architecture**, which breaks the pipeline into 3 layers:

| Layer | What it holds | Purpose |
|---|---|---|
| Bronze | Raw data, exact copy of source | Source of truth, nothing changed, nothing deleted |
| Silver | Cleaned and validated data | Trusted data, duplicates removed, bad rows rejected |
| Gold | Business-ready aggregates and KPIs | What the dashboard actually reads from |

<img width="1693" height="929" alt="ChatGPT Image Jul 19, 2026, 02_03_15 AM" src="https://github.com/user-attachments/assets/4a7b50dd-c650-44ff-88d9-0b52d97e99f4" />

---

## 2. Raw Data (Source Tables)

| Table | Rows | Description |
|---|---|---|
| books | 190 | Book catalog with price, stock, genre |
| customers | 2,800 | Customer master data with membership type |
| orders | 28,336 | Purchase transactions |
| loans | 9,614 | Library borrow/return records |
| reviews | 5,621 | Customer ratings and review text |

---

## 3. Bronze Layer — Raw Ingestion

### 3.1 What it does

The bronze layer is just a copy of the source tables, nothing is cleaned here. Every bronze table has two extra columns added on top of the source structure:

| Column | Type | Why |
|---|---|---|
| ingested_at | DATETIME | When this row was loaded |
| batch_id | VARCHAR | Which load run this row came from |

### 3.2 Incremental Load (Watermark Pattern)

Instead of loading all data every time, I used a **watermark pattern**. A table called `pipeline_metadata` keeps track of the last successful load time for every bronze table.

| table_name | last_loaded_at | rows_loaded | status |
|---|---|---|---|
| bronze_books | last run time | count | SUCCESS |
| bronze_customers | last run time | count | SUCCESS |
| bronze_orders | last run time | count | SUCCESS |
| bronze_loans | last run time | count | SUCCESS |
| bronze_reviews | last run time | count | SUCCESS |

Every load reads this watermark first, loads only new rows (using `order_date`, `joined_on`, `loan_date`, `created_at` as the date to compare), then updates the watermark once the load succeeds. This whole insert + update is wrapped in a transaction, so if the insert fails halfway, the watermark does not move.

### 3.3 Watermark column used per table

| Table | Watermark column | Reason |
|---|---|---|
| bronze_books | none (books don't have a load-relevant date) | uses row-existence check instead |
| bronze_customers | joined_on | new customer sign-ups |
| bronze_orders | order_date | new purchase activity |
| bronze_loans | loan_date | new borrow activity |
| bronze_reviews | created_at | new review activity |

---

## 4. Silver Layer — Cleaning & Validation

### 4.1 What it does

The silver layer reads from bronze and produces a clean version of each table. Three things happen here:

1. **Deduplicate** — if the same primary key appears more than once in bronze, only the latest one (by `ingested_at`) is kept, using `ROW_NUMBER()`.
2. **Validate** — every row is checked against a set of quality rules. Rows that fail go into `silver_rejected_rows` with a reason, rows that pass go into the silver table.
3. **Enrich** — some columns are calculated fresh, like `order_value` for orders and `days_overdue` / `overdue_category` for loans.

### 4.2 Quality rules used per table

| Table | Rule checked | Rejection reason logged |
|---|---|---|
| books | title not empty, author not empty, price > 0, stock >= 0, published_on not null | Missing Title / Missing Author / Invalid Price / Invalid Stock / Missing Published Date |
| customers | name not empty, email format valid, joined_on not null, membership not empty | Missing Name / Invalid Email / Missing Join Date / Missing Membership |
| orders | quantity > 0, order_date not null, status not empty | Invalid Quantity / Missing Order Date / Missing Status |
| loans | loan_date not null, due_date not null, due_date >= loan_date | Missing Loan Date / Missing Due Date / Invalid Due Date |
| reviews | rating between 1 and 5 | Invalid Rating |

<img width="1092" height="637" alt="Silver_rejected_rows" src="https://github.com/user-attachments/assets/e35465a6-6b48-4736-b2c5-08844de417ba" />

### 4.3 Derived / enriched columns

| Table | New column | How it is calculated |
|---|---|---|
| orders | order_value | quantity × book price |
| loans | days_overdue | days between due_date and return_date (or today, if not yet returned), never negative |
| loans | overdue_category | ON TIME (0 days) / MILD (1–5 days) / SEVERE (6–15 days) / CRITICAL (15+ days) |

### 4.4 A bug I ran into and fixed

For reviews, I initially added extra checks (review text not empty, created_at not null) that were not part of the required rules. This pushed the rejection rate for reviews up to 9.7%, which failed the < 5% healthy target. I removed the extra checks and kept only the one rule that was actually required (rating between 1 and 5). After this fix, the rejection rate for reviews dropped to about 1.76%.

**Lesson learned:** don't add validation rules that were not asked for, it only creates false rejections and makes the data quality numbers look worse than they actually are.

### 4.5 Accepted vs Rejected summary

| Table | Bronze rows | Accepted (Silver) | Rejected | Rejection % |
|---|---|---|---|---|
| bronze_books | 190 | 190 | 0 | 0.00% |
| bronze_customers | 2,800 | 2,771 | 29 | 1.04% |
| bronze_orders | 28,336 | 27,953 | 217 | 0.77% |
| bronze_loans | 9,614 | 9,538 | 76 | 0.79% |
| bronze_reviews | 5,621 | 5,522 | 99 | 1.76% |

<img width="1073" height="467" alt="Gold_pipeline_health" src="https://github.com/user-attachments/assets/27cfada4-25e5-4824-9880-f2c4f7e9424a" />


---

## 5. Gold Layer — KPI Views & Business Aggregates

The gold layer only reads from silver tables, never from bronze or the raw source. It has two types of views:

### 5.1 KPI Views (5 required)

Every KPI view returns the same shape of output: current value, target value, PASS/FAIL status, and when it was calculated.

| KPI View | What it measures | Target |
|---|---|---|
| gold_kpi_revenue_growth | Month-over-month % change in DELIVERED order revenue | ≥ 5% in any 3 consecutive months |
| gold_kpi_retention_rate | % of customers who ordered in 2 consecutive calendar months | ≥ 60% |
| gold_kpi_sell_through | % of books with at least 1 DELIVERED order | ≥ 70% |
| gold_kpi_return_compliance | % of loans returned on or before due_date | ≥ 75% |
| gold_kpi_review_coverage | % of DELIVERED orders that have a matching review | ≥ 40% |

**How each one works, in simple words:**

- **Revenue Growth** — Add up delivered order revenue for each month, then compare it with the previous month using the `LAG()` window function to get the MoM % change. The view `gold_kpi_revenue_growth` provides the monthly tracking indicators, while the overall business target ("≥ 5% in any 3 consecutive months") is verified via `gold_kpi_revenue_growth_target_check` using an islands-and-gaps pattern across consecutive PASS months.
- **Retention Rate** — Find which customers ordered in month X, then check if the same customer also ordered in month X+1 (self join on customer + next month).
- **Sell-Through** — Count how many distinct books had at least 1 delivered order, divide by the total number of books.
- **Return Compliance** — Count how many loans were returned on or before the due date, divide by total loans.
- **Review Coverage** — For every delivered order, check if a review exists for the same customer + book combination (orders and reviews don't share an order id, so this is matched on customer + book).

<img width="917" height="342" alt="Gold_retention_rate" src="https://github.com/user-attachments/assets/25fcac47-dd97-431f-97a5-2a00162a91cc" />


### 5.2 Analytical Views (2 required)

| View | What it shows |
|---|---|
| gold_top_books | Top 10 books by revenue within each genre, with total units sold and average rating |
| gold_customer_segments | Every customer classified as HIGH VALUE (> ₹20,000), MID VALUE (₹5,000–₹20,000), or LOW VALUE (< ₹5,000), based on total spend on delivered orders. Customers with zero spend are also included using a LEFT JOIN |

<img width="1086" height="648" alt="Gold_customers_segments" src="https://github.com/user-attachments/assets/3cad56b4-4dfd-442d-8cc9-a87bd553a34e" />

---

## 6. Pipeline Health & Audit

A view called `gold_pipeline_health` was built to check the health of the whole pipeline in one query. It joins bronze row counts, silver row counts, and rejected row counts for every table, and calculates a rejection rate.

**Rule:** if rejection rate for any table is above 5%, that table's status shows DEGRADED, otherwise HEALTHY.

| table_name | rows_in_bronze | rows_in_silver | rows_rejected | rejection_rate_pct | pipeline_status |
|---|---|---|---|---|---|
| bronze_books | 190 | 190 | 0 | 0.00 | HEALTHY |
| bronze_customers | 2,800 | 2,771 | 29 | 1.04 | HEALTHY |
| bronze_orders | 28,336 | 27,953 | 217 | 0.77 | HEALTHY |
| bronze_loans | 9,614 | 9,538 | 76 | 0.79 | HEALTHY |
| bronze_reviews | 5,621 | 5,522 | 99 | 1.76 | HEALTHY |

**Overall pipeline verdict:** HEALTHY (worst table rejection rate is 1.76%, well under the 5% limit)

<img width="1092" height="582" alt="Pipeline_health" src="https://github.com/user-attachments/assets/1da66683-fb06-4484-ae00-d069697b0562" />


---

---

## 7. Tech Stack Used

| Tool | Purpose |
|---|---|
| MySQL 8 | Database engine, all pipeline logic |
| Window Functions (ROW_NUMBER, LAG) | Deduplication and month-over-month comparison |
| CTEs (WITH clause) | Breaking complex KPI logic into readable steps |
| Transactions | Making bronze load safe and atomic |
| Views | All silver-to-gold business logic, kept query-ready |

---

## 8. Final Folder Structure

```
Celebal_Final_Project/
├── raw_data/
│   ├── books.csv
│   ├── customers.csv
│   ├── loans.csv
│   ├── orders.csv
│   └── reviews.csv
└── sql/
│   ├── task1_schema.sql
│   ├── task2_bronze_load.sql
│   ├── task3_silver_transform.sql
│   ├── task4_gold_views.sql
│   └── task5_audit.sql
└── screenshots/
│   ├── Bronze_layer/
│   ├── Silver_layer/
│   ├── Gold_kpi/
│   ├── Health_pipline/
└── Readme.md

```

---

## 11. Conclusion

The pipeline moves data through 3 layers, raw copy in bronze, cleaned and validated in silver, business-ready KPIs in gold. All five KPI targets are being tracked with clear PASS/FAIL logic, and the pipeline health check shows the overall data quality is well within the accepted 5% rejection limit. The main learning from this project was how small mistakes, like a missing existence check or an extra validation rule, can silently break numbers further down the pipeline, and how important it is to trace rejections back to their exact cause instead of just accepting the final count.
