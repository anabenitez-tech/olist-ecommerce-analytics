-- ============================================================
-- Project: Olist E-Commerce Analytics
-- File: 01_database_setup.sql
-- Purpose:
--   Create the final SQL Server tables used in the project
--   and load validated data from the staging tables.
--
-- Notes:
--   - Raw CSV files were first imported into staging tables
--     using the suffix "_import".
--   - Monetary fields were corrected after detecting a
--     decimal separator issue during import.
--   - Final tables use appropriate data types and primary keys.
-- ============================================================

USE olist_ecommerce;
GO

-- ============================================
-- Table: customers_import
-- Source: olist_customers_dataset.csv
-- ============================================

SELECT TOP 10 *
FROM customers_import;

-- ============================================
-- Check existing tables
-- ============================================

SELECT
    TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_NAME;

SELECT COUNT(*) AS total_rows
FROM customers;

DROP TABLE customers;

-- ============================================
-- Create final customers table
-- ============================================

CREATE TABLE customers (
    customer_id NVARCHAR(50) PRIMARY KEY,
    customer_unique_id NVARCHAR(50) NOT NULL,
    customer_zip_code_prefix INT NOT NULL,
    customer_city NVARCHAR(50) NOT NULL,
    customer_state NVARCHAR(50) NOT NULL
);

INSERT INTO customers (
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state
)
SELECT
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state
FROM customers_import;

SELECT COUNT(*) AS total_customers
FROM customers;



-- ============================================
-- Create final orders table
-- ============================================

CREATE TABLE orders (
    order_id NVARCHAR(50) PRIMARY KEY,
    customer_id NVARCHAR(50) NOT NULL,
    order_status NVARCHAR(50) NOT NULL,
    order_purchase_timestamp DATETIME2 NOT NULL,
    order_approved_at DATETIME2 NULL,
    order_delivered_carrier_date DATETIME2 NULL,
    order_delivered_customer_date DATETIME2 NULL,
    order_estimated_delivery_date DATETIME2 NOT NULL
);

INSERT INTO orders (
    order_id,
    customer_id,
    order_status,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date
)
SELECT
    order_id,
    customer_id,
    order_status,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date
FROM orders_import;

SELECT COUNT(*) AS total_orders
FROM orders;

-- ============================================
-- Create final products table
-- ============================================

CREATE TABLE products (
    product_id NVARCHAR(50) PRIMARY KEY,
    product_category_name NVARCHAR(50) NULL,
    product_name_lenght INT NULL,
    product_description_lenght INT NULL,
    product_photos_qty INT NULL,
    product_weight_g INT NULL,
    product_length_cm INT NULL,
    product_height_cm INT NULL,
    product_width_cm INT NULL
);

INSERT INTO products (
    product_id,
    product_category_name,
    product_name_lenght,
    product_description_lenght,
    product_photos_qty,
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm
)
SELECT
    product_id,
    product_category_name,
    product_name_lenght,
    product_description_lenght,
    product_photos_qty,
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm
FROM products_import;

SELECT COUNT(*) AS total_products
FROM products;


-- ============================================
-- Create final sellers table
-- ============================================

CREATE TABLE sellers (
    seller_id NVARCHAR(50) PRIMARY KEY,
    seller_zip_code_prefix INT NOT NULL,
    seller_city NVARCHAR(50) NOT NULL,
    seller_state NVARCHAR(50) NOT NULL
);

INSERT INTO sellers (
    seller_id,
    seller_zip_code_prefix,
    seller_city,
    seller_state
)
SELECT
    seller_id,
    seller_zip_code_prefix,
    seller_city,
    seller_state
FROM sellers_import;

SELECT COUNT(*) AS total_sellers
FROM sellers;


-- ============================================
-- Create final order_items table
-- ============================================

CREATE TABLE order_items (
    order_id NVARCHAR(50) NOT NULL,
    order_item_id INT NOT NULL,
    product_id NVARCHAR(50) NOT NULL,
    seller_id NVARCHAR(50) NOT NULL,
    shipping_limit_date DATETIME2 NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    freight_value DECIMAL(10,2) NOT NULL,

    CONSTRAINT PK_order_items
        PRIMARY KEY (order_id, order_item_id)
);

