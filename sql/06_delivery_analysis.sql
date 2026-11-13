-- ============================================================
-- Project: Olist E-Commerce Analytics
-- File: 06_delivery_analysis.sql
-- Purpose:
--   Analyze delivery performance, freight costs and the
--   relationship between logistics and customer satisfaction.
--
-- Main metrics:
--   - Average delivery time
--   - Late delivery rate
--   - Delivery time by customer state
--   - Freight value by state
--   - Delivery delay vs review score
-- ============================================================

USE olist_ecommerce;
GO

-- ============================================================
-- 1. Average Delivery Time
-- ============================================================

SELECT
    ROUND(
        AVG(
            CAST(
                DATEDIFF(
                    DAY,
                    order_purchase_timestamp,
                    order_delivered_customer_date
                ) AS FLOAT
            )
        ),
        2
    ) AS average_delivery_days
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL;

  -- Finding:
-- Delivered orders take an average of 12.5 days
-- from purchase to customer delivery.

-- ============================================================
-- 2. Late Delivery Rate
-- ============================================================

SELECT
    COUNT(*) AS delivered_orders,
    SUM(
        CASE
            WHEN CAST(order_delivered_customer_date AS DATE)
                 > CAST(order_estimated_delivery_date AS DATE)
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
-- 6,534 delivered orders arrived after the estimated delivery date,
-- resulting in a late delivery rate of 6.77%.

-- ============================================================
-- 3. Average Delivery Time by Customer State
-- ============================================================

SELECT
    c.customer_state,
    COUNT(*) AS delivered_orders,
    ROUND(
        AVG(
            CAST(
                DATEDIFF(
                    DAY,
                    o.order_purchase_timestamp,
                    o.order_delivered_customer_date
                ) AS FLOAT
            )
        ),
        2
    ) AS average_delivery_days
FROM orders o
INNER JOIN customers c
    ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
GROUP BY c.customer_state
ORDER BY average_delivery_days DESC;

-- Finding:
-- Delivery performance varies significantly by customer state.
-- RR has the longest average delivery time at 29.34 days,
-- while SP has the shortest among high-volume states at 8.70 days.
-- This suggests a strong geographic effect on logistics performance.

-- ============================================================
-- 4. Late Delivery Rate by Customer State
-- ============================================================

SELECT
    c.customer_state,
    COUNT(*) AS delivered_orders,

    SUM(
        CASE
            WHEN CAST(o.order_delivered_customer_date AS DATE)
                 > CAST(o.order_estimated_delivery_date AS DATE)
            THEN 1
            ELSE 0
        END
    ) AS late_deliveries,

    ROUND(
        100.0 *
        SUM(
            CASE
                WHEN CAST(o.order_delivered_customer_date AS DATE)
                     > CAST(o.order_estimated_delivery_date AS DATE)
                THEN 1
                ELSE 0
            END
        ) / COUNT(*),
        2
    ) AS late_delivery_rate

FROM orders o

INNER JOIN customers c
    ON o.customer_id = c.customer_id

WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL

GROUP BY c.customer_state

ORDER BY late_delivery_rate DESC;

-- Finding:
-- Late delivery performance varies significantly by state.
-- AL has the highest late delivery rate at 21.41%,
-- followed by MA at 17.43%.
-- In contrast, high-volume states such as SP, MG and PR
-- maintain substantially lower late delivery rates.

-- ============================================================
-- 5. Average Freight Value by Customer State
-- ============================================================

SELECT
    c.customer_state,
    COUNT(DISTINCT o.order_id) AS delivered_orders,
    ROUND(AVG(CAST(oi.freight_value AS FLOAT)), 2) AS average_freight_value,
    ROUND(SUM(oi.freight_value), 2) AS total_freight_value
FROM orders o
INNER JOIN customers c
    ON o.customer_id = c.customer_id
INNER JOIN order_items oi
    ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_state
ORDER BY average_freight_value DESC;

-- Finding:
-- Average freight value varies significantly by customer state.
-- PB and RR have the highest average freight value at 43.09,
-- while SP has a much lower average of 15.12.
-- This suggests that geographic distance and logistics complexity
-- have a strong impact on shipping costs.

-- ============================================================
-- 6. Delivery Delay vs Review Score
-- ============================================================

SELECT
    CASE
        WHEN CAST(o.order_delivered_customer_date AS DATE)
             > CAST(o.order_estimated_delivery_date AS DATE)
            THEN 'Late'
        ELSE 'On Time'
    END AS delivery_status,

    COUNT(DISTINCT o.order_id) AS total_orders,

    ROUND(
        AVG(CAST(r.review_score AS FLOAT)),
        2
    ) AS average_review_score

FROM orders o

INNER JOIN order_reviews r
    ON o.order_id = r.order_id

WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL

GROUP BY
    CASE
        WHEN CAST(o.order_delivered_customer_date AS DATE)
             > CAST(o.order_estimated_delivery_date AS DATE)
            THEN 'Late'
        ELSE 'On Time'
    END;
  

  -- Finding:
-- Late deliveries are strongly associated with lower customer satisfaction.
-- Orders delivered after the estimated delivery date have an average
-- review score of 2.27, compared with 4.29 for on-time deliveries.
-- This highlights delivery performance as an important factor
-- in the customer experience.

-- ============================================================
-- 7. Review Score by Delay Severity
-- ============================================================

SELECT
    CASE
        WHEN DATEDIFF(
            DAY,
            o.order_estimated_delivery_date,
            o.order_delivered_customer_date
        ) <= 0
            THEN 'On Time'

        WHEN DATEDIFF(
            DAY,
            o.order_estimated_delivery_date,
            o.order_delivered_customer_date
        ) BETWEEN 1 AND 3
            THEN '1-3 Days Late'

        WHEN DATEDIFF(
            DAY,
            o.order_estimated_delivery_date,
            o.order_delivered_customer_date
        ) BETWEEN 4 AND 7
            THEN '4-7 Days Late'

        WHEN DATEDIFF(
            DAY,
            o.order_estimated_delivery_date,
            o.order_delivered_customer_date
        ) BETWEEN 8 AND 14
            THEN '8-14 Days Late'

        ELSE '15+ Days Late'
    END AS delay_group,

    COUNT(DISTINCT o.order_id) AS total_orders,

    ROUND(
        AVG(CAST(r.review_score AS FLOAT)),
        2
    ) AS average_review_score

FROM orders o

INNER JOIN order_reviews r
    ON o.order_id = r.order_id

WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL

GROUP BY
    CASE
        WHEN DATEDIFF(
            DAY,
            o.order_estimated_delivery_date,
            o.order_delivered_customer_date
        ) <= 0
            THEN 'On Time'

        WHEN DATEDIFF(
            DAY,
            o.order_estimated_delivery_date,
            o.order_delivered_customer_date
        ) BETWEEN 1 AND 3
            THEN '1-3 Days Late'

        WHEN DATEDIFF(
            DAY,
            o.order_estimated_delivery_date,
            o.order_delivered_customer_date
        ) BETWEEN 4 AND 7
            THEN '4-7 Days Late'

        WHEN DATEDIFF(
            DAY,
            o.order_estimated_delivery_date,
            o.order_delivered_customer_date
        ) BETWEEN 8 AND 14
            THEN '8-14 Days Late'

        ELSE '15+ Days Late'
    END;

    -- Finding:
-- Customer satisfaction declines sharply as delivery delays increase.
-- On-time deliveries have an average review score of 4.29,
-- while orders delayed by 4-7 days average only 2.10.
-- Orders delayed by more than one week receive average scores
-- below 2.0, highlighting the strong impact of severe delivery delays
-- on customer satisfaction.

-- ============================================================
-- 8. Average Delivery Time by Review Score
-- ============================================================

SELECT
    r.review_score,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(
        AVG(
            CAST(
                DATEDIFF(
                    DAY,
                    o.order_purchase_timestamp,
                    o.order_delivered_customer_date
                ) AS FLOAT
            )
        ),
        2
    ) AS average_delivery_days
FROM orders o
INNER JOIN order_reviews r
    ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
GROUP BY r.review_score
ORDER BY r.review_score;

-- Finding:
-- Average delivery time decreases consistently as review scores improve.
-- Orders rated 1 star take an average of 21.25 days to arrive,
-- compared with only 10.63 days for 5-star reviews.
-- This reinforces the strong relationship between delivery performance
-- and customer satisfaction.