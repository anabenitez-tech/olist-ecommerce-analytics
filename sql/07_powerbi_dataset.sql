-- ============================================================
-- Project: Olist E-Commerce Analytics
-- File: 07_powerbi_dataset.sql
-- Purpose:
--   Create a consolidated dataset for Power BI reporting.
--
-- Grain:
--   One row per delivered order.
-- ============================================================

USE olist_ecommerce;
GO


-- ============================================================
-- 1. Power BI Order-Level Dataset
-- ============================================================

ALTER VIEW vw_powerbi_orders AS

WITH order_values AS (
    SELECT
        order_id,
        SUM(price) AS product_revenue,
        SUM(freight_value) AS freight_value,
        SUM(price + freight_value) AS order_total,
        COUNT(*) AS items_count
    FROM order_items
    GROUP BY order_id
),

review_summary AS (
    SELECT
        order_id,
        AVG(CAST(review_score AS FLOAT)) AS review_score
    FROM order_reviews
    GROUP BY order_id
)

SELECT
    o.order_id,
    c.customer_unique_id,
    c.customer_city,
    c.customer_state,

    o.order_purchase_timestamp,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,

    ov.items_count,
    ov.product_revenue,
    ov.freight_value,
    ov.order_total,

    DATEDIFF(
        DAY,
        o.order_purchase_timestamp,
        o.order_delivered_customer_date
    ) AS delivery_days,

    CASE
        WHEN CAST(o.order_delivered_customer_date AS DATE)
             > CAST(o.order_estimated_delivery_date AS DATE)
        THEN 1
        ELSE 0
    END AS is_late,

    DATEDIFF(
        DAY,
        o.order_estimated_delivery_date,
        o.order_delivered_customer_date
    ) AS delivery_delay_days,

    rs.review_score

FROM orders o

INNER JOIN customers c
    ON o.customer_id = c.customer_id

INNER JOIN order_values ov
    ON o.order_id = ov.order_id

LEFT JOIN review_summary rs
    ON o.order_id = rs.order_id

WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL;
GO


-- ============================================================
-- 2. Validation
-- ============================================================

SELECT TOP 10 *
FROM vw_powerbi_orders;

SELECT
    COUNT(*) AS delivered_orders,
    SUM(is_late) AS late_deliveries,
    ROUND(
        100.0 * SUM(is_late) / COUNT(*),
        2
    ) AS late_delivery_rate
FROM vw_powerbi_orders;

SELECT COUNT(*) AS total_rows
FROM vw_powerbi_orders;

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT order_id) AS unique_orders
FROM vw_powerbi_orders;