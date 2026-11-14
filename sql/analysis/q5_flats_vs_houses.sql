-- q5_flats_vs_houses.sql
-- Across NSW, a 2-bed flat now rents for more than a 3-bed house. Is that true postcode by postcode?
-- Compares the two segments inside each postcode (latest 12 months, 30+ leases of each type).
WITH latest AS (
    SELECT *
    FROM v_residential_periods
    WHERE period_index = 0
      AND ((dwelling_type = 'Flat/unit' AND bedroom_group = '2 bed')
        OR (dwelling_type = 'House'     AND bedroom_group = '3 bed'))
),
by_postcode AS (
    SELECT
        postcode,
        count(*) FILTER (WHERE dwelling_type = 'Flat/unit')                AS flat_bonds,
        median(weekly_rent) FILTER (WHERE dwelling_type = 'Flat/unit')     AS flat_median,
        count(*) FILTER (WHERE dwelling_type = 'House')                    AS house_bonds,
        median(weekly_rent) FILTER (WHERE dwelling_type = 'House')         AS house_median
    FROM latest
    GROUP BY postcode
),
compared AS (
    SELECT * FROM by_postcode WHERE flat_bonds >= 30 AND house_bonds >= 30
)
SELECT 1 AS metric_order, 'NSW median weekly rent, 2-bed flat' AS metric,
       (SELECT median(weekly_rent) FROM latest WHERE dwelling_type = 'Flat/unit') AS value
UNION ALL
SELECT 2, 'NSW median weekly rent, 3-bed house',
       (SELECT median(weekly_rent) FROM latest WHERE dwelling_type = 'House')
UNION ALL
SELECT 3, 'Postcodes compared (30+ leases of each type)', (SELECT count(*) FROM compared)
UNION ALL
SELECT 4, 'Postcodes where the 3-bed house rents for more', (SELECT count(*) FROM compared WHERE house_median > flat_median)
UNION ALL
SELECT 5, 'Share of 2-bed flat leases in postcodes 2000-2249 (%)',
       (SELECT round(100.0 * avg(CASE WHEN postcode BETWEEN 2000 AND 2249 THEN 1 ELSE 0 END), 1)
        FROM latest WHERE dwelling_type = 'Flat/unit')
UNION ALL
SELECT 6, 'Share of 3-bed house leases in postcodes 2000-2249 (%)',
       (SELECT round(100.0 * avg(CASE WHEN postcode BETWEEN 2000 AND 2249 THEN 1 ELSE 0 END), 1)
        FROM latest WHERE dwelling_type = 'House')
ORDER BY metric_order;
