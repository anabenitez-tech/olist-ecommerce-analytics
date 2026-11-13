-- ============================================================
-- Project: Olist E-Commerce Analytics
-- File: 02_data_quality_checks.sql
-- Purpose:
--   Validate the quality and consistency of the final tables
--   before starting the business analysis.
--
-- Checks performed:
--   - Missing values
--   - Duplicate records
--   - Referential integrity
--   - Missing category translations
--   - Invalid monetary values
--   - Review score validation
--   - Delivery date inconsistencies
-- ============================================================

USE olist_ecommerce;
GO


-- ============================================================
-- 1. Customer data quality
-- ============================================================

SELECT
    SUM(CASE WHEN customer_id IS NULL THEN 1 ELSE 0 END) AS null_customer_id,
    SUM(CASE WHEN customer_unique_id IS NULL THEN 1 ELSE 0 END) AS null_customer_unique_id,
    SUM(CASE WHEN customer_zip_code_prefix IS NULL THEN 1 ELSE 0 END) AS null_zip,
    SUM(CASE WHEN customer_city IS NULL THEN 1 ELSE 0 END) AS null_city,
    SUM(CASE WHEN customer_state IS NULL THEN 1 ELSE 0 END) AS null_state
FROM customers;


SELECT
    customer_id,
    COUNT(*) AS total_rows
FROM customers
GROUP BY customer_id
HAVING COUNT(*) > 1;


SELECT TOP 10
    customer_unique_id,
    COUNT(*) AS total_customer_records
FROM customers
GROUP BY customer_unique_id
HAVING COUNT(*) > 1
ORDER BY total_customer_records DESC;


-- ============================================================
-- 2. Order data quality
-- ============================================================

SELECT
    SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END) AS null_order_id,
    SUM(CASE WHEN customer_id IS NULL THEN 1 ELSE 0 END) AS null_customer_id,
    SUM(CASE WHEN order_status IS NULL THEN 1 ELSE 0 END) AS null_order_status,
    SUM(CASE WHEN order_purchase_timestamp IS NULL THEN 1 ELSE 0 END) AS null_purchase_date,
    SUM(CASE WHEN order_approved_at IS NULL THEN 1 ELSE 0 END) AS null_approved_at,
    SUM(CASE WHEN order_delivered_carrier_date IS NULL THEN 1 ELSE 0 END) AS null_carrier_date,
    SUM(CASE WHEN order_delivered_customer_date IS NULL THEN 1 ELSE 0 END) AS null_customer_date,
    SUM(CASE WHEN order_estimated_delivery_date IS NULL THEN 1 ELSE 0 END) AS null_estimated_date
FROM orders;


SELECT
    order_status,
    COUNT(*) AS total_orders
FROM orders
WHERE order_delivered_customer_date IS NULL
GROUP BY order_status
ORDER BY total_orders DESC;


SELECT
    order_id,
    order_status,
    order_purchase_timestamp,
    order_delivered_customer_date
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NULL;

-- Finding:
-- 8 orders are marked as "delivered" but do not have
-- a customer delivery date.


SELECT
    order_id,
    COUNT(*) AS total_rows
FROM orders
GROUP BY order_id
HAVING COUNT(*) > 1;


-- ============================================================
-- 3. Referential integrity
-- ============================================================

SELECT COUNT(*) AS orphan_orders
FROM orders o
LEFT JOIN customers c
    ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;


SELECT COUNT(*) AS orphan_order_items
FROM order_items oi
LEFT JOIN orders o
    ON oi.order_id = o.order_id
WHERE o.order_id IS NULL;


SELECT COUNT(*) AS orphan_products
FROM order_items oi
LEFT JOIN products p
    ON oi.product_id = p.product_id
WHERE p.product_id IS NULL;


SELECT COUNT(*) AS orphan_sellers
FROM order_items oi
LEFT JOIN sellers s
    ON oi.seller_id = s.seller_id
WHERE s.seller_id IS NULL;


SELECT COUNT(*) AS orphan_payments
FROM order_payments op
LEFT JOIN orders o
    ON op.order_id = o.order_id
WHERE o.order_id IS NULL;


SELECT COUNT(*) AS orphan_reviews
FROM order_reviews r
LEFT JOIN orders o
    ON r.order_id = o.order_id
