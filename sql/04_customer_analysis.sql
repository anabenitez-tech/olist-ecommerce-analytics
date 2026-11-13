-- ============================================================
-- Project: Olist E-Commerce Analytics
-- File: 04_customer_analysis.sql
-- Purpose:
--   Analyze customer behavior, repeat purchases and
--   customer value using delivered orders.
--
-- Main metrics:
--   - Unique customers
--   - Repeat customers
--   - Repeat purchase rate
--   - Orders per customer
--   - Revenue per customer
--   - RFM segmentation
--   - Cohort analysis
-- ============================================================

USE olist_ecommerce;
GO

-- ============================================================
-- 1. Unique Customers
-- ============================================================

SELECT
    COUNT(DISTINCT customer_unique_id) AS unique_customers
FROM customers;

-- ============================================================
-- 2. Repeat Customers
-- ============================================================

SELECT
    COUNT(*) AS repeat_customers
FROM (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS total_orders
    FROM customers c
    INNER JOIN orders o
        ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
    HAVING COUNT(DISTINCT o.order_id) > 1
) AS repeat_customer_list;


-- ============================================================
-- 3. Repeat Purchase Rate
-- ============================================================

WITH customer_orders AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS total_orders
    FROM customers c
    INNER JOIN orders o
        ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
)

SELECT
    COUNT(*) AS delivered_customers,
    SUM(CASE WHEN total_orders > 1 THEN 1 ELSE 0 END) AS repeat_customers,
    ROUND(
        100.0 *
        SUM(CASE WHEN total_orders > 1 THEN 1 ELSE 0 END)
        / COUNT(*),
        2
    ) AS repeat_purchase_rate
FROM customer_orders;

-- Finding:
-- 93,358 customers completed at least one delivered order.
-- Only 2,801 customers placed more than one delivered order,
-- resulting in a repeat purchase rate of 3.00%.
-- Customer retention is therefore relatively low within the observed period.


-- ============================================================
-- 4. Orders per Customer
-- ============================================================

WITH customer_orders AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS total_orders
    FROM customers c
    INNER JOIN orders o
        ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
)

SELECT
    total_orders,
    COUNT(*) AS customers
FROM customer_orders
GROUP BY total_orders
ORDER BY total_orders;

-- Finding:
-- Most customers are one-time buyers.
-- 90,557 customers placed only one delivered order,
-- while only a very small number purchased more than 3 times.
-- The most active customer placed 15 delivered orders.

-- ============================================================
-- 5. Top Customers by Revenue
-- ============================================================

SELECT TOP 10
    c.customer_unique_id,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(oi.price), 2) AS customer_revenue
FROM customers c
INNER JOIN orders o
    ON c.customer_id = o.customer_id
INNER JOIN order_items oi
    ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_unique_id
ORDER BY customer_revenue DESC;

-- Finding:
-- The highest-revenue customer generated 13,440.00 from a single order.
-- High customer value is therefore not necessarily linked to purchase frequency.
-- Several top customers generated substantial revenue from only one purchase.

-- ============================================================
-- 6. Average Revenue per Customer
-- ============================================================

WITH customer_revenue AS (
    SELECT
        c.customer_unique_id,
        SUM(oi.price) AS revenue
    FROM customers c
    INNER JOIN orders o
        ON c.customer_id = o.customer_id
    INNER JOIN order_items oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
)

SELECT
    ROUND(AVG(revenue), 2) AS average_revenue_per_customer
FROM customer_revenue;

-- Finding:
-- Average revenue per delivered customer is 141.62.
-- However, customer value is highly uneven, with a small number
-- of customers generating substantially more than the average.

-- ============================================================
-- 7. RFM Base Metrics
-- ============================================================

