"""Download the NSW Fair Trading rental bond lodgement files listed in data/sources.csv.

Usage:
    python scripts/download_data.py            # skip files already downloaded
    python scripts/download_data.py --force    # download everything again
"""
import argparse
import csv
import time
from pathlib import Path

import requests

ROOT = Path(__file__).resolve().parent.parent
SOURCES = ROOT / "data" / "sources.csv"
RAW_DIR = ROOT / "data" / "raw"


def download(url: str, dest: Path, retries: int = 3) -> None:
    for attempt in range(1, retries + 1):
        try:
            with requests.get(url, timeout=120, stream=True,
                              headers={"User-Agent": "nsw-rental-market-sql/1.0"}) as r:
                r.raise_for_status()
                tmp = dest.with_suffix(dest.suffix + ".part")
                with open(tmp, "wb") as fh:
                    for chunk in r.iter_content(chunk_size=1 << 16):
                        fh.write(chunk)
                tmp.replace(dest)
                return
        except requests.RequestException as exc:
            if attempt == retries:
                raise
            print(f"  retry {attempt}/{retries} after error: {exc}")
            time.sleep(2 * attempt)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--force", action="store_true", help="re-download existing files")
    args = parser.parse_args()

    RAW_DIR.mkdir(parents=True, exist_ok=True)
    with open(SOURCES, newline="") as fh:
        rows = list(csv.DictReader(fh))

    for row in rows:
        dest = RAW_DIR / f"bonds_{row['period']}.xlsx"
        if dest.exists() and not args.force:
            print(f"[skip] {dest.name}")
            continue
        print(f"[get ] {dest.name}  <-  {row['url']}")
        download(row["url"], dest)
    print(f"Done: {len(rows)} source files in {RAW_DIR}")


if __name__ == "__main__":
    main()
