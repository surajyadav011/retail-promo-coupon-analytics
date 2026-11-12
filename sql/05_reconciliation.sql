USE retail_promo;

-- R1. Merchandise scope: the base for every dashboard KPI
-- target: net 7393261.48, gross 8778913.45, discount 1385651.97, rate 15.78, baskets 251552, households 2500
SELECT ROUND(SUM(t.sales_value), 2)  AS net_sales,
       ROUND(SUM(t.gross_sales), 2)  AS gross_sales,
       ROUND(SUM(t.discount_amt), 2) AS retailer_discount,
       ROUND(100 * SUM(t.discount_amt) / SUM(t.gross_sales), 2) AS discount_rate_pct,
       COUNT(DISTINCT t.basket_id)   AS baskets,
       COUNT(DISTINCT t.household_key) AS households
FROM fact_transaction t
STRAIGHT_JOIN dim_product p ON p.product_id = t.product_id
WHERE p.is_merchandise = 1;

-- R2. Overall coupon redemption rate
-- target: 889 redeemed of 7208 targeted = 12.33
SELECT SUM(redeemed_flag) AS redeemed_pairs,
       COUNT(*)           AS targeted_pairs,
       ROUND(100 * SUM(redeemed_flag) / COUNT(*), 2) AS redemption_rate_pct
FROM campaign_household;

-- R3. Promo-dependent households (discount rate >= 20%)
-- target: 519 households, 1282517.57 net sales, 17.35% of merchandise net sales
WITH household_totals AS (
    SELECT t.household_key,
           SUM(t.sales_value)  AS net_sales,
           SUM(t.discount_amt) AS discount_amt,
           SUM(t.gross_sales)  AS gross_sales
    FROM fact_transaction t
    STRAIGHT_JOIN dim_product p ON p.product_id = t.product_id
    WHERE p.is_merchandise = 1
    GROUP BY t.household_key
)
SELECT COUNT(*)                                   AS promo_dependent_households,
       ROUND(SUM(net_sales), 2)                   AS promo_dependent_sales,
       ROUND(100 * SUM(net_sales) / (SELECT SUM(net_sales) FROM household_totals), 2) AS share_of_sales_pct
FROM household_totals
WHERE discount_amt / gross_sales >= 0.20;

-- R4. Grain trap: coupon_product holds many rows per product
-- target: wrong 13819963.19 (2.96x), right 4672434.13
SELECT 'wrong: join coupon rows to sales' AS method, ROUND(SUM(t.sales_value), 2) AS net_sales
FROM coupon_product cp
JOIN fact_transaction t ON t.product_id = cp.product_id
STRAIGHT_JOIN dim_product p ON p.product_id = t.product_id AND p.is_merchandise = 1
UNION ALL
SELECT 'right: distinct couponed products', ROUND(SUM(t.sales_value), 2)
FROM fact_transaction t
STRAIGHT_JOIN dim_product p ON p.product_id = t.product_id AND p.is_merchandise = 1
WHERE t.product_id IN (SELECT DISTINCT product_id FROM coupon_product);

-- R5. Average weekly net sales from week 16 (after the ramp-up)
-- target: 87 weeks, 79258.80
SELECT COUNT(*) AS weeks, ROUND(AVG(net_sales), 2) AS avg_weekly_net_sales
FROM (
    SELECT t.week_no, SUM(t.sales_value) AS net_sales
    FROM fact_transaction t
    STRAIGHT_JOIN dim_product p ON p.product_id = t.product_id
    WHERE p.is_merchandise = 1 AND t.week_no >= 16
    GROUP BY t.week_no
) weekly;