WITH customer_rfm AS (
    SELECT
        c.customer_unique_id,
        MAX(o.order_purchase_timestamp) AS last_purchase_date,
        COUNT(DISTINCT o.order_id) AS frequency,
        SUM(oi.price) AS monetary
    FROM customers c
    INNER JOIN orders o
        ON c.customer_id = o.customer_id
    INNER JOIN order_items oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
)

SELECT TOP 10
    customer_unique_id,
    last_purchase_date,
    frequency,
    ROUND(monetary, 2) AS monetary
FROM customer_rfm
ORDER BY monetary DESC;

-- ============================================================
-- 8. RFM Metrics with Recency
-- ============================================================

DECLARE @analysis_date DATE = (
    SELECT DATEADD(DAY, 1, MAX(CAST(order_purchase_timestamp AS DATE)))
    FROM orders
    WHERE order_status = 'delivered'
);

WITH customer_rfm AS (
    SELECT
        c.customer_unique_id,
        DATEDIFF(
            DAY,
            MAX(CAST(o.order_purchase_timestamp AS DATE)),
            @analysis_date
        ) AS recency,
        COUNT(DISTINCT o.order_id) AS frequency,
        SUM(oi.price) AS monetary
    FROM customers c
    INNER JOIN orders o
        ON c.customer_id = o.customer_id
    INNER JOIN order_items oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
)

SELECT TOP 10
    customer_unique_id,
    recency,
    frequency,
    ROUND(monetary, 2) AS monetary
FROM customer_rfm
ORDER BY monetary DESC;

-- ============================================================
-- 9. RFM Scoring
-- ============================================================

DECLARE @analysis_date DATE = (
    SELECT DATEADD(DAY, 1, MAX(CAST(order_purchase_timestamp AS DATE)))
    FROM orders
    WHERE order_status = 'delivered'
);

WITH customer_rfm AS (
    SELECT
        c.customer_unique_id,

        DATEDIFF(
            DAY,
            MAX(CAST(o.order_purchase_timestamp AS DATE)),
            @analysis_date
        ) AS recency,

        COUNT(DISTINCT o.order_id) AS frequency,

        SUM(oi.price) AS monetary

    FROM customers c

    INNER JOIN orders o
        ON c.customer_id = o.customer_id

    INNER JOIN order_items oi
        ON o.order_id = oi.order_id

    WHERE o.order_status = 'delivered'

    GROUP BY c.customer_unique_id
),

rfm_scores AS (
    SELECT
        customer_unique_id,
        recency,
        frequency,
        monetary,

        -- Lower recency is better
        6 - NTILE(5) OVER (
            ORDER BY recency ASC
        ) AS r_score,

        -- Frequency scoring adapted to the
        -- highly skewed purchase distribution
        CASE
            WHEN frequency = 1 THEN 1
            WHEN frequency = 2 THEN 2
            WHEN frequency = 3 THEN 3
            WHEN frequency BETWEEN 4 AND 5 THEN 4
            WHEN frequency >= 6 THEN 5
        END AS f_score,

        -- Higher monetary value is better
        NTILE(5) OVER (
            ORDER BY monetary ASC
        ) AS m_score

    FROM customer_rfm
)

SELECT TOP 20
    customer_unique_id,
    recency,
    frequency,
    ROUND(monetary, 2) AS monetary,
    r_score,
    f_score,
    m_score
FROM rfm_scores
ORDER BY
    r_score DESC,
    f_score DESC,
    m_score DESC;

    -- ============================================================
-- 10. RFM Customer Segmentation
-- ============================================================

DECLARE @analysis_date DATE = (
    SELECT DATEADD(DAY, 1, MAX(CAST(order_purchase_timestamp AS DATE)))
    FROM orders
    WHERE order_status = 'delivered'
);

