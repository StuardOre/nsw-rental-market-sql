"""Load the raw NSW rental bond lodgement workbooks into DuckDB, untouched.

Every value is stored as text in `raw_lodgements`, together with the file it
came from, so all typing and cleaning happens in SQL (see sql/01_staging.sql)
and can be audited.

Usage:
    python scripts/load_raw.py
"""
from datetime import date, datetime
from pathlib import Path

import duckdb
import pandas as pd
from openpyxl import load_workbook

ROOT = Path(__file__).resolve().parent.parent
RAW_DIR = ROOT / "data" / "raw"
DB_PATH = ROOT / "data" / "rentals.duckdb"

EXPECTED_HEADER = ["Lodgement Date", "Postcode", "Dwelling Type", "Bedrooms", "Weekly Rent"]
COLUMNS = ["lodgement_date", "postcode", "dwelling_type", "bedrooms", "weekly_rent"]


def as_text(value) -> str | None:
    """Return a cell as text; dates become ISO strings, empty cells become None."""
    if value is None:
        return None
    if isinstance(value, (datetime, date)):
        return value.strftime("%Y-%m-%d")
    text = str(value).strip()
    return text or None


def read_workbook(path: Path) -> pd.DataFrame:
    """Read the first sheet, find the header row and return the data rows as text."""
    wb = load_workbook(path, read_only=True, data_only=True)
    ws = wb[wb.sheetnames[0]]
    rows, header_found = [], False
    for row in ws.iter_rows(values_only=True):
        cells = list(row[:5])
        if not header_found:
            if [as_text(c) for c in cells] == EXPECTED_HEADER:
                header_found = True
            continue
        if all(c is None for c in cells):
            continue
        rows.append([as_text(c) for c in cells])
    wb.close()
    if not header_found:
        raise ValueError(f"{path.name}: header row {EXPECTED_HEADER} not found")
    df = pd.DataFrame(rows, columns=COLUMNS)
    df["source_file"] = path.name
    return df


def main() -> None:
    files = sorted(RAW_DIR.glob("bonds_*.xlsx"))
    if not files:
        raise SystemExit("No files in data/raw. Run scripts/download_data.py first.")

    con = duckdb.connect(str(DB_PATH))
    con.execute("DROP TABLE IF EXISTS raw_lodgements")
    con.execute("""
        CREATE TABLE raw_lodgements (
            lodgement_date VARCHAR, postcode VARCHAR, dwelling_type VARCHAR,
            bedrooms VARCHAR, weekly_rent VARCHAR, source_file VARCHAR
        )
    """)
    total = 0
    for path in files:
        df = read_workbook(path)
        con.register("batch", df)
        con.execute("INSERT INTO raw_lodgements SELECT * FROM batch")
        con.unregister("batch")
        total += len(df)
        print(f"[load] {path.name:<22} {len(df):>9,} rows")
    con.close()
    print(f"Loaded {total:,} rows into {DB_PATH.name}:raw_lodgements")


if __name__ == "__main__":
    main()
