-- 03_marts.sql
-- Reporting tables built on v_residential (one row per new residential lease).
--
-- Periods are rolling 12-month windows that end at the latest month in the data,
-- so the most recent period is always a full year and new monthly files slot in
-- without changing any SQL. With data from January 2022 to October 2026:
--   period 0 = Nov 2025 - Oct 2026, period 1 = Nov 2024 - Oct 2025, ...
--   period 4 = Jan 2022 - Oct 2022 (only 10 months, flagged by n_months)

-- Helper view: every lease tagged with its rolling period
CREATE OR REPLACE VIEW v_residential_periods AS
WITH bounds AS (
    SELECT min(lodgement_month) AS first_month, max(lodgement_month) AS last_month
    FROM v_residential
),
tagged AS (
    SELECT
        r.*,
        b.first_month,
        b.last_month,
        CAST(floor(datediff('month', r.lodgement_month, b.last_month) / 12) AS INTEGER) AS period_index
    FROM v_residential AS r
    CROSS JOIN bounds AS b
)
SELECT
    * EXCLUDE (first_month, last_month),
    -- the oldest window is cut at the first month of data
    CAST(greatest(last_month - to_months(12 * period_index + 11), first_month) AS DATE) AS period_start,
    CAST(last_month - to_months(12 * period_index) AS DATE)                            AS period_end
FROM tagged;


-- 1. Monthly rents by dwelling type and size, with NSW and dwelling-type totals
CREATE OR REPLACE TABLE mart_monthly_rents AS
SELECT
    lodgement_month                                                           AS month,
    CASE WHEN grouping(dwelling_type) = 1 THEN 'All dwellings' ELSE dwelling_type END AS dwelling_type,
    CASE WHEN grouping(bedroom_group) = 1 THEN 'All sizes' ELSE bedroom_group END     AS bedroom_group,
    count(*)                                                                  AS bonds,
    quantile_cont(weekly_rent, 0.25)                                          AS p25_rent,
    median(weekly_rent)                                                       AS median_rent,
    quantile_cont(weekly_rent, 0.75)                                          AS p75_rent
FROM v_residential
GROUP BY GROUPING SETS (
    (lodgement_month, dwelling_type, bedroom_group),
    (lodgement_month, dwelling_type),
    (lodgement_month)
)
ORDER BY month, dwelling_type, bedroom_group;


-- 2. Rents per rolling 12-month period (medians must be computed on leases, not averaged from months)
CREATE OR REPLACE TABLE mart_period_rents AS
SELECT
    period_index,
    min(period_start)                                                         AS period_start,
    min(period_end)                                                           AS period_end,
    datediff('month', min(period_start), min(period_end)) + 1                 AS n_months,
    CASE WHEN grouping(dwelling_type) = 1 THEN 'All dwellings' ELSE dwelling_type END AS dwelling_type,
    CASE WHEN grouping(bedroom_group) = 1 THEN 'All sizes' ELSE bedroom_group END     AS bedroom_group,
    count(*)                                                                  AS bonds,
    median(weekly_rent)                                                       AS median_rent
FROM v_residential_periods
GROUP BY GROUPING SETS (
    (period_index, dwelling_type, bedroom_group),
    (period_index, dwelling_type),
    (period_index)
)
ORDER BY period_index DESC, dwelling_type, bedroom_group;


-- 3. Postcode change for the two most common segments: latest 12 months vs the 12 months before.
--    Postcodes need at least 30 new leases in each window, so small samples do not dominate the ranking.
CREATE OR REPLACE TABLE mart_postcode_change AS
WITH by_postcode AS (
    SELECT
        dwelling_type,
        bedroom_group,
        postcode,
        count(*) FILTER (WHERE period_index = 1)                AS bonds_prev_12m,
        median(weekly_rent) FILTER (WHERE period_index = 1)     AS median_prev_12m,
        count(*) FILTER (WHERE period_index = 0)                AS bonds_last_12m,
        median(weekly_rent) FILTER (WHERE period_index = 0)     AS median_last_12m
    FROM v_residential_periods
    WHERE period_index IN (0, 1)
      AND ((dwelling_type = 'Flat/unit' AND bedroom_group = '2 bed')
        OR (dwelling_type = 'House'     AND bedroom_group = '3 bed'))
    GROUP BY dwelling_type, bedroom_group, postcode
)
SELECT
    *,
    median_last_12m - median_prev_12m                                       AS change_dollars,
    round(100.0 * (median_last_12m - median_prev_12m) / median_prev_12m, 1) AS change_pct
