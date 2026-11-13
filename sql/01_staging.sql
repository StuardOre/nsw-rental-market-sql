-- 01_staging.sql
-- Type and clean the raw bond lodgements (one row per new bond lodged).
-- Source: NSW Fair Trading rental bond lodgement data (data/sources.csv).
--
-- Cleaning rules (each one is flagged, nothing is silently dropped):
--   * dates, postcodes, bedrooms and rent are cast with TRY_CAST, so bad values become NULL
--   * 'U' means unknown for dwelling type, bedrooms and rent
--   * a handful of rows have dwelling type and bedrooms swapped (e.g. dwelling '3', bedrooms 'H');
--     these are detected and switched back
--   * rents outside $50-$5,000 a week are kept but flagged as outliers
--     (they include garages, car spaces, data-entry errors and luxury homes)

CREATE OR REPLACE TABLE stg_lodgements AS
WITH typed AS (
    SELECT
        TRY_CAST(lodgement_date AS DATE)      AS lodgement_date,
        TRY_CAST(postcode AS INTEGER)         AS postcode,
        UPPER(TRIM(dwelling_type))            AS dwelling_raw,
        UPPER(TRIM(bedrooms))                 AS bedrooms_raw,
        TRY_CAST(weekly_rent AS DOUBLE)       AS weekly_rent,
        source_file
    FROM raw_lodgements
),
fixed AS (
    SELECT
        *,
        -- swapped columns: a valid dwelling code sits in the bedrooms column and a number in the dwelling column
        (bedrooms_raw IN ('F', 'H', 'T', 'O', 'U')
            AND TRY_CAST(dwelling_raw AS INTEGER) IS NOT NULL) AS cols_swapped
    FROM typed
),
resolved AS (
    SELECT
        lodgement_date,
        postcode,
        CASE WHEN cols_swapped THEN bedrooms_raw ELSE dwelling_raw END AS dwelling_code,
        TRY_CAST(CASE WHEN cols_swapped THEN dwelling_raw ELSE bedrooms_raw END AS INTEGER) AS bedrooms,
        weekly_rent,
        cols_swapped,
        source_file
    FROM fixed
)
SELECT
    lodgement_date,
    CAST(date_trunc('month', lodgement_date) AS DATE)       AS lodgement_month,
    year(lodgement_date)                                     AS lodgement_year,
    postcode,
    CASE dwelling_code
        WHEN 'F' THEN 'Flat/unit'
        WHEN 'H' THEN 'House'
        WHEN 'T' THEN 'Terrace/townhouse'
        WHEN 'O' THEN 'Other'
        WHEN 'U' THEN 'Unknown'
        ELSE 'Invalid code'
    END                                                      AS dwelling_type,
    bedrooms,
    CASE
        WHEN bedrooms IS NULL THEN 'Unknown'
        WHEN bedrooms <= 1 THEN '0-1 bed'
        WHEN bedrooms = 2 THEN '2 bed'
        WHEN bedrooms = 3 THEN '3 bed'
        ELSE '4+ bed'
    END                                                      AS bedroom_group,
    weekly_rent,
    weekly_rent IS NOT NULL AND (weekly_rent < 50 OR weekly_rent > 5000) AS rent_outlier,
    cols_swapped,
    source_file
FROM resolved;

-- Analysis-ready view: residential homes with a known size and a plausible rent.
-- 'Other' (rooms, garages, car spaces) and unknown dwelling types are excluded.
CREATE OR REPLACE VIEW v_residential AS
SELECT *
FROM stg_lodgements
WHERE lodgement_date IS NOT NULL
  AND dwelling_type IN ('Flat/unit', 'House', 'Terrace/townhouse')
  AND bedrooms IS NOT NULL
  AND weekly_rent IS NOT NULL
  AND NOT rent_outlier;
