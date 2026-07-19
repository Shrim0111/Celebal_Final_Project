-- 1. monthly revenue growth (MoM % change on DELIVERED orders)
-- target: >= 5% in any 3 consecutive months
CREATE OR REPLACE VIEW gold_kpi_revenue_growth AS
WITH monthly AS (
    SELECT DATE_FORMAT(order_date, '%Y-%m') AS kpi_period, SUM(order_value) AS revenue
    FROM silver_orders
    WHERE status = 'DELIVERED'
    GROUP BY DATE_FORMAT(order_date, '%Y-%m')
),
growth AS (
    SELECT kpi_period, revenue,
           LAG(revenue) OVER (ORDER BY kpi_period) AS prev_revenue
    FROM monthly
)
-- calculate growth % and mark PASS if it meets the 5% target
SELECT
    kpi_period,
    ROUND((revenue - prev_revenue) / prev_revenue * 100, 2) AS kpi_value,
    5 AS kpi_target,
    CASE
        WHEN prev_revenue IS NOT NULL AND (revenue - prev_revenue) / prev_revenue * 100 >= 5 THEN 'PASS'
        ELSE 'FAIL'
    END AS status,
    NOW() AS calculated_at
FROM growth
WHERE prev_revenue IS NOT NULL
ORDER BY kpi_period;

-------------------------------------------------------------------------------------------------------

-- 2. customer retention rate (% of active customers who ordered in 2 consecutive months)
-- target: >= 60%
CREATE OR REPLACE VIEW gold_kpi_retention_rate AS
WITH customer_months AS (
    SELECT DISTINCT customer_id, DATE_FORMAT(order_date, '%Y-%m') AS ym
    FROM silver_orders
),
consecutive_customers AS (
    SELECT DISTINCT a.customer_id
    FROM customer_months a
    JOIN customer_months b
      ON a.customer_id = b.customer_id
     AND b.ym = DATE_FORMAT(DATE_ADD(STR_TO_DATE(CONCAT(a.ym, '-01'), '%Y-%m-%d'), INTERVAL 1 MONTH), '%Y-%m')
)
--  retained customers divided by all active customers, checked against 60% target
SELECT
    ROUND((SELECT COUNT(*) FROM consecutive_customers)
          / (SELECT COUNT(DISTINCT customer_id) FROM customer_months) * 100, 2) AS kpi_value,
    60 AS kpi_target,
    CASE
        WHEN (SELECT COUNT(*) FROM consecutive_customers)
             / (SELECT COUNT(DISTINCT customer_id) FROM customer_months) * 100 >= 60 THEN 'PASS'
        ELSE 'FAIL'
    END AS status,
    NOW() AS calculated_at;
    
    ---------------------------------------------------------------------------------
    
-- 3. book sell-through rate (% of books with at least 1 DELIVERED order)
-- target: >= 70%
CREATE OR REPLACE VIEW gold_kpi_sell_through AS
SELECT
    ROUND(sold.sold_books / total.total_books * 100, 2) AS kpi_value,
    70 AS kpi_target,
    CASE WHEN sold.sold_books / total.total_books * 100 >= 70 THEN 'PASS' ELSE 'FAIL' END AS status,
    NOW() AS calculated_at
FROM
    (SELECT COUNT(DISTINCT book_id) AS sold_books FROM silver_orders WHERE status = 'DELIVERED') sold,
    (SELECT COUNT(*) AS total_books FROM silver_books) total;
---------------------------------------------------------------------------------------------------------------

-- 4. library return compliance (% loans returned on or before due_date)
-- target: >= 75%
CREATE OR REPLACE VIEW gold_kpi_return_compliance AS
SELECT
    ROUND(compliant.compliant_loans / total.total_loans * 100, 2) AS kpi_value,
    75 AS kpi_target,
    CASE WHEN compliant.compliant_loans / total.total_loans * 100 >= 75 THEN 'PASS' ELSE 'FAIL' END AS status,
    NOW() AS calculated_at
FROM
    (SELECT COUNT(*) AS compliant_loans FROM silver_loans WHERE return_date IS NOT NULL AND return_date <= due_date) compliant,
    (SELECT COUNT(*) AS total_loans FROM silver_loans) total;
-----------------------------------------------------------------------------------------------

-- 5. review coverage rate (% of DELIVERED orders that have a matching review)
-- matched on customer_id + book_id since orders and reviews don't share an id
-- target: >= 40%
CREATE OR REPLACE VIEW gold_kpi_review_coverage AS
WITH delivered AS (
    SELECT order_id, customer_id, book_id
    FROM silver_orders
    WHERE status = 'DELIVERED'
),
-- check if a review exists for same customer and book combo
covered AS (
    SELECT d.order_id
    FROM delivered d
    WHERE EXISTS (
        SELECT 1 FROM silver_reviews r
        WHERE r.customer_id = d.customer_id AND r.book_id = d.book_id
    )
)
-- covered orders divided by all delivered orders, checked against 40% target
SELECT
    ROUND((SELECT COUNT(*) FROM covered) / (SELECT COUNT(*) FROM delivered) * 100, 2) AS kpi_value,
    40 AS kpi_target,
    CASE
        WHEN (SELECT COUNT(*) FROM covered) / (SELECT COUNT(*) FROM delivered) * 100 >= 40 THEN 'PASS'
        ELSE 'FAIL'
    END AS status,
    NOW() AS calculated_at;
--------------------------------------------------------------------------------------------

CREATE OR REPLACE VIEW gold_top_books AS
SELECT
    genre,
    book_id,
    title,
    total_units_sold,
    total_revenue,
    average_rating
FROM (
    SELECT
        b.genre,
        b.book_id,
        b.title,
        SUM(o.quantity) AS total_units_sold,
        SUM(o.order_value) AS total_revenue,
        ROUND(AVG(r.rating),2) AS average_rating,
        ROW_NUMBER() OVER (
            PARTITION BY b.genre
            ORDER BY SUM(o.order_value) DESC
        ) AS rn
    FROM silver_books b
    JOIN silver_orders o
        ON b.book_id = o.book_id
    LEFT JOIN silver_reviews r
        ON b.book_id = r.book_id
    GROUP BY
        b.genre,
        b.book_id,
        b.title
) t
WHERE rn <= 10;

-----------------------------------------------------

-- 7. customer segments by total spend (HIGH >20000, MID 5000-20000, LOW <5000)
CREATE OR REPLACE VIEW gold_customer_segments AS
WITH spend AS (
    SELECT customer_id, SUM(order_value) AS total_spend
    FROM silver_orders
    WHERE status = 'DELIVERED'
    GROUP BY customer_id
)
SELECT
    c.customer_id,
    c.name AS customer_name,
    COALESCE(s.total_spend, 0) AS total_spend,
    CASE
        WHEN COALESCE(s.total_spend, 0) > 20000 THEN 'HIGH VALUE'
        WHEN COALESCE(s.total_spend, 0) >= 5000 THEN 'MID VALUE'
        ELSE 'LOW VALUE'
    END AS customer_segment
FROM silver_customers c
LEFT JOIN spend s ON s.customer_id = c.customer_id;
