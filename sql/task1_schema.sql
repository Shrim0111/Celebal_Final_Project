create database celebal;
use celebal;


-- create a metadata pipline
CREATE TABLE pipeline_metadata (
    table_name VARCHAR(100) PRIMARY KEY,
    last_loaded_at DATETIME NOT NULL DEFAULT '2000-01-01 00:00:00',
    rows_loaded INT DEFAULT 0,
    status VARCHAR(20) DEFAULT 'PENDING'
);

-- create the structure of the bronze_books table
CREATE TABLE bronze_books
LIKE celebal.books;
ALTER TABLE celebal.bronze_books
ADD COLUMN ingested_at DATETIME,
ADD COLUMN batch_id VARCHAR(50);

-- create the structure of the bronze_customers table
CREATE TABLE bronze_customers
LIKE customers;
ALTER TABLE bronze_customers
ADD COLUMN ingested_at DATETIME,
ADD COLUMN batch_id VARCHAR(50);

-- create the structure of the bronze_order table
CREATE TABLE bronze_orders
LIKE orders;
ALTER TABLE bronze_orders
ADD COLUMN ingested_at DATETIME,
ADD COLUMN batch_id VARCHAR(50);

-- create the structure of the bronze_loans table
CREATE TABLE bronze_loans
LIKE loans;
ALTER TABLE bronze_loans
ADD COLUMN ingested_at DATETIME,
ADD COLUMN batch_id VARCHAR(50);

-- create the structure of the bronze_reviews table
CREATE TABLE bronze_reviews
LIKE reviews;
ALTER TABLE bronze_reviews
ADD COLUMN ingested_at DATETIME,
ADD COLUMN batch_id VARCHAR(50);

-- create the structure of the silver_books table
CREATE TABLE silver_books (
    book_id INT PRIMARY KEY,
    title VARCHAR(255),
    author VARCHAR(255),
    genre VARCHAR(100),
    price DECIMAL(10,2),
    stock INT,
    published_on DATE
);


-- create the structure of the silver_customers table
CREATE TABLE silver_customers (
    customer_id INT PRIMARY KEY,
    name VARCHAR(255),
    email VARCHAR(255),
    city VARCHAR(100),
    joined_on DATE,
    membership VARCHAR(20)
);

-- create the structure of the silver_order table
CREATE TABLE silver_orders (
    order_id INT PRIMARY KEY,
    customer_id INT,
    book_id INT,
    order_date DATE,
    quantity INT,
    status VARCHAR(20),
    order_value DECIMAL(10,2)
);

-- create the structure of the silver_loans table
CREATE TABLE silver_loans (
    loan_id INT PRIMARY KEY,
    customer_id INT,
    book_id INT,
    loan_date DATE,
    due_date DATE,
    return_date DATE,
    days_overdue INT,
    overdue_category VARCHAR(20)
);

-- create the structure of the silver_reviews table
CREATE TABLE silver_reviews (
    review_id INT PRIMARY KEY,
    customer_id INT,
    book_id INT,
    rating INT,
    review_text TEXT,
    created_at DATETIME
);

-- create the structure of the silver_rejeceted table
CREATE TABLE silver_rejected_rows (
    table_name VARCHAR(100),
    source_id INT,
    rejection_reason VARCHAR(255),
    rejected_at DATETIME
);



CREATE VIEW gold_kpi_revenue_growth AS
SELECT NULL AS kpi_value,
       NULL AS kpi_target,
       NULL AS status,
       NULL AS calculated_at;

CREATE VIEW gold_kpi_retention_rate AS
SELECT NULL AS kpi_value,
       NULL AS kpi_target,
       NULL AS status,
       NULL AS calculated_at;

CREATE VIEW gold_kpi_sell_through AS
SELECT NULL AS kpi_value,
       NULL AS kpi_target,
       NULL AS status,
       NULL AS calculated_at;

CREATE VIEW gold_kpi_return_compliance AS
SELECT NULL AS kpi_value,
       NULL AS kpi_target,
       NULL AS status,
       NULL AS calculated_at;

CREATE VIEW gold_kpi_review_coverage AS
SELECT NULL AS kpi_value,
       NULL AS kpi_target,
       NULL AS status,
       NULL AS calculated_at;

CREATE VIEW gold_top_books AS
SELECT
    NULL AS book_id,
    NULL AS title,
    NULL AS genre,
    NULL AS total_revenue,
    NULL AS average_rating,
    NULL AS units_sold;

CREATE VIEW gold_customer_segments AS
SELECT
    NULL AS customer_id,
    NULL AS customer_name,
    NULL AS total_spend,
    NULL AS customer_segment;


INSERT INTO pipeline_metadata (table_name) VALUES
    ('bronze_books'),
    ('bronze_customers'),
    ('bronze_orders'),
    ('bronze_loans'),
    ('bronze_reviews');