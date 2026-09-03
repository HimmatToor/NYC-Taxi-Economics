from pathlib import Path

DATA_DIR = Path(__file__).resolve().parent.parent / "TaxiData"

YELLOW_DIR = DATA_DIR / "yellowTaxiData"
GREEN_DIR = DATA_DIR / "greenTaxiData"


def list_files(taxi_type: str) -> list[Path]:
    """Return sorted parquet file paths for 'yellow' or 'green'."""
    directory = YELLOW_DIR if taxi_type == "yellow" else GREEN_DIR
    return sorted(directory.glob("*.parquet"))


def month_from_filename(path: Path) -> str:
    """'yellow_tripdata_2025-03.parquet' -> '2025-03'"""
    return path.stem.split("_")[-1]
