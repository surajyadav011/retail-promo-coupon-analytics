# Retail Promotion & Coupon ROI Analytics

Find out which discounts and coupon campaigns really work. This project cleans 2.6 million retail transactions with Python, stores them in MySQL, and shows the results in a two-page Power BI dashboard.

![Python](https://img.shields.io/badge/Python-3.12%20%7C%203.14-3776AB?logo=python&logoColor=white) ![MySQL](https://img.shields.io/badge/MySQL-8-4479A1?logo=mysql&logoColor=white) ![Power BI](https://img.shields.io/badge/Power%20BI-DAX-F2C811?logo=powerbi&logoColor=black) ![Tests](https://img.shields.io/badge/tests-6%20passing-brightgreen) ![License](https://img.shields.io/badge/license-MIT-blue)

<p align="center">
  <img src="docs/screenshots/executive_overview.png" alt="Power BI executive overview dashboard" width="900">
</p>

## Quick start
Get the dataset first (see [Dataset](#dataset)) and put the eight CSV files in `data/raw/`. Then run:

```bash
git clone https://github.com/surajyadav011/retail-promo-coupon-analytics.git
cd retail-promo-coupon-analytics
pip install -r requirements.txt
python src/prepare_data.py
pytest tests -q
```

You should see this:

```text
Starting Data Pipeline...
dim_product: 92,353 rows exported
...
fact_transaction: 2,581,266 rows exported
product_promo_week: 2,049,187 rows exported
Pipeline Execution Complete!
6 passed
```

## What is this project?
It answers four questions about a grocery retailer:

1. Which departments rely most on discounts?
2. Which campaign types bring shoppers back?
3. Do coupon users really spend more?
4. How much of the revenue comes from deal hunters?

The data has 2,500 households, 30 campaigns and 102 weeks. It comes from the dunnhumby "The Complete Journey" set.

## Key features
- **Clean data:** voids removed, fuel and misc lines flagged, a 36.8M-row file cut to 2.05M rows.
- **Fast files:** 808 MB of CSV becomes about 36 MB of Parquet.
- **MySQL model:** 8 tables with keys and indexes, and a loader you can re-run.
- **SQL analysis:** CTEs, window functions and CASE logic, in five scripts.
- **Power BI report:** 7 tables, 10 DAX measures and a household segment column.
- **Safe numbers:** 6 automated tests and SQL checks that must match the dashboard.

## Key findings
All figures use merchandise lines only (fuel and misc are left out).

| Metric | Result |
|---|---|
| Net sales | **$7,393,261.48** |
| Retailer discount rate | **15.78%** of shelf-price sales |
| Most discounted departments | Meat 24.4%, packaged meat 22.5%, packaged seafood 25.3% |
| Promo-dependent households | **519 of 2,500 (21%)**, with **17.35%** of net sales |
| Coupon redemption rate | **12.33%** (889 of 7,208 targeted pairs) |
| Redemption by type | Type A **15.96%**, Type B 7.91%, Type C 7.67% |
| Coupon-eligible products | 63.2% of net sales ($4.67M) |

Redeemers outspend other households in 24 of 30 campaigns. That is not proof the coupons worked. Coupon users were already the most active shoppers.

**A trap worth knowing:** one product sits on many coupon rows. A direct join to sales counts it again and again. It shows $13.82M of coupon sales when the true figure is $4.67M. The Power BI model avoids this with `TREATAS`.

## Dashboard
Open `powerbi/Retail_Promotion_Analytics_Dashboard.pbix` in Power BI Desktop (Windows). It has two pages.

- **Executive Overview:** four KPI cards, net sales by department, redemption by campaign type, sales by household segment, weekly trend and a department table.
- **Coupon Analysis:** coupon sales by department, redemption by campaign, a daily redemption trend and a campaign table.

<p align="center">
  <img src="docs/screenshots/coupon_analysis.png" alt="Power BI coupon analysis dashboard" width="900">
</p>

The report reads Parquet files from the author's folder. To use your own copy, go to **Home > Transform data > Data source settings > Change Source**. Point each table to your `data/processed` folder and click **Refresh**.

## How it works
```mermaid
flowchart LR
    A["8 CSV files<br/>808 MB"] --> B["Python<br/>prepare_data.py"]
    B --> C["Parquet<br/>about 36 MB"]
    C --> D["MySQL<br/>8 tables"]
    C --> E["Excel extracts<br/>mis_inputs.xlsx"]
    C --> F["Power BI<br/>7 tables, DAX"]
    D --> G["SQL analysis<br/>and checks"]
```

## Prerequisites
| Tool | Version | Check it |
|---|---|---|
| Python | 3.12 or newer | `python --version` |
| MySQL | 8 or newer (for the SQL part) | `mysql --version` |
| Git | any recent | `git --version` |
| Power BI Desktop | current (Windows only, for the report) | open the `.pbix` file |

## Installation
Use a virtual environment so the packages stay in one place.

```bash
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
```

On macOS or Linux, activate with `source .venv/bin/activate`. To check it worked, run `python -c "import pandas, pyarrow, pandera; print('ok')"`. It prints `ok`.

## Dataset
The data is not stored in this repo. Download **dunnhumby - The Complete Journey** from [dunnhumby](https://www.dunnhumby.com/source-files/) (a copy is also on Kaggle). Read its terms of use first. Put these files in `data/raw/`:

```text
campaign_desc.csv     campaign_table.csv   causal_data.csv    coupon.csv
coupon_redempt.csv    hh_demographic.csv   product.csv        transaction_data.csv
```

`causal_data.csv` is about 664 MB with 36.8M rows. The script reads it in chunks, so it fits in normal memory.

## Usage
Run each step from the project root.

| Step | Command | What you get |
|---|---|---|
| 1. Clean data | `python src/prepare_data.py` | 8 Parquet files in `data/processed/` |
| 2. Create tables | `mysql -u root -p -e "source sql/01_schema.sql"` | Empty MySQL tables |
| 3. Load tables | `python src/load_mysql.py` | Row counts for each table |
| 4. Run analysis | `mysql -u root -p retail_promo -e "source sql/02_analysis_queries.sql"` | KPI, trend, campaign and segment results |
| 5. Check data | `mysql -u root -p -e "source sql/04_validation.sql"` | Zero violations |
| 6. Check numbers | `mysql -u root -p -e "source sql/05_reconciliation.sql"` | The targets in this README |
| 7. Excel inputs | `python src/export_excel_inputs.py` | `excel/mis_inputs.xlsx` |
| 8. Run tests | `pytest tests -q` | `6 passed` |

Run `pytest` from the project root. The tests use relative paths.

## Configuration
Only one setting is needed. The loader reads the MySQL address from an environment variable, so no password is stored in the code.

| Name | Default | What it does |
|---|---|---|
| `MYSQL_URL` | none (required) | Connection string for `src/load_mysql.py` |

Set it before step 3. In Windows `cmd`:

```bat
set MYSQL_URL=mysql+pymysql://USER:PASSWORD@localhost:3306/retail_promo
```

In PowerShell use `$env:MYSQL_URL = "..."`. On macOS or Linux use `export MYSQL_URL="..."`. Replace `USER` and `PASSWORD` with your own. If the password has special characters, URL-encode them. The loader empties each table first, so you can run it again safely.

## Examples
**Example 1: see which departments depend on discounts.** Run `sql/02_analysis_queries.sql` and read the first result. It lists net sales, discount and discount rate per department. Meat is near 24%. Drug and general merchandise is near 9%.

**Example 2: prove the coupon trap.** Run `sql/05_reconciliation.sql` and find the result with two rows. The wrong join shows 13,819,963.19. The right method shows 4,672,434.13.

**Example 3: check every table loaded.** Run `sql/04_validation.sql`. Each check that must be zero should show 0. Net sales should read 8,057,443.80 for all lines.

## Data model
```mermaid
erDiagram
    dim_product ||--o{ fact_transaction : product_id
    dim_household ||--o{ fact_transaction : household_key
    dim_household ||--o{ campaign_household : household_key
    dim_campaign ||--o{ campaign_household : campaign_id
    dim_household ||--o{ coupon_redemption : household_key
    dim_campaign ||--o{ coupon_redemption : campaign_id
    dim_product ||--o{ coupon_product : product_id
    dim_campaign ||--o{ coupon_product : campaign_id
    dim_product ||--o{ product_promo_week : product_id
```
The fact table key is `(basket_id, product_id)`. It has three B-Tree indexes: `(household_key, day_no)`, `(product_id, week_no)` and `(week_no)`. `basket_id` is `BIGINT UNSIGNED` and money columns are `DECIMAL(8,2)`.

## How the data is cleaned
| Problem | Rows | What was done |
|---|---|---|
| Zero-quantity lines (voids) | 14,466 | Removed |
| Fuel and misc lines, with quantities up to 89,638 | 28,052 | Kept, flagged `is_merchandise = 0`, left out of KPIs |
| Products with no department | 15 | Labelled `UNKNOWN` |
| Households with no demographics | 1,699 | Kept, labelled `Unknown` |
| Duplicate coupon rows | 5,164 | Removed |
| Huge causal file | 36.8M | Read in chunks, rolled up to product by week |

Three features are added. `gross_sales` rebuilds the shelf price as `sales_value - retail_disc - coupon_match_disc`. `discount_pct` is the discount divided by gross sales. `redeemed_flag` marks households that used a coupon from a campaign they were sent.

Net sales match the raw file to the cent: $8,057,463.08 minus $19.28 of voids gives $8,057,443.80.

## SQL analysis
| Script | Technique | Answers |
|---|---|---|
| `02_analysis_queries.sql` Q1 | `GROUP BY`, `HAVING` | Sales and discount rate by department |
| Q2 | `LAG`, `DENSE_RANK` | Weekly growth and top items per department |
| Q3 | Multi-step CTEs | Redemption rate and spend per campaign |
| Q4 | `CASE WHEN` | Promo dependent, responsive and full price households |
| `03_query_tuning.sql` | `EXPLAIN`, `STRAIGHT_JOIN` | Fixes a slow join order |

The optimizer first scanned the small product table. It then made millions of random lookups into the fact table. Forcing the fact table to lead with `STRAIGHT_JOIN` fixed this. Check the plan again on your own server, because plans change as data grows.

## Power BI model and DAX
The model has 7 tables and 8 relationships. All are many-to-one, single direction and active. The sales table is not linked to the campaign tables on purpose. Campaigns belong to households and date windows, not to single sales lines.

| Measure | How it works |
|---|---|
| `Net Sales`, `Gross Sales`, `Retailer Discount` | `CALCULATE` with the merchandise filter |
| `Discount Rate %` | Total discount divided by total gross sales |
| `Baskets`, `Avg Basket Value` | Distinct baskets and value per basket |
| `Redemption Rate %` | Redeemed pairs divided by targeted pairs |
| `Couponed Product Sales` | `TREATAS` counts each coupon product once |
| `Promo Dependent Households`, `Promo Dependent Sales Share %` | `SUMMARIZE` to one row per household, then filter at 20% |
| `promo_segment` (column) | `SWITCH` into three household groups |

The key measure avoids the coupon trap:

```dax
Couponed Product Sales =
CALCULATE (
    [Net Sales],
    TREATAS ( VALUES ( coupon_product[product_id] ), dim_product[product_id] )
)
```

Three joins that go wrong:

| Join | Wrong total | Right total |
|---|---|---|
| Coupon products to sales | $13.82M (2.96x) | $4.67M |
| Campaign households to sales | $39.97M (5.41x) | $7.39M |
| Average of line discount percents | 13.64% | 15.78% (ratio of sums) |

## Data quality
`tests/test_data_quality.py` runs six checks: schema and ranges, row count, no orphan products, no orphan households, redemptions map to real coupons, and unique coupon keys. The SQL scripts `04_validation.sql` and `05_reconciliation.sql` repeat these checks in the database. The dashboard cards, SQL results and Parquet files agree on net sales, discount rate, redemption rate and promo-dependent share.

## Troubleshooting
| Error you see | Fix |
|---|---|
| `FileNotFoundError: data/raw/...csv` | Put all eight CSV files in `data/raw/` |
| `KeyError: 'MYSQL_URL'` | Set the variable in the same terminal, then run the loader again |
| `Access denied for user` | Check the user and password in `MYSQL_URL` |
| `Cannot add or update a child row` | Run `sql/01_schema.sql` first, and load tables in the loader's order |
| Tests cannot find files | Run `pytest` from the project root, after `prepare_data.py` |
| Power BI cannot find the data | Use **Change Source** to point to your `data/processed` folder |

## Limits
- There is no cost data. Results show revenue and discount spend, not profit.
- Redeemer spend is correlation, not lift. A control group is needed to prove lift.
- Weeks 1 to 15 show a sales ramp-up, so trend charts start at week 16.
- Store-level promo detail is lost when the causal file is rolled up.

## Roadmap
- Measure real coupon lift with a control group.
- Add cost data to move from revenue to profit.
- Add a product-level discount analysis.
- Add a scenario sheet in Excel for discount cuts.

## Contributing
Ideas and fixes are welcome. Fork the repo, create a branch, make your change and run `pytest tests -q`. Then open a pull request that says what you changed and why.

## License
Released under the [MIT License](LICENSE). The dataset belongs to dunnhumby and is not included here.

## Author
**Suraj** - data analytics.
[LinkedIn](https://www.linkedin.com/in/suraj--a332332b5) | [GitHub](https://github.com/surajyadav011)
