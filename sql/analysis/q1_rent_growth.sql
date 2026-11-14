-- q1_rent_growth.sql
-- How fast are rents for new leases rising? Median weekly rent per rolling 12-month period,
-- for NSW overall and the main dwelling segments.
WITH segments AS (
    SELECT * FROM (VALUES
        (1, 'All dwellings',     'All sizes'),
        (2, 'Flat/unit',         'All sizes'),
        (3, 'Flat/unit',         '0-1 bed'),
        (4, 'Flat/unit',         '2 bed'),
        (5, 'House',             'All sizes'),
        (6, 'House',             '3 bed'),
        (7, 'House',             '4+ bed')
    ) AS s(segment_order, dwelling_type, bedroom_group)
),
periods AS (
    SELECT
        s.segment_order,
        p.dwelling_type,
        p.bedroom_group,
        p.period_index,
        strftime(p.period_start, '%b %Y') || ' - ' || strftime(p.period_end, '%b %Y') AS period,
        p.n_months,
        p.bonds,
        p.median_rent
    FROM mart_period_rents AS p
    JOIN segments AS s USING (dwelling_type, bedroom_group)
),
-- baseline: the oldest complete 12-month window (the very first window has only 10 months)
baseline AS (
    SELECT segment_order, median_rent AS base_median
    FROM periods
    WHERE n_months = 12
    QUALIFY row_number() OVER (PARTITION BY segment_order ORDER BY period_index DESC) = 1
)
SELECT
    p.dwelling_type,
    p.bedroom_group,
    p.period,
    p.n_months,
    p.bonds,
    p.median_rent,
    -- only compare full 12-month windows with each other
    CASE WHEN p.n_months = 12 AND lag(p.n_months) OVER seg = 12
         THEN round(100.0 * (p.median_rent / lag(p.median_rent) OVER seg - 1), 1) END
                                                                         AS change_vs_prev_period_pct,
    CASE WHEN p.n_months = 12
         THEN round(100.0 * (p.median_rent / b.base_median - 1), 1) END  AS change_since_first_full_year_pct
FROM periods AS p
JOIN baseline AS b USING (segment_order)
WINDOW seg AS (PARTITION BY p.segment_order ORDER BY p.period_index DESC)
ORDER BY p.segment_order, p.period_index DESC;
