-- q3_rent_bands.sql
-- How affordable are new leases? Share of new leases by weekly rent, per rolling 12-month period.
SELECT
    strftime(min(period_start), '%b %Y') || ' - ' || strftime(min(period_end), '%b %Y')  AS period,
    CAST(sum(bonds) AS BIGINT)                                                        AS bonds,
    round(100.0 * sum(bonds) FILTER (WHERE band_order <= 2) / sum(bonds), 1)          AS under_500_pct,
    round(100.0 * sum(bonds) FILTER (WHERE band_order BETWEEN 3 AND 5) / sum(bonds), 1) AS from_500_to_799_pct,
    round(100.0 * sum(bonds) FILTER (WHERE band_order = 6) / sum(bonds), 1)           AS from_800_to_999_pct,
    round(100.0 * sum(bonds) FILTER (WHERE band_order = 7) / sum(bonds), 1)           AS from_1000_pct
FROM mart_rent_bands
GROUP BY period_index
ORDER BY period_index DESC;
