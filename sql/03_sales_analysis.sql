-- ============================================================
-- Project: Olist E-Commerce Analytics
-- File: 03_sales_analysis.sql
-- Purpose:
--   Analyze sales performance and key commercial metrics
--   using the cleaned relational tables.
--
-- Main metrics:
--   - Total revenue
--   - Total orders
--   - Average order value
--   - Monthly sales trend
--   - Revenue by category
--   - Revenue by customer state
-- ============================================================

USE olist_ecommerce;
GO

-- ============================================================
-- 1. Total product revenue
-- ============================================================

SELECT
    ROUND(SUM(price), 2) AS total_product_revenue
FROM order_items;

-- ============================================================
-- 2. Total orders
-- ============================================================

SELECT
    COUNT(*) AS total_orders
FROM orders;

-- ============================================================
-- 3. Average Order Value (AOV)
-- ============================================================

SELECT
    ROUND(AVG(order_revenue), 2) AS average_order_value
FROM (
    SELECT
        order_id,
        SUM(price) AS order_revenue
    FROM order_items
    GROUP BY order_id
) AS order_totals;

-- ============================================================
-- 4. Average Order Value - Delivered Orders
-- ============================================================

SELECT
    ROUND(AVG(order_revenue), 2) AS delivered_average_order_value
FROM (
    SELECT
        oi.order_id,
        SUM(oi.price) AS order_revenue
    FROM order_items oi
    INNER JOIN orders o
        ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY oi.order_id
) AS order_totals;


-- ============================================================
-- 5. Revenue from Delivered Orders
-- ============================================================

SELECT
    ROUND(SUM(oi.price), 2) AS delivered_product_revenue
FROM order_items oi
INNER JOIN orders o
    ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered';

-- ============================================================
-- 6. Delivered Orders
-- ============================================================

SELECT
    COUNT(*) AS delivered_orders
FROM orders
WHERE order_status = 'delivered';


-- ============================================================
-- 7. Freight Value from Delivered Orders
-- ============================================================

SELECT
    ROUND(SUM(oi.freight_value), 2) AS delivered_freight_value
FROM order_items oi
INNER JOIN orders o
    ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered';

-- ============================================================
-- 8. Freight Share of Delivered Order Value
-- ============================================================

SELECT
    ROUND(SUM(oi.price), 2) AS product_revenue,
    ROUND(SUM(oi.freight_value), 2) AS freight_value,
    ROUND(SUM(oi.price + oi.freight_value), 2) AS total_order_value,
    ROUND(
        100.0 * SUM(oi.freight_value) 
        / SUM(oi.price + oi.freight_value),
        2
    ) AS freight_percentage
FROM order_items oi
INNER JOIN orders o
    ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered';


-- ============================================================
-- 9. Monthly Revenue Trend
-- ============================================================

SELECT
    YEAR(o.order_purchase_timestamp) AS order_year,
    MONTH(o.order_purchase_timestamp) AS order_month,
    ROUND(SUM(oi.price), 2) AS monthly_revenue
FROM orders o
INNER JOIN order_items oi
    ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY
    YEAR(o.order_purchase_timestamp),
    MONTH(o.order_purchase_timestamp)
ORDER BY
    order_year,
    order_month;


    -- ============================================================
-- 10. Month-over-Month Revenue Growth
-- ============================================================

WITH monthly_revenue AS (
    SELECT
        YEAR(o.order_purchase_timestamp) AS order_year,
        MONTH(o.order_purchase_timestamp) AS order_month,
        SUM(oi.price) AS revenue
    FROM orders o
    INNER JOIN order_items oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY
        YEAR(o.order_purchase_timestamp),
        MONTH(o.order_purchase_timestamp)
)

SELECT
    order_year,
    order_month,
    ROUND(revenue, 2) AS revenue,
    ROUND(
        100.0 * (revenue - LAG(revenue) OVER (
            ORDER BY order_year, order_month
        ))
        / LAG(revenue) OVER (
            ORDER BY order_year, order_month
        ),
        2
    ) AS mom_growth_pct
FROM monthly_revenue
ORDER BY
    order_year,
    order_month;


    -- ============================================================
-- 11. Revenue by Product Category
-- ============================================================