WITH customer_rfm AS (
    SELECT
        c.customer_unique_id,

        DATEDIFF(
            DAY,
            MAX(CAST(o.order_purchase_timestamp AS DATE)),
            @analysis_date
        ) AS recency,

        COUNT(DISTINCT o.order_id) AS frequency,

        SUM(oi.price) AS monetary

    FROM customers c

    INNER JOIN orders o
        ON c.customer_id = o.customer_id

    INNER JOIN order_items oi
        ON o.order_id = oi.order_id

    WHERE o.order_status = 'delivered'

    GROUP BY c.customer_unique_id
),

rfm_scores AS (
    SELECT
        customer_unique_id,
        recency,
        frequency,
        monetary,

        6 - NTILE(5) OVER (
            ORDER BY recency ASC
        ) AS r_score,

        CASE
            WHEN frequency = 1 THEN 1
            WHEN frequency = 2 THEN 2
            WHEN frequency = 3 THEN 3
            WHEN frequency BETWEEN 4 AND 5 THEN 4
            WHEN frequency >= 6 THEN 5
        END AS f_score,

        NTILE(5) OVER (
            ORDER BY monetary ASC
        ) AS m_score

    FROM customer_rfm
),

rfm_segments AS (
    SELECT
        customer_unique_id,
        recency,
        frequency,
        monetary,
        r_score,
        f_score,
        m_score,

        CASE
            WHEN r_score >= 4
                 AND f_score >= 4
                 AND m_score >= 4
                THEN 'Champions'

            WHEN f_score >= 4
                 AND m_score >= 3
                THEN 'Loyal Customers'

            WHEN r_score >= 4
                 AND f_score BETWEEN 2 AND 3
                THEN 'Potential Loyalists'

            WHEN r_score <= 2
                 AND f_score >= 3
                THEN 'At Risk'

            WHEN r_score <= 2
                 AND f_score <= 2
                THEN 'Hibernating'

            ELSE 'Others'
        END AS customer_segment

    FROM rfm_scores
)

SELECT
    customer_segment,
    COUNT(*) AS customers,
    ROUND(AVG(CAST(recency AS FLOAT)), 2) AS avg_recency,
    ROUND(AVG(CAST(frequency AS FLOAT)), 2) AS avg_frequency,
    ROUND(AVG(monetary), 2) AS avg_monetary
FROM rfm_segments
GROUP BY customer_segment
ORDER BY customers DESC;

-- Finding:
-- Most customers fall into low-engagement segments.
-- Hibernating customers represent a large share of the customer base,
-- while Champions and Loyal Customers are very limited.
-- This is consistent with the low repeat purchase rate observed earlier.

-- ============================================================
-- 11. Customer Cohort Assignment
-- ============================================================

WITH first_purchase AS (
    SELECT
        c.customer_unique_id,
        MIN(o.order_purchase_timestamp) AS first_purchase_date
    FROM customers c
    INNER JOIN orders o
        ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
)

SELECT TOP 20
    customer_unique_id,
    first_purchase_date,
    DATEFROMPARTS(
        YEAR(first_purchase_date),
        MONTH(first_purchase_date),
        1
    ) AS cohort_month
FROM first_purchase
ORDER BY first_purchase_date;


-- ============================================================
-- 12. Cohort Month Index
-- ============================================================

WITH first_purchase AS (
    SELECT
        c.customer_unique_id,
        MIN(o.order_purchase_timestamp) AS first_purchase_date
    FROM customers c
    INNER JOIN orders o
        ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),

customer_orders AS (
    SELECT
        c.customer_unique_id,
        o.order_purchase_timestamp,
        fp.first_purchase_date,

        DATEFROMPARTS(
            YEAR(fp.first_purchase_date),
            MONTH(fp.first_purchase_date),
            1
        ) AS cohort_month,

        DATEFROMPARTS(
            YEAR(o.order_purchase_timestamp),
            MONTH(o.order_purchase_timestamp),
            1
        ) AS order_month

    FROM customers c
    INNER JOIN orders o
        ON c.customer_id = o.customer_id
    INNER JOIN first_purchase fp
        ON c.customer_unique_id = fp.customer_unique_id
    WHERE o.order_status = 'delivered'
)

