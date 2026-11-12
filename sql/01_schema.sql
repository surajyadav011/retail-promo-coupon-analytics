CREATE DATABASE IF NOT EXISTS retail_promo
    DEFAULT CHARACTER SET utf8mb4;
USE retail_promo;

DROP TABLE IF EXISTS product_promo_week;
DROP TABLE IF EXISTS coupon_redemption;
DROP TABLE IF EXISTS coupon_product;
DROP TABLE IF EXISTS campaign_household;
DROP TABLE IF EXISTS fact_transaction;
DROP TABLE IF EXISTS dim_campaign;
DROP TABLE IF EXISTS dim_household;
DROP TABLE IF EXISTS dim_product;

CREATE TABLE dim_product (
    product_id          INT UNSIGNED NOT NULL,
    manufacturer        INT UNSIGNED NOT NULL,
    department          VARCHAR(30) NOT NULL,
    brand               VARCHAR(10) NOT NULL,
    commodity_desc      VARCHAR(60) NULL,
    sub_commodity_desc  VARCHAR(80) NULL,
    curr_size_of_product VARCHAR(20) NULL,
    is_merchandise      TINYINT UNSIGNED NOT NULL,
    PRIMARY KEY (product_id),
    KEY idx_product_department (department, commodity_desc)
) ENGINE=InnoDB;

CREATE TABLE dim_household (
    household_key        SMALLINT UNSIGNED NOT NULL,
    age_desc             VARCHAR(10) NOT NULL,
    marital_status_code  CHAR(7) NOT NULL,
    income_desc          VARCHAR(10) NOT NULL,
    homeowner_desc       VARCHAR(20) NOT NULL,
    hh_comp_desc         VARCHAR(30) NOT NULL,
    household_size_desc  VARCHAR(10) NOT NULL,
    kid_category_desc    VARCHAR(20) NOT NULL,
    has_demographics     TINYINT UNSIGNED NOT NULL,
    PRIMARY KEY (household_key)
) ENGINE=InnoDB;

CREATE TABLE dim_campaign (
    campaign_id    TINYINT UNSIGNED NOT NULL,
    campaign_type  CHAR(5) NOT NULL,
    start_day      SMALLINT UNSIGNED NOT NULL,
    end_day        SMALLINT UNSIGNED NOT NULL,
    PRIMARY KEY (campaign_id),
    CHECK (end_day >= start_day)
) ENGINE=InnoDB;

CREATE TABLE fact_transaction (
    basket_id          BIGINT UNSIGNED NOT NULL,
    product_id         INT UNSIGNED NOT NULL,
    household_key      SMALLINT UNSIGNED NOT NULL,
    store_id           INT UNSIGNED NOT NULL,
    day_no             SMALLINT UNSIGNED NOT NULL,
    week_no            TINYINT UNSIGNED NOT NULL,
    trans_time         SMALLINT UNSIGNED NOT NULL,
    quantity           INT UNSIGNED NOT NULL,
    sales_value        DECIMAL(8,2) NOT NULL,
    retail_disc        DECIMAL(8,2) NOT NULL,
    coupon_disc        DECIMAL(8,2) NOT NULL,
    coupon_match_disc  DECIMAL(8,2) NOT NULL,
    gross_sales        DECIMAL(9,2) NOT NULL,
    discount_amt       DECIMAL(9,2) NOT NULL,
    discount_pct       DECIMAL(6,4) NULL,
    is_coupon_line     TINYINT UNSIGNED NOT NULL,
    PRIMARY KEY (basket_id, product_id),
    KEY idx_txn_household_day (household_key, day_no),
    KEY idx_txn_product_week (product_id, week_no),
    KEY idx_txn_week (week_no),
    CONSTRAINT fk_txn_product FOREIGN KEY (product_id) REFERENCES dim_product (product_id),
    CONSTRAINT fk_txn_household FOREIGN KEY (household_key) REFERENCES dim_household (household_key)
) ENGINE=InnoDB;

CREATE TABLE campaign_household (
    household_key  SMALLINT UNSIGNED NOT NULL,
    campaign_id    TINYINT UNSIGNED NOT NULL,
    redeemed_flag  TINYINT UNSIGNED NOT NULL,
    PRIMARY KEY (household_key, campaign_id),
    KEY idx_ch_campaign (campaign_id),
    CONSTRAINT fk_ch_household FOREIGN KEY (household_key) REFERENCES dim_household (household_key),
    CONSTRAINT fk_ch_campaign FOREIGN KEY (campaign_id) REFERENCES dim_campaign (campaign_id)
) ENGINE=InnoDB;

CREATE TABLE coupon_product (
    campaign_id  TINYINT UNSIGNED NOT NULL,
    coupon_upc   BIGINT UNSIGNED NOT NULL,
    product_id   INT UNSIGNED NOT NULL,
    PRIMARY KEY (campaign_id, coupon_upc, product_id),
    KEY idx_cp_product (product_id),
    CONSTRAINT fk_cp_campaign FOREIGN KEY (campaign_id) REFERENCES dim_campaign (campaign_id),
    CONSTRAINT fk_cp_product FOREIGN KEY (product_id) REFERENCES dim_product (product_id)
) ENGINE=InnoDB;

CREATE TABLE coupon_redemption (
    household_key  SMALLINT UNSIGNED NOT NULL,
    day_no         SMALLINT UNSIGNED NOT NULL,
    coupon_upc     BIGINT UNSIGNED NOT NULL,
    campaign_id    TINYINT UNSIGNED NOT NULL,
    PRIMARY KEY (household_key, day_no, coupon_upc, campaign_id),
    KEY idx_cr_campaign (campaign_id),
    CONSTRAINT fk_cr_household FOREIGN KEY (household_key) REFERENCES dim_household (household_key),
    CONSTRAINT fk_cr_campaign FOREIGN KEY (campaign_id) REFERENCES dim_campaign (campaign_id)
) ENGINE=InnoDB;

CREATE TABLE product_promo_week (
    product_id         INT UNSIGNED NOT NULL,
    week_no            TINYINT UNSIGNED NOT NULL,
    stores_on_display  SMALLINT UNSIGNED NOT NULL,
    stores_on_mailer   SMALLINT UNSIGNED NOT NULL,
    stores_tracked     SMALLINT UNSIGNED NOT NULL,
    PRIMARY KEY (product_id, week_no),
    CONSTRAINT fk_ppw_product FOREIGN KEY (product_id) REFERENCES dim_product (product_id)
) ENGINE=InnoDB;
