-- q4_seasonality.sql
-- When do people sign new leases, and do rents follow the same calendar?
SELECT
    month_name,
    avg_share_of_year_bonds_pct,
    avg_rent_vs_trend_pct,
    rank() OVER (ORDER BY avg_share_of_year_bonds_pct DESC) AS busiest_rank,
    rank() OVER (ORDER BY avg_rent_vs_trend_pct DESC)       AS priciest_rank
FROM mart_seasonality
ORDER BY month_number;
