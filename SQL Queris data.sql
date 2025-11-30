

-- Q1: Top 10 categories by total revenue

WITH cat_rev AS (
  SELECT
    category,
    SUM(purchase_amount)::numeric(12,2) AS total_revenue,
    COUNT(*) AS orders,
    AVG(purchase_amount)::numeric(12,2) AS avg_order_value
  FROM customer
  WHERE category IS NOT NULL
  GROUP BY category
)
SELECT category, total_revenue, orders, avg_order_value
FROM cat_rev
ORDER BY total_revenue DESC
LIMIT 10;





-- Q2: Avg order value for discounted vs non-discounted, per category
WITH flag AS (
  SELECT
    category,
    -- normalize discount text to boolean
    CASE
      WHEN lower(trim(coalesce(discount_applied,''))) IN ('yes','y','true','1') THEN true
      WHEN lower(trim(coalesce(discount_applied,''))) IN ('no','n','false','0') THEN false
      ELSE NULL
    END AS discount_flag,
    purchase_amount
  FROM customer
)
SELECT
  category,
  discount_flag,
  COUNT(*) AS orders,
  ROUND(AVG(purchase_amount)::numeric,2) AS avg_purchase_amount,
  ROUND(STDDEV_POP(purchase_amount)::numeric,2) AS stddev_amount
FROM flag
WHERE category IS NOT NULL
GROUP BY category, discount_flag
ORDER BY category, discount_flag NULLS LAST;


-- Q3: Payment method counts, revenue and avg order value
SELECT
  payment_method,
  COUNT(*) AS orders,
  SUM(purchase_amount)::numeric(12,2) AS total_revenue,
  ROUND(AVG(purchase_amount)::numeric,2) AS avg_order_value
FROM customer
WHERE payment_method IS NOT NULL
GROUP BY payment_method
ORDER BY orders DESC;


-- Q4: Top 20 customers by lifetime spend
WITH customer_spend AS (
  SELECT
    customer_id,
    COUNT(*) AS orders,
    SUM(purchase_amount)::numeric(12,2) AS total_spent,
    AVG(purchase_amount)::numeric(12,2) AS avg_order_value,
    MAX(previous_purchases) AS reported_previous_purchases
  FROM customer
  GROUP BY customer_id
)
SELECT customer_id, orders, total_spent, avg_order_value, reported_previous_purchases
FROM customer_spend
ORDER BY total_spent DESC
LIMIT 20;

-- Q5: Customer segmentation by previous_purchases
WITH customer_type AS (
  SELECT 
    customer_id,
    previous_purchases,
    CASE 
      WHEN previous_purchases IS NULL OR previous_purchases <= 1 THEN 'New'
      WHEN previous_purchases BETWEEN 2 AND 10 THEN 'Returning'
      ELSE 'Loyal'
    END AS customer_segment
  FROM customer
)
SELECT 
  customer_segment,
  COUNT(*) AS number_of_customers
FROM customer_type
GROUP BY customer_segment
ORDER BY number_of_customers DESC;

-- Q6: Subscription status vs avg previous purchases and AOV
SELECT
  subscription_status,
  COUNT(DISTINCT customer_id) AS distinct_customers,
  ROUND(AVG(previous_purchases)::numeric,2) AS avg_previous_purchases,
  ROUND(AVG(purchase_amount)::numeric,2) AS avg_order_value,
  SUM(purchase_amount)::numeric(12,2) AS total_revenue
FROM customer
GROUP BY subscription_status
ORDER BY avg_previous_purchases DESC NULLS LAST;


-- Q7: Discount dependency per category (percentage of orders with discount)
WITH category_stats AS (
  SELECT 
    category,
    COUNT(*) AS total_orders,
    COUNT(*) FILTER (
      WHERE lower(trim(coalesce(discount_applied,''))) IN ('yes','y','true','1')
    ) AS discounted_orders
  FROM customer
  WHERE category IS NOT NULL
  GROUP BY category
)
SELECT 
  category,
  total_orders,
  discounted_orders,
  ROUND((discounted_orders::numeric / NULLIF(total_orders,0)) * 100, 2) AS discount_dependency_pct
FROM category_stats
ORDER BY discount_dependency_pct DESC;


-- Q8: Top 3 size-color combinations by orders for each category
WITH combo AS (
  SELECT
    category,
    size,
    color,
    COUNT(*) AS orders
  FROM customer
  WHERE category IS NOT NULL
  GROUP BY category, size, color
)
SELECT category, size, color, orders
FROM (
  SELECT *,
         ROW_NUMBER() OVER (PARTITION BY category ORDER BY orders DESC) AS rn
  FROM combo
) t
WHERE rn <= 3
ORDER BY category, orders DESC;


-- Q9: Avg review rating by shipping_type and payment_method (only stable groups)
SELECT
  shipping_type,
  payment_method,
  COUNT(*) AS orders,
  ROUND(AVG(review_rating)::numeric,2) AS avg_rating
FROM customer
WHERE review_rating IS NOT NULL
GROUP BY shipping_type, payment_method
HAVING COUNT(*) >= 10
ORDER BY avg_rating DESC NULLS LAST;

-- Q10: Avg and median (50th percentile) purchase_frequency_days by category
SELECT
  category,
  COUNT(*) AS orders,
  ROUND(AVG(purchase_frequency_days)::numeric,2) AS avg_freq_days,
  ROUND(
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY purchase_frequency_days)::numeric,
    2
  ) AS median_freq_days
FROM customer
WHERE purchase_frequency_days IS NOT NULL
GROUP BY category
ORDER BY avg_freq_days NULLS LAST;

