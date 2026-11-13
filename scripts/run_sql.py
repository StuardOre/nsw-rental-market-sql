"""Run the SQL models in order against data/rentals.duckdb.

Usage:
    python scripts/run_sql.py              # run sql/0*.sql models
    python scripts/run_sql.py --analysis   # also run sql/analysis/*.sql and save results/*.csv
"""
import argparse
from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parent.parent
DB_PATH = ROOT / "data" / "rentals.duckdb"
SQL_DIR = ROOT / "sql"
RESULTS_DIR = ROOT / "results"


def run_models(con: duckdb.DuckDBPyConnection) -> None:
    for path in sorted(SQL_DIR.glob("0*.sql")):
        con.execute(path.read_text())
        print(f"[model] {path.name}")


def run_analysis(con: duckdb.DuckDBPyConnection) -> None:
    RESULTS_DIR.mkdir(exist_ok=True)
    for path in sorted((SQL_DIR / "analysis").glob("*.sql")):
        df = con.execute(path.read_text()).df()
        out = RESULTS_DIR / f"{path.stem}.csv"
        df.to_csv(out, index=False)
        print(f"[query] {path.name:<40} -> results/{out.name} ({len(df)} rows)")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--analysis", action="store_true", help="also run the analysis queries")
    args = parser.parse_args()

    if not DB_PATH.exists():
        raise SystemExit("data/rentals.duckdb not found. Run scripts/load_raw.py first.")
    con = duckdb.connect(str(DB_PATH))
    run_models(con)
    print(con.sql("SELECT * FROM dq_checks"))
    if args.analysis:
        run_analysis(con)
    con.close()


if __name__ == "__main__":
    main()
