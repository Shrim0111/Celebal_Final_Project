-- bronze_books load
START TRANSACTION;
INSERT INTO bronze_books (book_id, title, author, genre, price, stock, published_on, ingested_at, batch_id)
SELECT s.book_id, s.title, s.author, s.genre, s.price, s.stock, s.published_on, NOW(), CONCAT('BATCH_', DATE_FORMAT(NOW(), '%Y%m%d_%H%i%s'))
FROM books s
WHERE NOT EXISTS (SELECT 1 FROM bronze_books b WHERE b.book_id = s.book_id);

SET @rows_loaded = ROW_COUNT();
UPDATE pipeline_metadata
SET last_loaded_at = NOW(), rows_loaded = @rows_loaded, status = 'SUCCESS'
WHERE table_name = 'bronze_books';
COMMIT;


-- bronze_customers load

SET @last_load_customers = (SELECT last_loaded_at FROM pipeline_metadata WHERE table_name = 'bronze_customers');

START TRANSACTION;
INSERT INTO bronze_customers (customer_id, name, email, city, joined_on, membership, ingested_at, batch_id)
SELECT s.customer_id, s.name, s.email, s.city, s.joined_on, s.membership, NOW(), CONCAT('BATCH_', DATE_FORMAT(NOW(), '%Y%m%d_%H%i%s'))
FROM customers s
WHERE s.joined_on > @last_load_customers
AND NOT EXISTS (SELECT 1 FROM bronze_customers b WHERE b.customer_id = s.customer_id);

SET @rows_loaded = ROW_COUNT();
UPDATE pipeline_metadata
SET last_loaded_at = NOW(), rows_loaded =@rows_loaded, status = 'SUCCESS'
WHERE table_name = 'bronze_customers';
COMMIT;


-- bronze_orders load

SET @last_load_orders = (SELECT last_loaded_at FROM pipeline_metadata WHERE table_name = 'bronze_orders');

START TRANSACTION;
INSERT INTO bronze_orders (order_id, customer_id, book_id, order_date, quantity, status, ingested_at, batch_id)
SELECT s.order_id, s.customer_id, s.book_id, s.order_date, s.quantity, s.status, NOW(), CONCAT('BATCH_', DATE_FORMAT(NOW(), '%Y%m%d_%H%i%s'))
FROM orders s
WHERE s.order_date > @last_load_orders
AND NOT EXISTS (SELECT 1 FROM bronze_orders b WHERE b.order_id = s.order_id);

SET @rows_loaded = ROW_COUNT();
UPDATE pipeline_metadata
SET last_loaded_at = NOW(), rows_loaded = @rows_loaded, status = 'SUCCESS'
WHERE table_name = 'bronze_orders';
COMMIT;



-- bronze_loans load

SET @last_load_loans = (SELECT last_loaded_at FROM pipeline_metadata WHERE table_name = 'bronze_loans');

START TRANSACTION;
INSERT INTO bronze_loans (loan_id, customer_id, book_id, loan_date, due_date, return_date, ingested_at, batch_id)
SELECT s.loan_id, s.customer_id, s.book_id, s.loan_date, s.due_date, s.return_date, NOW(), CONCAT('BATCH_', DATE_FORMAT(NOW(), '%Y%m%d_%H%i%s'))
FROM loans s
WHERE s.loan_date > @last_load_loans
AND NOT EXISTS (SELECT 1 FROM bronze_loans b WHERE b.loan_id = s.loan_id);

SET @rows_loaded = ROW_COUNT();
UPDATE pipeline_metadata
SET last_loaded_at = NOW(), rows_loaded = @rows_loaded, status = 'SUCCESS'
WHERE table_name = 'bronze_loans';
COMMIT;


-- bronze_reviews load

SET @last_load_reviews = (SELECT last_loaded_at FROM pipeline_metadata WHERE table_name = 'bronze_reviews');

START TRANSACTION;
INSERT INTO bronze_reviews (review_id, customer_id, book_id, rating, review_text, created_at, ingested_at, batch_id)
SELECT s.review_id, s.customer_id, s.book_id, s.rating, s.review_text, s.created_at, NOW(), CONCAT('BATCH_', DATE_FORMAT(NOW(), '%Y%m%d_%H%i%s'))
FROM reviews s
WHERE s.created_at > @last_load_reviews
AND NOT EXISTS (SELECT 1 FROM bronze_reviews b WHERE b.review_id = s.review_id);

SET @rows_loaded = ROW_COUNT();
UPDATE pipeline_metadata
SET last_loaded_at = NOW(), rows_loaded = @rows_loaded, status = 'SUCCESS'
WHERE table_name = 'bronze_reviews';
COMMIT;


