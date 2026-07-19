
-- pipeline health view: bronze count, silver count, rejected count,
-- rejection rate and status per table

CREATE OR REPLACE VIEW gold_pipeline_health AS
SELECT
    pm.table_name,
    pm.last_loaded_at,
    bronze_counts.rows_in_bronze,
    silver_counts.rows_in_silver,
    COALESCE(rej_counts.rows_rejected, 0) AS rows_rejected,
    ROUND(COALESCE(rej_counts.rows_rejected, 0) / NULLIF(bronze_counts.rows_in_bronze, 0) * 100, 2) AS rejection_rate_pct,
    CASE
        WHEN ROUND(COALESCE(rej_counts.rows_rejected, 0) / NULLIF(bronze_counts.rows_in_bronze, 0) * 100, 2) > 5 THEN 'DEGRADED'
        ELSE 'HEALTHY'
    END AS pipeline_status
FROM pipeline_metadata pm
LEFT JOIN (
    SELECT 'bronze_books' AS table_name, COUNT(*) AS rows_in_bronze FROM bronze_books
    UNION ALL SELECT 'bronze_customers', COUNT(*) FROM bronze_customers
    UNION ALL SELECT 'bronze_orders', COUNT(*) FROM bronze_orders
    UNION ALL SELECT 'bronze_loans', COUNT(*) FROM bronze_loans
    UNION ALL SELECT 'bronze_reviews', COUNT(*) FROM bronze_reviews
) bronze_counts ON bronze_counts.table_name = pm.table_name
LEFT JOIN (
    SELECT 'bronze_books' AS table_name, COUNT(*) AS rows_in_silver FROM silver_books
    UNION ALL SELECT 'bronze_customers', COUNT(*) FROM silver_customers
    UNION ALL SELECT 'bronze_orders', COUNT(*) FROM silver_orders
    UNION ALL SELECT 'bronze_loans', COUNT(*) FROM silver_loans
    UNION ALL SELECT 'bronze_reviews', COUNT(*) FROM silver_reviews
) silver_counts ON silver_counts.table_name = pm.table_name
LEFT JOIN (
    SELECT table_name, COUNT(*) AS rows_rejected
    FROM silver_rejected_rows
    GROUP BY table_name
) rej_counts ON rej_counts.table_name = pm.table_name;



-- overall pipeline verdict: healthy only if every table's rejection
-- rate is under 5%

SELECT
    ROUND(AVG(rejection_rate_pct), 2) AS avg_rejection_rate_pct,
    MAX(rejection_rate_pct) AS worst_table_rejection_rate_pct,
    CASE
        WHEN MAX(rejection_rate_pct) > 5 THEN 'DEGRADED'
        ELSE 'HEALTHY'
    END AS overall_pipeline_verdict
FROM gold_pipeline_health;