SELECT TOP 30
    customer_unique_id,
    cohort_month,
    order_month,
    DATEDIFF(
        MONTH,
        cohort_month,
        order_month
    ) AS cohort_index
FROM customer_orders
ORDER BY
    customer_unique_id,
    order_month;


    -- ============================================================
-- 13. Cohort Retention Counts
-- ============================================================

WITH first_purchase AS (
    SELECT
        c.customer_unique_id,
        MIN(o.order_purchase_timestamp) AS first_purchase_date
    FROM customers c
    INNER JOIN orders o
        ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),

customer_orders AS (
    SELECT
        c.customer_unique_id,

        DATEFROMPARTS(
            YEAR(fp.first_purchase_date),
            MONTH(fp.first_purchase_date),
            1
        ) AS cohort_month,

        DATEFROMPARTS(
            YEAR(o.order_purchase_timestamp),
            MONTH(o.order_purchase_timestamp),
            1
        ) AS order_month

    FROM customers c
    INNER JOIN orders o
        ON c.customer_id = o.customer_id
    INNER JOIN first_purchase fp
        ON c.customer_unique_id = fp.customer_unique_id
    WHERE o.order_status = 'delivered'
),

cohort_data AS (
    SELECT
        customer_unique_id,
        cohort_month,
        DATEDIFF(
            MONTH,
            cohort_month,
            order_month
        ) AS cohort_index
    FROM customer_orders
)

SELECT
    cohort_month,
    cohort_index,
    COUNT(DISTINCT customer_unique_id) AS customers
FROM cohort_data
GROUP BY
    cohort_month,
    cohort_index
ORDER BY
    cohort_month,
    cohort_index;

    -- ============================================================
-- 14. Cohort Retention Rate
-- ============================================================

WITH first_purchase AS (
    SELECT
        c.customer_unique_id,
        MIN(o.order_purchase_timestamp) AS first_purchase_date
    FROM customers c
    INNER JOIN orders o
        ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),

customer_orders AS (
    SELECT
        c.customer_unique_id,

        DATEFROMPARTS(
            YEAR(fp.first_purchase_date),
            MONTH(fp.first_purchase_date),
            1
        ) AS cohort_month,

        DATEFROMPARTS(
            YEAR(o.order_purchase_timestamp),
            MONTH(o.order_purchase_timestamp),
            1
        ) AS order_month

    FROM customers c
    INNER JOIN orders o
        ON c.customer_id = o.customer_id
    INNER JOIN first_purchase fp
        ON c.customer_unique_id = fp.customer_unique_id
    WHERE o.order_status = 'delivered'
),

cohort_data AS (
    SELECT
        customer_unique_id,
        cohort_month,
        DATEDIFF(
            MONTH,
            cohort_month,
            order_month
        ) AS cohort_index
    FROM customer_orders
),

cohort_counts AS (
    SELECT
        cohort_month,
        cohort_index,
        COUNT(DISTINCT customer_unique_id) AS customers
    FROM cohort_data
    GROUP BY
        cohort_month,
        cohort_index
),

cohort_sizes AS (
    SELECT
        cohort_month,
        customers AS cohort_size
    FROM cohort_counts
    WHERE cohort_index = 0
)

SELECT
    cc.cohort_month,
    cc.cohort_index,
    cc.customers,
    cs.cohort_size,
    ROUND(
        100.0 * cc.customers / cs.cohort_size,
        2
    ) AS retention_rate
FROM cohort_counts cc
INNER JOIN cohort_sizes cs
    ON cc.cohort_month = cs.cohort_month
ORDER BY
    cc.cohort_month,
    cc.cohort_index;

    -- Finding:
-- Customer retention is consistently low across acquisition cohorts.
-- For most cohorts, less than 1% of customers return in the months
-- following their first purchase.
-- This is consistent with the 3.00% overall repeat purchase rate.