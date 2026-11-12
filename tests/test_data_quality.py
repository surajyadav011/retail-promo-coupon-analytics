from pathlib import Path

import pandas as pd
import pandera.pandas as pa
import pytest

PROCESSED = Path("data/processed")


def load(name):
    return pd.read_parquet(PROCESSED / f"{name}.parquet")


@pytest.fixture(scope="module")
def fact():
    return load("fact_transaction")


def test_fact_schema(fact):
    schema = pa.DataFrameSchema(
        {
            "basket_id": pa.Column(int, pa.Check.gt(0)),
            "quantity": pa.Column(int, pa.Check.gt(0)),
            "sales_value": pa.Column(float, pa.Check.ge(0)),
            "gross_sales": pa.Column(float, pa.Check.ge(0)),
            "discount_pct": pa.Column(float, pa.Check.le(1), nullable=True),
            "week_no": pa.Column(int, pa.Check.in_range(1, 102)),
        },
        unique=["basket_id", "product_id"],
    )
    schema.validate(fact)


def test_fact_row_count_reconciles(fact):
    # 2,595,732 raw rows minus 14,466 zero-quantity voids
    assert len(fact) == 2_581_266


def test_no_orphan_products(fact):
    assert fact["product_id"].isin(load("dim_product")["product_id"]).all()


def test_no_orphan_households(fact):
    assert fact["household_key"].isin(load("dim_household")["household_key"]).all()


def test_redemptions_map_to_known_coupons():
    redemptions = load("coupon_redemption")
    coupons = load("coupon_product")[["coupon_upc", "campaign_id"]].drop_duplicates()
    merged = redemptions.merge(coupons, on=["coupon_upc", "campaign_id"], how="left", indicator=True)
    assert (merged["_merge"] == "both").all()


def test_coupon_product_key_is_unique():
    assert not load("coupon_product").duplicated(["campaign_id", "coupon_upc", "product_id"]).any()
