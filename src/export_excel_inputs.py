from pathlib import Path

import pandas as pd

PROCESSED = Path("data/processed")
OUT = Path("excel/mis_inputs.xlsx")
MIN_DEPT_BASKETS = 1000


def load(name):
    return pd.read_parquet(PROCESSED / f"{name}.parquet")


def merchandise_lines():
    fact = load("fact_transaction")
    products = load("dim_product")[["product_id", "department", "is_merchandise"]]
    lines = fact.merge(products, on="product_id")
    return lines[lines["is_merchandise"] == 1]


def department_kpi(lines):
    df = lines.groupby("department").agg(
        baskets=("basket_id", "nunique"),
        gross_sales=("gross_sales", "sum"),
        discount_amt=("discount_amt", "sum"),
        net_sales=("sales_value", "sum"),
    )
    df = df[df["baskets"] >= MIN_DEPT_BASKETS].round(2)
    return df.sort_values("net_sales", ascending=False).reset_index()


def weekly_kpi(lines):
    df = lines.groupby("week_no").agg(
        baskets=("basket_id", "nunique"),
        gross_sales=("gross_sales", "sum"),
        discount_amt=("discount_amt", "sum"),
        net_sales=("sales_value", "sum"),
    )
    return df.round(2).reset_index()


def campaign_kpi(lines):
    campaigns = load("dim_campaign")
    targeted = load("campaign_household")
    window = targeted.merge(campaigns, on="campaign_id").merge(
        lines[["household_key", "day_no", "sales_value"]], on="household_key"
    )
    window = window[window["day_no"].between(window["start_day"], window["end_day"])]
    keys = ["campaign_id", "household_key", "redeemed_flag"]
    spend = window.groupby(keys, as_index=False)["sales_value"].sum()

    summary = targeted.groupby("campaign_id").agg(
        targeted_hh=("household_key", "size"), redeemers=("redeemed_flag", "sum")
    )
    avg_spend = spend.pivot_table(
        index="campaign_id", columns="redeemed_flag", values="sales_value", aggfunc="mean"
    )
    avg_spend.columns = ["avg_spend_non_redeemers", "avg_spend_redeemers"]
    df = campaigns.merge(summary, on="campaign_id").merge(avg_spend.reset_index(), on="campaign_id")
    return df.round(2)


def main():
    OUT.parent.mkdir(exist_ok=True)
    lines = merchandise_lines()
    with pd.ExcelWriter(OUT) as writer:
        department_kpi(lines).to_excel(writer, sheet_name="Data_Dept", index=False)
        campaign_kpi(lines).to_excel(writer, sheet_name="Data_Campaign", index=False)
        weekly_kpi(lines).to_excel(writer, sheet_name="Data_Weekly", index=False)
    print(f"written {OUT}")


if __name__ == "__main__":
    main()
