-- ============================================================
-- Project: Olist E-Commerce Analytics
-- File: 05_product_analysis.sql
-- Purpose:
--   Analyze product and category performance using delivered orders,
--   including sales volume, revenue, seller performance and reviews.
--
-- Main metrics:
--   - Top products by revenue
--   - Top products by units sold
--   - Category performance
--   - Average product price
--   - Seller concentration
--   - Review score by category
--   - High-sales products with low review scores
-- ============================================================

USE olist_ecommerce;
GO

-- ============================================================
-- 1. Top Products by Revenue
-- ============================================================

SELECT TOP 10
    oi.product_id,
    COUNT(*) AS items_sold,
    ROUND(SUM(oi.price), 2) AS revenue
FROM order_items oi
INNER JOIN orders o
    ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY oi.product_id
ORDER BY revenue DESC;

-- Finding:
-- The top revenue-generating product generated 63,560.00
-- from 194 delivered order items.

-- ============================================================
-- 2. Top Products by Units Sold
-- ============================================================

SELECT TOP 10
    oi.product_id,
    COUNT(*) AS items_sold,
    ROUND(SUM(oi.price), 2) AS revenue
FROM order_items oi
INNER JOIN orders o
    ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY oi.product_id
ORDER BY items_sold DESC;

-- Finding:
-- The best-selling product by units sold is not the highest-revenue product.
-- The top-selling product sold 520 units and generated 37,104.30 in revenue,
-- showing that sales volume and product value contribute differently to performance.

-- ============================================================
-- 3. Top Products with Category
-- ============================================================

SELECT TOP 10
    oi.product_id,
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
    oi.product_id,
    COALESCE(
        ct.product_category_name_english,
        p.product_category_name,
        'Unknown'
    )
ORDER BY revenue DESC;

-- Finding:
-- The two highest-revenue products belong to the health_beauty category,
-- reinforcing its position as the leading category by total revenue.
-- However, other top products come from computers, bed_bath_table,
-- baby, cool_stuff and watches_gifts, showing a diversified product mix.


-- ============================================================
-- 4. Average Product Price by Category
-- ============================================================

SELECT TOP 10
    COALESCE(
        ct.product_category_name_english,
        p.product_category_name,
        'Unknown'
    ) AS category_name,
    COUNT(*) AS items_sold,
    ROUND(AVG(oi.price), 2) AS average_price,
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
ORDER BY average_price DESC;

-- Finding:
-- Computers has the highest average selling price (1,098.92),
-- but relatively low sales volume.
-- In contrast, watches_gifts combines a lower average price
-- with very high sales volume, generating substantially more revenue.

-- ============================================================
-- 5. Average Review Score by Category
-- ============================================================

SELECT TOP 10
    COALESCE(
        ct.product_category_name_english,
        p.product_category_name,
        'Unknown'
    ) AS category_name,
    COUNT(DISTINCT r.review_id) AS total_reviews,
    ROUND(AVG(CAST(r.review_score AS FLOAT)), 2) AS average_review_score
FROM order_items oi
INNER JOIN orders o
    ON oi.order_id = o.order_id
INNER JOIN products p
    ON oi.product_id = p.product_id
LEFT JOIN category_translation ct
    ON p.product_category_name = ct.product_category_name
INNER JOIN order_reviews r
    ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
GROUP BY
    COALESCE(
        ct.product_category_name_english,
        p.product_category_name,
        'Unknown'
    )
HAVING COUNT(DISTINCT r.review_id) >= 20
ORDER BY average_review_score DESC;

-- Finding:
-- books_imported has the highest average review score (4.51)
-- among categories with at least 20 reviews.

-- ============================================================
-- 6. Lowest-Rated Categories
-- ============================================================

SELECT TOP 10
    COALESCE(
        ct.product_category_name_english,
        p.product_category_name,
        'Unknown'
    ) AS category_name,
    COUNT(DISTINCT r.review_id) AS total_reviews,
    ROUND(AVG(CAST(r.review_score AS FLOAT)), 2) AS average_review_score
FROM order_items oi
INNER JOIN orders o
    ON oi.order_id = o.order_id
INNER JOIN products p
    ON oi.product_id = p.product_id
LEFT JOIN category_translation ct
    ON p.product_category_name = ct.product_category_name
INNER JOIN order_reviews r
    ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
GROUP BY
    COALESCE(
        ct.product_category_name_english,
        p.product_category_name,
        'Unknown'
    )
HAVING COUNT(DISTINCT r.review_id) >= 20
ORDER BY average_review_score ASC;

-- Finding:
-- diapers_and_hygiene has the lowest average review score (3.38),
-- although it is based on only 25 reviews.
-- office_furniture shows a more substantial satisfaction issue,
-- with an average score of 3.52 across 1,246 reviews.
-- bed_bath_table also deserves attention because it combines
-- high sales volume with a relatively low average review score (3.92).


-- ============================================================
-- 7. Category Revenue vs Customer Satisfaction
-- ============================================================

