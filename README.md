# NSW Rental Market Analysis with SQL (DuckDB)

How much does a new lease cost in New South Wales, and how fast are rents moving? This project answers that with **SQL on 1.5 million real rental bond lodgements** published by NSW Fair Trading (January 2022 to October 2026).

Every new tenancy in NSW must lodge a bond, and each lodgement records the postcode, dwelling type, number of bedrooms and weekly rent. That makes the bond data one of the most complete public sources on rents for new leases in Australia.

## Key findings

Periods are rolling 12-month windows ending in October 2026, the latest month in the data. All figures are medians of new leases (homes with a known size and a plausible rent).

1. **Rents for new leases rose 21% in three years.** The NSW median weekly rent went from **$600** (Nov 2022 - Oct 2023) to **$725** (Nov 2025 - Oct 2026). In January - October 2022 it was $535.
2. **Growth is slowing.** Year-on-year growth eased from 8.3% to 7.7% and then **3.6%** in the latest 12 months. In the latest year flats rose 7.1% and houses 2.9%.
3. **Cheaper leases are disappearing.** Leases under $500 a week fell from **28.4%** of new leases to **13.4%** in three years (40.7% in January - October 2022). Leases of $1,000 or more grew from 10.1% to **18.2%**.
4. **Rents rose almost everywhere.** For two-bedroom flats, the median rose in **257 of 272 postcodes** with enough data (30+ new leases in each year) and fell in only 7. The typical postcode moved +5.3%.
5. **A two-bedroom flat now rents for more than a three-bedroom house, but only on average.** NSW-wide, the median two-bedroom flat ($760) is above the median three-bedroom house ($650). Postcode by postcode, the house rents for more in **247 of 249** postcodes. The reversal is a mix effect: 80% of two-bedroom flat leases are in postcodes 2000-2249 (most of metropolitan Sydney), against 28% of three-bedroom house leases.
6. **February is the peak of the leasing year.** It has the most new leases (9.2% of the year) and the highest rents against trend (+2.2%). April is the quietest month (7.4%) and the cheapest (-1.2%).

Full query outputs are in [`results/`](results/).

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
                                       │  sql/02_data_quality.sql ──► dq_checks
                                       │  sql/03_marts.sql
                                       ▼
              mart_monthly_rents, mart_period_rents, mart_postcode_change,
                       mart_rent_bands, mart_seasonality
                                       │  sql/analysis/*.sql
                                       ▼
                                results/*.csv
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

## Data marts

| Table | Grain | What it answers |
|---|---|---|
| `mart_monthly_rents` | month × dwelling type × size, with totals (`GROUPING SETS`) | Monthly median and 25th/75th percentile rents |
| `mart_period_rents` | rolling 12-month period × dwelling type × size | Rents per year, computed on leases (not averaged from months) |
| `mart_postcode_change` | postcode, for 2-bed flats and 3-bed houses | Latest 12 months against the 12 months before (30+ leases in each) |
| `mart_rent_bands` | period × weekly rent band | Share of new leases in each price range |
| `mart_seasonality` | calendar month | Share of the year's leases and rent against a 13-month moving average |

Rolling periods end at the latest month in the data, so new monthly files from NSW Fair Trading slot in without changing any SQL.

## Analysis queries

| Query | Question |
|---|---|
| `q1_rent_growth.sql` | How fast are rents rising, overall and by segment? |
| `q2_postcode_movers.sql` | Which postcodes moved the most in the last 12 months? |
| `q3_rent_bands.sql` | What share of new leases is under $500, or $1,000 and over? |
| `q4_seasonality.sql` | When do people sign new leases, and when are rents highest? |
| `q5_flats_vs_houses.sql` | Why does a 2-bed flat cost more than a 3-bed house across NSW? |

## Run it

```bash
pip install -r requirements.txt
python scripts/download_data.py          # 14 XLSX files listed in data/sources.csv (about 40 MB)
python scripts/load_raw.py               # about 1 minute
python scripts/run_sql.py --analysis     # builds all models and writes results/*.csv
```

## Project structure

```
data/sources.csv        official download links (one file per year or month)
scripts/                download, load and SQL runner
sql/01_staging.sql      typing, cleaning rules and the analysis view
sql/02_data_quality.sql data-quality log
sql/03_marts.sql        reporting tables
sql/analysis/           one query per business question
results/                query outputs (CSV)
```

## Roadmap

- [x] Ingestion of 14 source files into DuckDB
- [x] Staging model with documented cleaning rules and data-quality log
- [x] Rent marts: monthly medians by dwelling and size, rolling 12-month periods, postcode trends, rent bands, seasonality
- [x] Analysis queries and key findings
- [ ] Interactive dashboard published with GitHub Pages
- [ ] Automated tests for the SQL models

## Source and licence

Data: NSW Fair Trading, [Rental bond data](https://www.nsw.gov.au/housing-and-construction/rental-forms-surveys-and-data/rental-bond-data), Creative Commons Attribution. Bond lodgements cover new tenancies only, so they describe rents for new leases rather than all existing rents.
