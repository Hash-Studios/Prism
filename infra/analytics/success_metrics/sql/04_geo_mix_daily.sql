CREATE OR REPLACE TABLE `YOUR_GCP_PROJECT.prism_dash.geo_mix_daily`
PARTITION BY event_day AS
WITH daily_users AS (
  SELECT DISTINCT event_day, user_key, country, is_western_country
  FROM `YOUR_GCP_PROJECT.prism_dash.ga4_events`
  WHERE user_key IS NOT NULL
),
first_seen AS (
  SELECT user_key, MIN(event_day) AS first_seen_day
  FROM daily_users
  GROUP BY user_key
)
SELECT
  d.event_day,
  COUNT(DISTINCT d.user_key) AS active_users_total,
  COUNT(DISTINCT IF(d.is_western_country = 1, d.user_key, NULL)) AS active_users_western,
  SAFE_DIVIDE(
    COUNT(DISTINCT IF(d.is_western_country = 1, d.user_key, NULL)),
    COUNT(DISTINCT d.user_key)
  ) * 100 AS western_user_pct,
  COUNT(DISTINCT IF(f.first_seen_day = d.event_day, d.user_key, NULL)) AS new_users,
  COUNT(DISTINCT IF(f.first_seen_day < d.event_day, d.user_key, NULL)) AS returning_users
FROM daily_users d
LEFT JOIN first_seen f USING (user_key)
GROUP BY d.event_day;