WHERE o.order_id IS NULL;

-- Finding:
-- No orphan records were found in the tested relationships.


-- ============================================================
-- 4. Product data quality
-- ============================================================

SELECT
    COUNT(*) AS categories_without_translation
FROM products p
LEFT JOIN category_translation ct
    ON p.product_category_name = ct.product_category_name
WHERE p.product_category_name IS NOT NULL
  AND ct.product_category_name IS NULL;


SELECT DISTINCT
    p.product_category_name
FROM products p
LEFT JOIN category_translation ct
    ON p.product_category_name = ct.product_category_name
WHERE p.product_category_name IS NOT NULL
  AND ct.product_category_name IS NULL
ORDER BY p.product_category_name;

-- Finding:
-- 13 products belong to categories without an English translation.
-- The affected categories are:
--   - pc_gamer
--   - portateis_cozinha_e_preparadores_de_alimentos


SELECT
    SUM(CASE WHEN product_category_name IS NULL THEN 1 ELSE 0 END) AS null_category,
    SUM(CASE WHEN product_name_lenght IS NULL THEN 1 ELSE 0 END) AS null_name_length,
    SUM(CASE WHEN product_description_lenght IS NULL THEN 1 ELSE 0 END) AS null_description_length,
    SUM(CASE WHEN product_photos_qty IS NULL THEN 1 ELSE 0 END) AS null_photos,
    SUM(CASE WHEN product_weight_g IS NULL THEN 1 ELSE 0 END) AS null_weight,
    SUM(CASE WHEN product_length_cm IS NULL THEN 1 ELSE 0 END) AS null_length,
    SUM(CASE WHEN product_height_cm IS NULL THEN 1 ELSE 0 END) AS null_height,
    SUM(CASE WHEN product_width_cm IS NULL THEN 1 ELSE 0 END) AS null_width
FROM products;


SELECT
    COUNT(DISTINCT oi.product_id) AS sold_products_without_category,
    COUNT(*) AS order_lines_without_category
FROM order_items oi
INNER JOIN products p
    ON oi.product_id = p.product_id
WHERE p.product_category_name IS NULL;

-- Finding:
-- 610 products do not have a product category.
-- These products appear in 1,603 order lines, so they
-- should not be removed from the analysis.


-- ============================================================
-- 5. Monetary and payment validation
-- ============================================================

SELECT
    SUM(CASE WHEN price < 0 THEN 1 ELSE 0 END) AS negative_prices,
    SUM(CASE WHEN freight_value < 0 THEN 1 ELSE 0 END) AS negative_freight
FROM order_items;


SELECT
    SUM(CASE WHEN payment_value < 0 THEN 1 ELSE 0 END) AS negative_payments,
    SUM(CASE WHEN payment_value = 0 THEN 1 ELSE 0 END) AS zero_payments
FROM order_payments;


SELECT
    payment_type,
    COUNT(*) AS zero_value_payments
FROM order_payments
WHERE payment_value = 0
GROUP BY payment_type;

-- Finding:
-- 9 payment records have payment_value = 0.
-- These correspond to voucher and not_defined payment types.


-- ============================================================
-- 6. Review validation
-- ============================================================

SELECT
    MIN(review_score) AS min_review_score,
    MAX(review_score) AS max_review_score
FROM order_reviews;

-- Finding:
-- Review scores are within the expected range of 1 to 5.


-- ============================================================
-- 7. Delivery consistency
-- ============================================================

SELECT
    COUNT(*) AS late_deliveries
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
  AND order_delivered_customer_date > order_estimated_delivery_date;


SELECT
    COUNT(*) AS delivered_orders,
    SUM(
        CASE
            WHEN order_delivered_customer_date > order_estimated_delivery_date
            THEN 1
            ELSE 0
        END
    ) AS late_deliveries,
    ROUND(
        100.0 *
        SUM(
            CASE
               WHEN CAST(order_delivered_customer_date AS DATE)
     > CAST(order_estimated_delivery_date AS DATE)
                THEN 1
                ELSE 0
            END
        ) / COUNT(*),
        2
    ) AS late_delivery_rate
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL;

-- Finding:
-- 6,534 delivered orders arrived after the estimated delivery date.
-- Late delivery rate: 6.77%.