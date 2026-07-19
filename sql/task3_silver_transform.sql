
-- BOOKS
-- rejected row of books inserted into silver rejected row
-- checks: title missing, author missing, price <=0, stock <0, published_on missing

INSERT INTO silver_rejected_rows (table_name,source_id,rejection_reason,rejected_at)
SELECT
    'bronze_books',book_id,
    CASE
        WHEN title IS NULL OR TRIM(title) = '' THEN 'Missing Title'
        WHEN author IS NULL OR TRIM(author) = '' THEN 'Missing Author'
        WHEN price <= 0 THEN 'Invalid Price'
        WHEN stock < 0 THEN 'Invalid Stock'
        WHEN published_on IS NULL THEN 'Missing Published Date'
    END,
    NOW()
FROM bronze_books
WHERE
      title IS NULL OR TRIM(title) = '' OR author IS NULL OR TRIM(author) = '' OR price <= 0 OR stock < 0 OR published_on IS NULL;
   
-- velid data of books are inserted into silver book
-- dedupe by book_id (keep latest ingested_at), then keep only rows that pass all checks
-- genre standardised to upper case

INSERT INTO silver_books (book_id,title,author,genre,price,stock,published_on)
WITH ranked_books AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY book_id ORDER BY ingested_at DESC) AS rn
    FROM bronze_books
)
SELECT book_id,TRIM(title),TRIM(author),UPPER(TRIM(genre)),price,stock,published_on
FROM ranked_books
WHERE rn = 1 AND title IS NOT NULL AND TRIM(title) <> ''AND author IS NOT NULL AND TRIM(author) <> ''AND price > 0 AND stock >= 0 AND published_on IS NOT NULL;



-- CUSTOMERS
-- rejected row of customer table inserted into silver rejected row
-- checks: name missing, email missing/invalid format, joined_on missing, membership missing

INSERT INTO silver_rejected_rows (table_name,source_id,rejection_reason,rejected_at)
SELECT
    'bronze_customers',customer_id,
    CASE
        WHEN name IS NULL OR TRIM(name) = '' THEN 'Missing Name'
        WHEN email IS NULL OR email NOT LIKE '%@%.%' THEN 'Invalid Email'
        WHEN joined_on IS NULL THEN 'Missing Join Date'
        WHEN membership IS NULL OR TRIM(membership) = '' THEN 'Missing Membership'
    END,
    NOW()
FROM bronze_customers
WHERE name IS NULL OR TRIM(name) = '' OR email IS NULL OR email NOT LIKE '%@%.%' OR joined_on IS NULL OR membership IS NULL OR TRIM(membership) = '';

-- velid data of customer are inserted into silver book
-- dedupe by customer_id (keep latest ingested_at), then keep only rows that pass all checks
-- email lowercased, membership uppercased for consistency

INSERT INTO silver_customers (customer_id,name,email,city,joined_on,membership)
WITH ranked_customers AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY ingested_at DESC) AS rn
    FROM bronze_customers
)
SELECT customer_id,TRIM(name),LOWER(TRIM(email)),TRIM(city),joined_on,UPPER(TRIM(membership))
FROM ranked_customers
WHERE rn = 1 AND name IS NOT NULL AND TRIM(name) <> '' AND email IS NOT NULL AND email LIKE '%@%.%' AND joined_on IS NOT NULL AND membership IS NOT NULL AND TRIM(membership) <> '';



-- ORDERS
-- rejected row of orders inserted into silver rejected row
-- checks: quantity <=0, order_date missing, status missing

INSERT INTO silver_rejected_rows (table_name,source_id,rejection_reason,rejected_at)
SELECT
    'bronze_orders',order_id,
    CASE
        WHEN quantity <= 0 THEN 'Invalid Quantity'
        WHEN order_date IS NULL THEN 'Missing Order Date'
        WHEN status IS NULL OR TRIM(status) = '' THEN 'Missing Status'
    END,
    NOW()
FROM bronze_orders
WHERE quantity <= 0 OR order_date IS NULL OR status IS NULL OR TRIM(status) = '';

