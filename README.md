# NSW Rental Market Analysis with SQL (DuckDB)

How much does a new lease cost in New South Wales, and how fast are rents moving? This project answers that with **SQL on 1.5 million real rental bond lodgements** published by NSW Fair Trading (January 2022 to October 2026).

Every new tenancy in NSW must lodge a bond, and each lodgement records the postcode, dwelling type, number of bedrooms and weekly rent. That makes the bond data one of the most complete public sources on rents for new leases in Australia.

## Pipeline

```
NSW Fair Trading XLSX files ──► scripts/download_data.py ──► data/raw/
                                       │
                         scripts/load_raw.py (all columns as text)
                                       ▼
                     DuckDB  raw_lodgements  (1,572,293 rows)
                                       │  sql/01_staging.sql
                                       ▼
            stg_lodgements  +  v_residential (analysis-ready view)
                                       │  sql/02_data_quality.sql
                                       ▼
                         dq_checks (one row per data-quality check)
```

Raw values are loaded as text and every cleaning rule lives in SQL, so each decision can be read and audited in one place.

## Data quality (current load)

| Check | Rows | % of rows |
|---|---:|---:|
| Rows loaded | 1,572,293 | 100.00 |
| Dwelling type unknown (U) | 50,465 | 3.21 |
| Bedrooms unknown | 38,441 | 2.44 |
| Weekly rent unknown (U) | 21,318 | 1.36 |
| Weekly rent outside $50-$5,000 (flagged, kept) | 1,247 | 0.08 |
| Dwelling/bedroom columns swapped in source (fixed) | 37 | 0.00 |
| Rows in analysis view `v_residential` | 1,445,552 | 91.94 |

`v_residential` keeps flats/units, houses and terraces/townhouses with a known number of bedrooms and a plausible rent. Rooms, garages and car spaces (dwelling type "Other") are excluded.

## Run it

```bash
pip install -r requirements.txt
python scripts/download_data.py   # 14 XLSX files listed in data/sources.csv (about 40 MB)
python scripts/load_raw.py        # about 1 minute
python scripts/run_sql.py         # builds staging tables and the data-quality log
```

## Project structure

```
data/sources.csv        official download links (one file per year or month)
scripts/                download, load and SQL runner
sql/01_staging.sql      typing, cleaning rules and the analysis view
sql/02_data_quality.sql data-quality log
```

## Roadmap

- [x] Ingestion of 14 source files into DuckDB
- [x] Staging model with documented cleaning rules and data-quality log
- [ ] Rent marts: monthly medians by dwelling and size, postcode trends, affordability bands
- [ ] Interactive dashboard published with GitHub Pages
- [ ] Automated tests for the SQL models

## Source and licence

Data: NSW Fair Trading, [Rental bond data](https://www.nsw.gov.au/housing-and-construction/rental-forms-surveys-and-data/rental-bond-data), Creative Commons Attribution. Bond lodgements cover new tenancies only, so they describe rents for new leases rather than all existing rents.