INSERT INTO order_items (
    order_id,
    order_item_id,
    product_id,
    seller_id,
    shipping_limit_date,
    price,
    freight_value
)
SELECT
    order_id,
    order_item_id,
    product_id,
    seller_id,
    shipping_limit_date,
    price,
    freight_value
FROM order_items_import;

SELECT COUNT(*) AS total_order_items
FROM order_items;


-- ============================================
-- Create final order_payments table
-- ============================================

CREATE TABLE order_payments (
    order_id NVARCHAR(50) NOT NULL,
    payment_sequential INT NOT NULL,
    payment_type NVARCHAR(50) NOT NULL,
    payment_installments INT NOT NULL,
    payment_value DECIMAL(10,2) NOT NULL,

    CONSTRAINT PK_order_payments
        PRIMARY KEY (order_id, payment_sequential)
);

INSERT INTO order_payments (
    order_id,
    payment_sequential,
    payment_type,
    payment_installments,
    payment_value
)
SELECT
    order_id,
    payment_sequential,
    payment_type,
    payment_installments,
    payment_value
FROM order_payments_import;

SELECT COUNT(*) AS total_payments
FROM order_payments;


-- ============================================
-- Create final order_reviews table
-- ============================================

CREATE TABLE order_reviews (
    review_row_id INT IDENTITY(1,1) PRIMARY KEY,
    review_id NVARCHAR(50) NOT NULL,
    order_id NVARCHAR(50) NOT NULL,
    review_score INT NOT NULL,
    review_comment_title NVARCHAR(500) NULL,
    review_comment_message NVARCHAR(MAX) NULL,
    review_creation_date DATETIME2 NOT NULL,
    review_answer_timestamp DATETIME2 NOT NULL
);

INSERT INTO order_reviews (
    review_id,
    order_id,
    review_score,
    review_comment_title,
    review_comment_message,
    review_creation_date,
    review_answer_timestamp
)
SELECT
    review_id,
    order_id,
    review_score,
    review_comment_title,
    review_comment_message,
    review_creation_date,
    review_answer_timestamp
FROM order_reviews_import;

SELECT COUNT(*) AS total_reviews
FROM order_reviews;


-- ============================================
-- Create final category_translation table
-- ============================================

CREATE TABLE category_translation (
    product_category_name NVARCHAR(50) PRIMARY KEY,
    product_category_name_english NVARCHAR(50) NOT NULL
);

INSERT INTO category_translation (
    product_category_name,
    product_category_name_english
)
SELECT
    product_category_name,
    product_category_name_english
FROM category_translation_import;

SELECT COUNT(*) AS total_categories
FROM category_translation;


-- ============================================
-- Create final geolocation table
-- ============================================

CREATE TABLE geolocation (
    geolocation_zip_code_prefix INT NOT NULL,
    geolocation_lat NVARCHAR(50) NOT NULL,
    geolocation_lng NVARCHAR(50) NOT NULL,
    geolocation_city NVARCHAR(50) NOT NULL,
    geolocation_state NVARCHAR(50) NOT NULL
);


INSERT INTO geolocation (
    geolocation_zip_code_prefix,
    geolocation_lat,
    geolocation_lng,
    geolocation_city,
    geolocation_state
)
SELECT
    geolocation_zip_code_prefix,
    geolocation_lat,
    geolocation_lng,
    geolocation_city,
    geolocation_state
FROM geolocation_import;

SELECT COUNT(*) AS total_geolocation
FROM geolocation;

-- ============================================================
-- Final validation
-- Check that all final tables contain the expected number of rows
-- ============================================================

SELECT 'customers' AS table_name, COUNT(*) AS total_rows FROM customers
UNION ALL
SELECT 'orders', COUNT(*) FROM orders
UNION ALL
SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL
SELECT 'order_payments', COUNT(*) FROM order_payments
UNION ALL
SELECT 'order_reviews', COUNT(*) FROM order_reviews
UNION ALL
SELECT 'products', COUNT(*) FROM products
UNION ALL
SELECT 'sellers', COUNT(*) FROM sellers
UNION ALL
SELECT 'geolocation', COUNT(*) FROM geolocation
UNION ALL
SELECT 'category_translation', COUNT(*) FROM category_translation;