WITH category_sales AS (
    SELECT
        COALESCE(
            ct.product_category_name_english,
            p.product_category_name,
            'Unknown'
        ) AS category_name,
        COUNT(*) AS items_sold,
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
),

category_reviews AS (
    SELECT
        COALESCE(
            ct.product_category_name_english,
            p.product_category_name,
            'Unknown'
        ) AS category_name,
        COUNT(DISTINCT r.review_id) AS total_reviews,
        AVG(CAST(r.review_score AS FLOAT)) AS average_review_score
    FROM order_items oi
    INNER JOIN orders o
        ON oi.order_id = o.order_id
    INNER JOIN products p
        ON oi.product_id = p.product_id
    LEFT JOIN category_translation ct
        ON p.product_category_name = ct.product_category_name
    INNER JOIN order_reviews r
        ON o.order_id = r.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY
        COALESCE(
            ct.product_category_name_english,
            p.product_category_name,
            'Unknown'
        )
)

SELECT TOP 15
    cs.category_name,
    cs.items_sold,
    ROUND(cs.revenue, 2) AS revenue,
    cr.total_reviews,
    ROUND(cr.average_review_score, 2) AS average_review_score
FROM category_sales cs
INNER JOIN category_reviews cr
    ON cs.category_name = cr.category_name
WHERE cr.total_reviews >= 100
ORDER BY cs.revenue DESC;



-- Finding:
-- office_furniture shows the clearest combination of meaningful revenue
-- and low customer satisfaction, with 268,154.31 in revenue and an
-- average review score of 3.52 across 1,246 reviews.
--
-- bed_bath_table and furniture_decor also deserve attention because
-- they generate high revenue while maintaining below-average review scores.


-- ============================================================
-- 8. High-Sales Products with Low Review Scores
-- ============================================================

WITH product_sales AS (
    SELECT
        oi.product_id,
        COUNT(*) AS items_sold,
        SUM(oi.price) AS revenue
    FROM order_items oi
    INNER JOIN orders o
        ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY oi.product_id
),

product_reviews AS (
    SELECT
        oi.product_id,
        COUNT(DISTINCT r.review_id) AS total_reviews,
        AVG(CAST(r.review_score AS FLOAT)) AS average_review_score
    FROM order_items oi
    INNER JOIN orders o
        ON oi.order_id = o.order_id
    INNER JOIN order_reviews r
        ON o.order_id = r.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY oi.product_id
)

SELECT TOP 15
    ps.product_id,
    ps.items_sold,
    ROUND(ps.revenue, 2) AS revenue,
    pr.total_reviews,
    ROUND(pr.average_review_score, 2) AS average_review_score
FROM product_sales ps
INNER JOIN product_reviews pr
    ON ps.product_id = pr.product_id
WHERE ps.items_sold >= 50
  AND pr.total_reviews >= 30
ORDER BY
    average_review_score ASC,
    revenue DESC;

    -- Finding:
-- Several high-volume products show relatively low customer satisfaction.
-- The product 89b121bee266dcd25688a1ba72eefb61 stands out with
-- 63 units sold, 57 reviews and an average review score of only 2.49.
--
-- These products should be prioritized for further investigation,
-- since they combine meaningful sales activity with weak customer feedback.

-- ============================================================
-- 9. Low-Rated High-Sales Products with Category
-- ============================================================

WITH product_sales AS (
    SELECT
        oi.product_id,
        COUNT(*) AS items_sold,
        SUM(oi.price) AS revenue
    FROM order_items oi
    INNER JOIN orders o
        ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY oi.product_id
),

product_reviews AS (
    SELECT
        oi.product_id,
        COUNT(DISTINCT r.review_id) AS total_reviews,
        AVG(CAST(r.review_score AS FLOAT)) AS average_review_score
    FROM order_items oi
    INNER JOIN orders o
        ON oi.order_id = o.order_id
    INNER JOIN order_reviews r
        ON o.order_id = r.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY oi.product_id
)

SELECT TOP 15
    ps.product_id,

    COALESCE(
        ct.product_category_name_english,
        p.product_category_name,
        'Unknown'
    ) AS category_name,

    ps.items_sold,
    ROUND(ps.revenue, 2) AS revenue,
    pr.total_reviews,
    ROUND(pr.average_review_score, 2) AS average_review_score

FROM product_sales ps

INNER JOIN product_reviews pr
    ON ps.product_id = pr.product_id

INNER JOIN products p
    ON ps.product_id = p.product_id

LEFT JOIN category_translation ct
    ON p.product_category_name = ct.product_category_name

WHERE ps.items_sold >= 50
  AND pr.total_reviews >= 30

ORDER BY
    average_review_score ASC,
    revenue DESC;


    -- Finding:
-- Low-rated high-sales products are concentrated in a few categories,
-- especially office_furniture and computers_accessories.
-- This suggests that customer satisfaction issues may be category-specific
-- rather than isolated to individual products.
--
-- The lowest-rated high-sales product belongs to computers_accessories,
-- with an average review score of 2.49 across 57 reviews.