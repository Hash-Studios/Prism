CREATE OR REPLACE TABLE `YOUR_GCP_PROJECT.prism_dash.quality_daily`
PARTITION BY event_day AS
SELECT
  event_day,
  crash_free_users_pct,
  fatal_crash_count
FROM `YOUR_GCP_PROJECT.prism_dash.quality_daily_raw`;