SELECT TOP 10
    COALESCE(
        ct.product_category_name_english,
        p.product_category_name,
        'Unknown'
    ) AS category_name,
    ROUND(SUM(oi.price), 2) AS revenue
FROM order_items oi
INNER JOIN orders o
    ON oi.order_id = o.order_id
INNER JOIN products p
    ON oi.product_id = p.product_id
LEFT JOIN category_translation ct
    ON p.product_category_name = ct.product_category_name
WHERE o.order_status = 'delivered'
GROUP BY
    COALESCE(
        ct.product_category_name_english,
        p.product_category_name,
        'Unknown'
    )
ORDER BY revenue DESC;


-- ============================================================
-- 12. Revenue and Items Sold by Product Category
-- ============================================================

SELECT TOP 10
    COALESCE(
        ct.product_category_name_english,
        p.product_category_name,
        'Unknown'
    ) AS category_name,
    COUNT(*) AS items_sold,
    ROUND(SUM(oi.price), 2) AS revenue
FROM order_items oi
INNER JOIN orders o
    ON oi.order_id = o.order_id
INNER JOIN products p
    ON oi.product_id = p.product_id
LEFT JOIN category_translation ct
    ON p.product_category_name = ct.product_category_name
WHERE o.order_status = 'delivered'
GROUP BY
    COALESCE(
        ct.product_category_name_english,
        p.product_category_name,
        'Unknown'
    )
ORDER BY revenue DESC;


-- ============================================================
-- 13. Revenue by Customer State
-- ============================================================

SELECT
    c.customer_state,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(oi.price), 2) AS revenue
FROM orders o
INNER JOIN customers c
    ON o.customer_id = c.customer_id
INNER JOIN order_items oi
    ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_state
ORDER BY revenue DESC;


-- ============================================================
-- 14. Average Order Value by Customer State
-- ============================================================

WITH order_totals AS (
    SELECT
        o.order_id,
        c.customer_state,
        SUM(oi.price) AS order_revenue
    FROM orders o
    INNER JOIN customers c
        ON o.customer_id = c.customer_id
    INNER JOIN order_items oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY
        o.order_id,
        c.customer_state
)

SELECT
    customer_state,
    COUNT(*) AS total_orders,
    ROUND(AVG(order_revenue), 2) AS average_order_value
FROM order_totals
GROUP BY customer_state
ORDER BY average_order_value DESC;


-- ============================================================
-- 15. Monthly Revenue and Orders
-- ============================================================

SELECT
    YEAR(o.order_purchase_timestamp) AS order_year,
    MONTH(o.order_purchase_timestamp) AS order_month,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(oi.price), 2) AS revenue
FROM orders o
INNER JOIN order_items oi
    ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY
    YEAR(o.order_purchase_timestamp),
    MONTH(o.order_purchase_timestamp)
ORDER BY
    order_year,
    order_month;

    -- Finding:
-- Sales volume increased significantly throughout 2017 and remained
-- at a high level during 2018.
-- November 2017 recorded the highest order volume (7,289 orders),
-- while May 2018 generated the highest monthly revenue (977,544.69).


-- ============================================================
-- 16. Top Sellers by Revenue
-- ============================================================

SELECT TOP 10
    s.seller_id,
    s.seller_state,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    ROUND(SUM(oi.price), 2) AS revenue
FROM order_items oi
INNER JOIN orders o
    ON oi.order_id = o.order_id
INNER JOIN sellers s
    ON oi.seller_id = s.seller_id
WHERE o.order_status = 'delivered'
GROUP BY
    s.seller_id,
    s.seller_state
ORDER BY revenue DESC;

-- Finding:
-- The top seller generated 226,987.93 in revenue across 1,124 delivered orders.
-- The seller is located in SP (São Paulo), reinforcing the strong commercial
-- concentration of the marketplace in that state.

-- ============================================================
-- 17. Revenue by Seller State
-- ============================================================

SELECT
    s.seller_state,
    COUNT(DISTINCT s.seller_id) AS total_sellers,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    ROUND(SUM(oi.price), 2) AS revenue
FROM order_items oi
INNER JOIN orders o
    ON oi.order_id = o.order_id
INNER JOIN sellers s
    ON oi.seller_id = s.seller_id
WHERE o.order_status = 'delivered'
GROUP BY s.seller_state
ORDER BY revenue DESC;

