import os
from pathlib import Path
import pandas as pd
from sqlalchemy import create_engine, text

PROCESSED = Path("data/processed")
DB_URL = os.environ["MYSQL_URL"]

# Parents first, so foreign keys are satisfied during load
LOAD_ORDER = [
    "dim_product",
    "dim_household",
    "dim_campaign",
    "campaign_household",
    "coupon_product",
    "coupon_redemption",
    "fact_transaction",
    "product_promo_week",
]


FACT_CHUNK_ROWS = 25_000


def load_table(engine, name):
    df = pd.read_parquet(PROCESSED / f"{name}.parquet")
    df = df.astype(object).where(df.notna(), None)
    
    with engine.connect() as conn:
    
        conn.execute(text("SET FOREIGN_KEY_CHECKS = 0;"))
        conn.execute(text(f"TRUNCATE TABLE {name};"))
        conn.commit()

    # Load data in safe chunks
    df.to_sql(name, engine, if_exists="append", index=False, chunksize=FACT_CHUNK_ROWS)
    
    with engine.connect() as conn:
        conn.execute(text("SET FOREIGN_KEY_CHECKS = 1;"))
        conn.commit()
        loaded = conn.execute(text(f"SELECT COUNT(*) FROM {name}")).scalar()
        
    print(f"{name}: {loaded:,} rows loaded successfully")


def main():
    engine = create_engine(DB_URL)
    print("Starting MySQL Data Loading Pipeline...")
    for name in LOAD_ORDER:
        load_table(engine, name)
    print("All tables successfully loaded into MySQL!")


if __name__ == "__main__":
    main()