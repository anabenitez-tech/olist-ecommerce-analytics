-- ============================================================
-- Project: Olist E-Commerce Analytics
-- File: 08_powerbi_product_dataset.sql
-- Purpose:
--   Create a product-level dataset for Power BI reporting.
--
-- Grain:
--   One row per delivered order item.
-- ============================================================

USE olist_ecommerce;
GO

CREATE VIEW vw_powerbi_products AS

SELECT
    oi.order_id,
    oi.order_item_id,
    oi.product_id,

    COALESCE(
        ct.product_category_name_english,
        p.product_category_name,
        'Unknown'
    ) AS product_category,

    oi.price,
    oi.freight_value,

    r.review_score

FROM order_items oi

INNER JOIN orders o
    ON oi.order_id = o.order_id

INNER JOIN products p
    ON oi.product_id = p.product_id

LEFT JOIN category_translation ct
    ON p.product_category_name = ct.product_category_name

LEFT JOIN order_reviews r
    ON oi.order_id = r.order_id

WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL;
GO

SELECT TOP 10 *
FROM vw_powerbi_products;