-- Finding:
-- SP (São Paulo) is the dominant seller state, generating 8,509,511.46
-- in revenue across 68,641 delivered orders and 1,769 sellers.

-- ============================================================
-- 18. Customer State Revenue Share
-- ============================================================

WITH state_revenue AS (
    SELECT
        c.customer_state,
        SUM(oi.price) AS revenue
    FROM orders o
    INNER JOIN customers c
        ON o.customer_id = c.customer_id
    INNER JOIN order_items oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_state
)

SELECT TOP 10
    customer_state,
    ROUND(revenue, 2) AS revenue,
    ROUND(
        100.0 * revenue / SUM(revenue) OVER (),
        2
    ) AS revenue_share_pct
FROM state_revenue
ORDER BY revenue DESC;

-- Finding:
-- SP (São Paulo) accounts for 38.33% of total delivered product revenue,
-- making it the most important customer state by a wide margin.

-- ============================================================
-- 19. Same-State vs Cross-State Orders
-- ============================================================

SELECT
    CASE
        WHEN c.customer_state = s.seller_state THEN 'Same State'
        ELSE 'Different State'
    END AS state_relationship,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(oi.price), 2) AS revenue
FROM orders o
INNER JOIN customers c
    ON o.customer_id = c.customer_id
INNER JOIN order_items oi
    ON o.order_id = oi.order_id
INNER JOIN sellers s
    ON oi.seller_id = s.seller_id
WHERE o.order_status = 'delivered'
GROUP BY
    CASE
        WHEN c.customer_state = s.seller_state THEN 'Same State'
        ELSE 'Different State'
    END
ORDER BY revenue DESC;

-- Finding:
-- Cross-state transactions generate most of the marketplace revenue.
-- Different-state orders generated 9,087,193.44 in revenue,
-- compared with 4,134,304.67 from same-state orders.

-- ============================================================
-- 20. Same-State vs Cross-State Revenue Share
-- ============================================================

WITH state_relationship_revenue AS (
    SELECT
        CASE
            WHEN c.customer_state = s.seller_state THEN 'Same State'
            ELSE 'Different State'
        END AS state_relationship,
        SUM(oi.price) AS revenue
    FROM orders o
    INNER JOIN customers c
        ON o.customer_id = c.customer_id
    INNER JOIN order_items oi
        ON o.order_id = oi.order_id
    INNER JOIN sellers s
        ON oi.seller_id = s.seller_id
    WHERE o.order_status = 'delivered'
    GROUP BY
        CASE
            WHEN c.customer_state = s.seller_state THEN 'Same State'
            ELSE 'Different State'
        END
)

SELECT
    state_relationship,
    ROUND(revenue, 2) AS revenue,
    ROUND(
        100.0 * revenue / SUM(revenue) OVER (),
        2
    ) AS revenue_share_pct
FROM state_relationship_revenue
ORDER BY revenue DESC;


-- Finding:
-- 68.73% of delivered product revenue comes from cross-state transactions,
-- while 31.27% comes from same-state transactions.
-- This suggests that Olist operates as a geographically distributed marketplace
-- rather than a primarily local commerce platform.

-- ============================================================
-- 21. Top Product Categories by Revenue Share
-- ============================================================

WITH category_revenue AS (
    SELECT
        COALESCE(
            ct.product_category_name_english,
            p.product_category_name,
            'Unknown'
        ) AS category_name,
        SUM(oi.price) AS revenue
    FROM order_items oi
    INNER JOIN orders o
        ON oi.order_id = o.order_id
    INNER JOIN products p
        ON oi.product_id = p.product_id
    LEFT JOIN category_translation ct
        ON p.product_category_name = ct.product_category_name
    WHERE o.order_status = 'delivered'
    GROUP BY
        COALESCE(
            ct.product_category_name_english,
            p.product_category_name,
            'Unknown'
        )
)

SELECT TOP 10
    category_name,
    ROUND(revenue, 2) AS revenue,
    ROUND(
        100.0 * revenue / SUM(revenue) OVER (),
        2
    ) AS revenue_share_pct
FROM category_revenue
ORDER BY revenue DESC;

-- Finding:
-- health_beauty is the top revenue-generating category,
-- contributing 9.33% of delivered product revenue.
-- The top 5 categories together account for a substantial share
-- of total marketplace revenue, indicating moderate category concentration.