FROM by_postcode
WHERE bonds_prev_12m >= 30
  AND bonds_last_12m >= 30
ORDER BY dwelling_type, bedroom_group, change_pct DESC;


-- 4. Rent bands: what share of new leases falls in each weekly price range, per period
CREATE OR REPLACE TABLE mart_rent_bands AS
WITH banded AS (
    SELECT
        period_index,
        period_start,
        period_end,
        CASE
            WHEN weekly_rent < 400  THEN 1
            WHEN weekly_rent < 500  THEN 2
            WHEN weekly_rent < 600  THEN 3
            WHEN weekly_rent < 700  THEN 4
            WHEN weekly_rent < 800  THEN 5
            WHEN weekly_rent < 1000 THEN 6
            ELSE 7
        END AS band_order
    FROM v_residential_periods
),
counts AS (
    SELECT
        period_index,
        min(period_start) AS period_start,
        min(period_end)   AS period_end,
        band_order,
        count(*)          AS bonds
    FROM banded
    GROUP BY period_index, band_order
)
SELECT
    period_index,
    period_start,
    period_end,
    band_order,
    CASE band_order
        WHEN 1 THEN 'Under $400'
        WHEN 2 THEN '$400-$499'
        WHEN 3 THEN '$500-$599'
        WHEN 4 THEN '$600-$699'
        WHEN 5 THEN '$700-$799'
        WHEN 6 THEN '$800-$999'
        ELSE '$1,000 and over'
    END                                                                       AS rent_band,
    bonds,
    round(100.0 * bonds / sum(bonds) OVER (PARTITION BY period_index), 1)     AS share_pct
FROM counts
ORDER BY period_index DESC, band_order;


-- 5. Seasonality: how lodgements and rents move across the calendar year.
--    Volume: each month's share of its calendar year's leases (complete years only).
--    Rent: each month's median against a centred 13-month moving average of monthly medians,
--    so the steady rise in rents does not show up as a fake "December peak".
CREATE OR REPLACE TABLE mart_seasonality AS
WITH monthly AS (
    SELECT
        lodgement_month,
        lodgement_year,
        count(*)            AS bonds,
        median(weekly_rent) AS median_rent
    FROM v_residential
    GROUP BY lodgement_month, lodgement_year
),
full_years AS (
    SELECT lodgement_year, sum(bonds) AS bonds_year
    FROM monthly
    GROUP BY lodgement_year
    HAVING count(*) = 12
),
trend AS (
    SELECT
        *,
        avg(median_rent) OVER w13 AS centred_ma_13m,
        count(*)         OVER w13 AS window_months
    FROM monthly
    WINDOW w13 AS (ORDER BY lodgement_month ROWS BETWEEN 6 PRECEDING AND 6 FOLLOWING)
),
volume AS (
    SELECT
        month(m.lodgement_month)              AS month_number,
        count(*)                              AS n_years_volume,
        avg(100.0 * m.bonds / f.bonds_year)   AS share_of_year_bonds_pct
    FROM monthly AS m
    JOIN full_years AS f USING (lodgement_year)
    GROUP BY month(m.lodgement_month)
),
rent AS (
    SELECT
        month(lodgement_month)                              AS month_number,
        count(*)                                            AS n_years_rent,
        avg(100.0 * (median_rent / centred_ma_13m - 1))     AS rent_vs_trend_pct
    FROM trend
    WHERE window_months = 13
    GROUP BY month(lodgement_month)
)
SELECT
    v.month_number,
    monthname(make_date(2000, v.month_number, 1))   AS month_name,
    v.n_years_volume,
    round(v.share_of_year_bonds_pct, 2)             AS avg_share_of_year_bonds_pct,
    r.n_years_rent,
    round(r.rent_vs_trend_pct, 1)                   AS avg_rent_vs_trend_pct
FROM volume AS v
JOIN rent AS r USING (month_number)
ORDER BY v.month_number;
