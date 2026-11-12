USE retail_promo;

-- V1. Row counts per table
SELECT 'fact_transaction' AS table_name, COUNT(*) AS row_count FROM fact_transaction
UNION ALL SELECT 'dim_product', COUNT(*) FROM dim_product
UNION ALL SELECT 'dim_household', COUNT(*) FROM dim_household
UNION ALL SELECT 'campaign_household', COUNT(*) FROM campaign_household
UNION ALL SELECT 'coupon_product', COUNT(*) FROM coupon_product
UNION ALL SELECT 'coupon_redemption', COUNT(*) FROM coupon_redemption
UNION ALL SELECT 'product_promo_week', COUNT(*) FROM product_promo_week;

-- V2. Orphan check: expect 0 for every row
SELECT 'txn_without_product' AS check_name, COUNT(*) AS violations
FROM fact_transaction t LEFT JOIN dim_product p ON p.product_id = t.product_id
WHERE p.product_id IS NULL
UNION ALL
SELECT 'txn_without_household', COUNT(*)
FROM fact_transaction t LEFT JOIN dim_household h ON h.household_key = t.household_key
WHERE h.household_key IS NULL
UNION ALL
SELECT 'redemption_without_coupon', COUNT(*)
FROM coupon_redemption r
LEFT JOIN (SELECT DISTINCT campaign_id, coupon_upc FROM coupon_product) c
       ON c.campaign_id = r.campaign_id AND c.coupon_upc = r.coupon_upc
WHERE c.coupon_upc IS NULL;

-- V3. Business rule checks: expect 0 for every row
SELECT 'non_positive_quantity' AS check_name, COUNT(*) AS violations FROM fact_transaction WHERE quantity <= 0
UNION ALL SELECT 'negative_sales', COUNT(*) FROM fact_transaction WHERE sales_value < 0
UNION ALL SELECT 'discount_pct_above_100', COUNT(*) FROM fact_transaction WHERE discount_pct > 1
UNION ALL SELECT 'campaign_end_before_start', COUNT(*) FROM dim_campaign WHERE end_day < start_day;

-- V4. Totals that must match the raw file after removing voids
-- target: net_sales 8057443.80, baskets 275889, households 2500
SELECT ROUND(SUM(sales_value), 2) AS net_sales,
       ROUND(SUM(gross_sales), 2) AS gross_sales,
       ROUND(SUM(discount_amt), 2) AS retailer_discount,
       COUNT(DISTINCT basket_id) AS baskets,
       COUNT(DISTINCT household_key) AS households
FROM fact_transaction;

-- V5. Structural NULLs: discount_pct is NULL only when gross_sales = 0
SELECT SUM(discount_pct IS NULL) AS null_discount_pct,
       SUM(gross_sales = 0) AS zero_gross_rows
FROM fact_transaction;
