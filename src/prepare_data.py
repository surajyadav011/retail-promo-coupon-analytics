from pathlib import Path
import pandas as pd

# Phase 1: Retail Data Ingestion, Cleaning & Parquet Pipeline,ETL

RAW = Path("data/raw")
OUT = Path("data/processed")
NON_MERCH_DEPTS = ["KIOSK-GAS", "MISC SALES TRAN"]
CAUSAL_CHUNK_ROWS = 2_000_000


def read_raw(name, **kwargs):
    df = pd.read_csv(RAW / f"{name}.csv", **kwargs)
    df.columns = df.columns.str.lower()
    return df


def build_products():
    df = read_raw("product", dtype=str, keep_default_na=False)
    df = df.apply(lambda col: col.str.strip()).replace("", pd.NA)
    df["product_id"] = df["product_id"].astype("int64")
    df["manufacturer"] = df["manufacturer"].astype("int64")
    
    # Label 15 products that have structural blank departments

    df["department"] = df["department"].fillna("UNKNOWN")
    
    # Flag non-merchandise (fuel/misc) to exclude from main KPIs later
    df["is_merchandise"] = (~df["department"].isin(NON_MERCH_DEPTS)).astype("int8")
    return df


def build_transactions(products):
    df = read_raw("transaction_data")
    df = df.rename(columns={"day": "day_no"})
    
    # zero-quantity rows are voids, no sale happened
    df = df[df["quantity"] > 0].copy()

    # sales_value is net of discounts, so shelf price is rebuilt by adding them back
    df["gross_sales"] = (df["sales_value"] - df["retail_disc"] - df["coupon_match_disc"]).round(2)
    df["discount_amt"] = -(df["retail_disc"] + df["coupon_match_disc"]).round(2)
    df["discount_pct"] = (df["discount_amt"] / df["gross_sales"]).where(df["gross_sales"] > 0).round(4)
    
    # Manufacturer coupon is separate from retailer discount
    df["is_coupon_line"] = (df["coupon_disc"] < 0).astype("int8")

    assert not df.duplicated(["basket_id", "product_id"]).any(), "duplicate basket/product keys"
    assert df["product_id"].isin(products["product_id"]).all(), "orphan product_id in transactions"
    return df


def build_households(transactions):
    demo = read_raw("hh_demographic")
    households = pd.DataFrame({"household_key": sorted(transactions["household_key"].unique())})
    df = households.merge(demo, on="household_key", how="left")
    df["has_demographics"] = df["age_desc"].notna().astype("int8")
    
    # Keep households without demographics to avoid losing 68% of the customer base
    demo_cols = [col for col in demo.columns if col != "household_key"]
    df[demo_cols] = df[demo_cols].fillna("Unknown")
    return df


def build_campaign_households():
    targeted = read_raw("campaign_table")
    redeemed = read_raw("coupon_redempt")[["household_key", "campaign"]].drop_duplicates()
    redeemed["redeemed_flag"] = 1
    
    # Left join to flag targeted households that actually redeemed a coupon
    df = targeted.merge(redeemed, on=["household_key", "campaign"], how="left")
    df["redeemed_flag"] = df["redeemed_flag"].fillna(0).astype("int8")
    return df.drop(columns="description")


def build_promo_weekly():
    # causal_data is 36M rows, so each chunk is rolled up to product x week before combining
    parts = []
    reader = pd.read_csv(
        RAW / "causal_data.csv", dtype={"display": str, "mailer": str}, chunksize=CAUSAL_CHUNK_ROWS
    )
    for chunk in reader:
        chunk.columns = chunk.columns.str.lower()
        chunk["on_display"] = chunk["display"] != "0"
        chunk["on_mailer"] = chunk["mailer"] != "0"
        parts.append(
            chunk.groupby(["product_id", "week_no"], as_index=False).agg(
                stores_on_display=("on_display", "sum"),
                stores_on_mailer=("on_mailer", "sum"),
                stores_tracked=("on_display", "size"),
            )
        )
    return pd.concat(parts).groupby(["product_id", "week_no"], as_index=False).sum()


def save(df, name):
    df.to_parquet(OUT / f"{name}.parquet", index=False)
    print(f"{name}: {len(df):,} rows exported")


def main():
    print("Starting Data Pipeline...")
    OUT.mkdir(parents=True, exist_ok=True)
    products = build_products()
    transactions = build_transactions(products)

    campaigns = read_raw("campaign_desc").rename(
        columns={"campaign": "campaign_id", "description": "campaign_type"}
    )
    coupons = read_raw("coupon").drop_duplicates().rename(columns={"campaign": "campaign_id"})
    redemptions = read_raw("coupon_redempt").rename(columns={"campaign": "campaign_id", "day": "day_no"})
    campaign_hh = build_campaign_households().rename(columns={"campaign": "campaign_id"})

    save(products, "dim_product")
    save(build_households(transactions), "dim_household")
    save(campaigns, "dim_campaign")
    save(campaign_hh, "campaign_household")
    save(coupons, "coupon_product")
    save(redemptions, "coupon_redemption")
    save(transactions, "fact_transaction")
    save(build_promo_weekly(), "product_promo_week")
    print("Pipeline Execution Complete!")


if __name__ == "__main__":
    main()