USE retail_promo;

-- 1. Join order: check which table the optimizer drives from
EXPLAIN
SELECT t.household_key, SUM(t.sales_value)
FROM fact_transaction t
JOIN dim_product p ON p.product_id = t.product_id
WHERE p.is_merchandise = 1
GROUP BY t.household_key;

-- 2. Same query with fact_transaction forced as the driving table
EXPLAIN
SELECT t.household_key, SUM(t.sales_value)
FROM fact_transaction t
STRAIGHT_JOIN dim_product p ON p.product_id = t.product_id
WHERE p.is_merchandise = 1
GROUP BY t.household_key;

-- 3. Index impact on the campaign window join (Q3 access path)
EXPLAIN
SELECT SUM(t.sales_value)
FROM campaign_household ch
JOIN dim_campaign c ON c.campaign_id = ch.campaign_id
JOIN fact_transaction t
     ON t.household_key = ch.household_key
    AND t.day_no BETWEEN c.start_day AND c.end_day;

-- 4. Actual runtime plan, MySQL 8.0.18+ only (MariaDB: use ANALYZE instead of EXPLAIN ANALYZE)
EXPLAIN ANALYZE
SELECT t.household_key, SUM(t.sales_value)
FROM fact_transaction t
STRAIGHT_JOIN dim_product p ON p.product_id = t.product_id
WHERE p.is_merchandise = 1
GROUP BY t.household_key;

-- 5. Refresh optimizer statistics after any bulk load
ANALYZE TABLE fact_transaction, dim_product;
