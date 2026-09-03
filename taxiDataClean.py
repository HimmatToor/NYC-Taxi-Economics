import pandas as pd
from pathlib import Path

DATA_DIR = Path("TaxiData/yellowTaxiData")

files = sorted(DATA_DIR.glob("*.parquet"))

print(f"Found {len(files)} files\n")

for file in files:
    df = pd.read_parquet(file)

    print("=" * 80)
    print(file.name)
    print(f"Rows: {len(df):,}")
    print(f"Columns: {len(df.columns)}")
    print("\nColumns:")
    print(df.columns.tolist())
    print("\nData types:")
    print(df.dtypes)
    print(df.head())
    print()