-- valid orders inserted into silver_orders
-- dedupe by order_id (keep latest ingested_at), join bronze_books to get price for order_value
-- status standardised to upper case

INSERT INTO silver_orders (order_id,customer_id,book_id,order_date,quantity,status,order_value)
WITH ranked_orders AS
(
    SELECT *,
           ROW_NUMBER() OVER(PARTITION BY order_id ORDER BY ingested_at DESC) AS rn
    FROM bronze_orders
)

SELECT o.order_id,o.customer_id,o.book_id,o.order_date,o.quantity,
    UPPER(TRIM(o.status)),(o.quantity * b.price) AS order_value
FROM ranked_orders o
JOIN bronze_books b
ON o.book_id = b.book_id
WHERE rn = 1 AND quantity > 0 AND order_date IS NOT NULL AND status IS NOT NULL AND TRIM(status) <> '';



-- LOANS
-- rejected row of loans inserted into silver rejected row
-- checks: loan_date missing, due_date missing, due_date before loan_date

INSERT INTO silver_rejected_rows (table_name,source_id,rejection_reason,rejected_at)
SELECT
    'bronze_loans',loan_id,
    CASE
        WHEN loan_date IS NULL THEN 'Missing Loan Date'
        WHEN due_date IS NULL THEN 'Missing Due Date'
        WHEN due_date < loan_date THEN 'Invalid Due Date'
    END,
    NOW()
FROM bronze_loans
WHERE loan_date IS NULL OR due_date IS NULL OR due_date < loan_date;


-- valid loans inserted into silver_loans
-- dedupe by loan_id (keep latest ingested_at)
-- days_overdue = days between due_date and return_date (or today if not returned yet), never negative
-- overdue_category buckets: ON TIME / MILD (1-5 days) / SEVERE (6-15 days) / CRITICAL (15+ days)

INSERT INTO silver_loans (loan_id,customer_id,book_id,loan_date,due_date,return_date,days_overdue,overdue_category)
WITH ranked_loans AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY loan_id ORDER BY ingested_at DESC) AS rn
    FROM bronze_loans
)

SELECT loan_id,customer_id,book_id,loan_date, due_date,return_date,
    GREATEST(
        DATEDIFF(
            COALESCE(return_date, CURDATE()),
            due_date
        ),
        0
    ) AS days_overdue,

    CASE
        WHEN GREATEST(DATEDIFF(COALESCE(return_date, CURDATE()), due_date),0) = 0
            THEN 'ON TIME'

        WHEN GREATEST(DATEDIFF(COALESCE(return_date, CURDATE()), due_date),0) BETWEEN 1 AND 5
            THEN 'MILD'

        WHEN GREATEST(DATEDIFF(COALESCE(return_date, CURDATE()), due_date),0) BETWEEN 6 AND 15
            THEN 'SEVERE'

        ELSE 'CRITICAL'
    END

FROM ranked_loans

WHERE rn = 1
AND loan_date IS NOT NULL
AND due_date IS NOT NULL
AND due_date >= loan_date;



-- REVIEWS
-- rejected row of reviews inserted into silver rejected row
-- only mandatory check per spec: rating must be between 1 and 5

INSERT INTO silver_rejected_rows (
    table_name,
    source_id,
    rejection_reason,
    rejected_at
)
SELECT
    'bronze_reviews',
    review_id,
    CASE
        WHEN rating NOT BETWEEN 1 AND 5 THEN 'Invalid Rating'
    END,
    NOW()
FROM bronze_reviews
WHERE
      rating NOT BETWEEN 1 AND 5;
   
-- valid reviews inserted into silver_reviews
-- dedupe by review_id (keep latest ingested_at), review_text trimmed

INSERT INTO silver_reviews (review_id,customer_id,book_id,rating,review_text,created_at)
WITH ranked_reviews AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY review_id ORDER BY ingested_at DESC) AS rn
    FROM bronze_reviews
)

SELECT review_id,customer_id,book_id,rating,TRIM(review_text),created_at
FROM ranked_reviews
WHERE rn = 1
  AND rating BETWEEN 1 AND 5
  AND review_text IS NOT NULL
  AND TRIM(review_text) <> ''
  AND created_at IS NOT NULL;