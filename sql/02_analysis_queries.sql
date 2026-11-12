USE retail_promo;

-- STRAIGHT_JOIN pins fact_transaction as the driving table (see 03_query_tuning.sql)

-- Q1. Department KPIs (merchandise only, departments with 1,000+ baskets)
SELECT p.department,
       COUNT(DISTINCT t.basket_id)                              AS baskets,
       ROUND(SUM(t.sales_value), 0)                             AS net_sales,
       ROUND(SUM(t.discount_amt), 0)                            AS retailer_discount,
       ROUND(100 * SUM(t.discount_amt) / SUM(t.gross_sales), 2) AS discount_rate_pct
FROM fact_transaction t
STRAIGHT_JOIN dim_product p ON p.product_id = t.product_id
WHERE p.is_merchandise = 1
GROUP BY p.department
HAVING baskets >= 1000
ORDER BY net_sales DESC;

-- Q2a. Weekly net sales with week-over-week growth
WITH weekly AS (
    SELECT t.week_no, SUM(t.sales_value) AS net_sales
    FROM fact_transaction t
    STRAIGHT_JOIN dim_product p ON p.product_id = t.product_id
    WHERE p.is_merchandise = 1
    GROUP BY t.week_no
)
SELECT week_no,
       ROUND(net_sales, 0) AS net_sales,
       ROUND(100 * (net_sales - LAG(net_sales) OVER (ORDER BY week_no))
                 / LAG(net_sales) OVER (ORDER BY week_no), 2) AS wow_growth_pct
FROM weekly
ORDER BY week_no;

-- Q2b. Top 3 commodities inside each department (commodities under $10K sales ignored)
WITH commodity_sales AS (
    SELECT p.department, p.commodity_desc, SUM(t.sales_value) AS net_sales
    FROM fact_transaction t
    STRAIGHT_JOIN dim_product p ON p.product_id = t.product_id
    WHERE p.is_merchandise = 1
    GROUP BY p.department, p.commodity_desc
    HAVING SUM(t.sales_value) >= 10000
),
ranked AS (
    SELECT department, commodity_desc, net_sales,
           DENSE_RANK() OVER (PARTITION BY department ORDER BY net_sales DESC) AS sales_rank
    FROM commodity_sales
)
SELECT department, commodity_desc, ROUND(net_sales, 0) AS net_sales, sales_rank
FROM ranked
WHERE sales_rank <= 3
ORDER BY department, sales_rank;

-- Q3. Campaign performance: redemption rate and spend of redeemers vs non-redeemers
-- reach is counted on every targeted household; spend is summed per household first,
-- so the coupon tables never fan out the transaction rows
WITH campaign_reach AS (
    SELECT campaign_id,
           COUNT(*)           AS targeted_households,
           SUM(redeemed_flag) AS redeemers
    FROM campaign_household
    GROUP BY campaign_id
),
campaign_spend AS (
    SELECT ch.campaign_id,
           ch.household_key,
           ch.redeemed_flag,
           SUM(t.sales_value) AS window_spend
    FROM campaign_household ch
    JOIN dim_campaign c ON c.campaign_id = ch.campaign_id
    JOIN fact_transaction t
         ON t.household_key = ch.household_key
        AND t.day_no BETWEEN c.start_day AND c.end_day
    STRAIGHT_JOIN dim_product p ON p.product_id = t.product_id AND p.is_merchandise = 1
    GROUP BY ch.campaign_id, ch.household_key, ch.redeemed_flag
),
campaign_avg_spend AS (
    SELECT campaign_id,
           AVG(CASE WHEN redeemed_flag = 1 THEN window_spend END) AS avg_spend_redeemers,
           AVG(CASE WHEN redeemed_flag = 0 THEN window_spend END) AS avg_spend_non_redeemers
    FROM campaign_spend
    GROUP BY campaign_id
)
SELECT c.campaign_id,
       c.campaign_type,
       r.targeted_households,
       r.redeemers,
       ROUND(100 * r.redeemers / r.targeted_households, 2) AS redemption_rate_pct,
       ROUND(a.avg_spend_redeemers, 2)                     AS avg_spend_redeemers,
       ROUND(a.avg_spend_non_redeemers, 2)                 AS avg_spend_non_redeemers
FROM dim_campaign c
JOIN campaign_reach r ON r.campaign_id = c.campaign_id
JOIN campaign_avg_spend a ON a.campaign_id = c.campaign_id
ORDER BY c.campaign_id;

-- Q4. Household segmentation by promo dependence (CASE WHEN)
WITH household_totals AS (
    SELECT t.household_key,
           SUM(t.sales_value)  AS net_sales,
           SUM(t.discount_amt) AS discount_amt,
           SUM(t.gross_sales)  AS gross_sales
    FROM fact_transaction t
    STRAIGHT_JOIN dim_product p ON p.product_id = t.product_id
    WHERE p.is_merchandise = 1
    GROUP BY t.household_key
),
segmented AS (
    SELECT household_key,
           net_sales,
           CASE
               WHEN discount_amt / gross_sales >= 0.20 THEN 'Promo Dependent'
               WHEN discount_amt / gross_sales >= 0.10 THEN 'Promo Responsive'
               ELSE 'Full Price Buyer'
           END AS promo_segment
    FROM household_totals
)
SELECT promo_segment,
       COUNT(*)                   AS households,
       ROUND(AVG(net_sales), 0)   AS avg_net_sales,
       ROUND(100 * SUM(net_sales) / SUM(SUM(net_sales)) OVER (), 1) AS share_of_sales_pct
FROM segmented
GROUP BY promo_segment
ORDER BY avg_net_sales DESC;
