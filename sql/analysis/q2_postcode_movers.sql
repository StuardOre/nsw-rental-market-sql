-- q2_postcode_movers.sql
-- Where did rents for new leases move the most in the last 12 months?
-- Top 10 rises and the 10 weakest changes per segment (postcodes with 30+ new leases in both windows).
-- Medians of small samples move more, so check bonds_* before reading too much into one postcode.
WITH ranked AS (
    SELECT
        *,
        row_number() OVER (PARTITION BY dwelling_type, bedroom_group ORDER BY change_pct DESC, postcode) AS rank_rise,
        row_number() OVER (PARTITION BY dwelling_type, bedroom_group ORDER BY change_pct ASC,  postcode) AS rank_fall
    FROM mart_postcode_change
)
SELECT
    dwelling_type,
    bedroom_group,
    CASE WHEN rank_rise <= 10 THEN 'Largest rise' ELSE 'Weakest change' END AS direction,
    CASE WHEN rank_rise <= 10 THEN rank_rise ELSE rank_fall END           AS rank,
    postcode,
    bonds_prev_12m,
    median_prev_12m,
    bonds_last_12m,
    median_last_12m,
    change_dollars,
    change_pct
FROM ranked
WHERE rank_rise <= 10 OR rank_fall <= 10
ORDER BY dwelling_type, bedroom_group, direction, rank;
