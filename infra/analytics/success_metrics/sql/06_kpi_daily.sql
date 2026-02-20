CREATE OR REPLACE TABLE `YOUR_GCP_PROJECT.prism_dash.kpi_daily`
PARTITION BY metric_date AS
WITH bounds AS (
  SELECT COALESCE(MIN(event_day), DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)) AS min_day
  FROM `YOUR_GCP_PROJECT.prism_dash.ga4_events`
),
days AS (
  SELECT day AS metric_date
  FROM bounds, UNNEST(GENERATE_DATE_ARRAY(min_day, CURRENT_DATE())) AS day
),
daily_users AS (
  SELECT DISTINCT event_day, user_key
  FROM `YOUR_GCP_PROJECT.prism_dash.ga4_events`
  WHERE user_key IS NOT NULL
),
dau AS (
  SELECT event_day AS metric_date, COUNT(DISTINCT user_key) AS dau
  FROM daily_users
  GROUP BY event_day
),
mau AS (
  SELECT
    d.metric_date,
    COUNT(DISTINCT u.user_key) AS mau
  FROM days d
  LEFT JOIN daily_users u
    ON u.event_day BETWEEN DATE_SUB(d.metric_date, INTERVAL 27 DAY) AND d.metric_date
  GROUP BY d.metric_date
),
first_seen AS (
  SELECT user_key, MIN(event_day) AS cohort_day
  FROM daily_users
  GROUP BY user_key
),
cohort_sizes AS (
  SELECT cohort_day, COUNT(*) AS cohort_size
  FROM first_seen
  GROUP BY cohort_day
),
retained_day_1 AS (
  SELECT f.cohort_day, COUNT(DISTINCT u.user_key) AS retained_day_1
  FROM first_seen f
  JOIN daily_users u
    ON u.user_key = f.user_key
   AND u.event_day = DATE_ADD(f.cohort_day, INTERVAL 1 DAY)
  GROUP BY f.cohort_day
),
retained_day_7 AS (
  SELECT f.cohort_day, COUNT(DISTINCT u.user_key) AS retained_day_7
  FROM first_seen f
  JOIN daily_users u
    ON u.user_key = f.user_key
   AND u.event_day = DATE_ADD(f.cohort_day, INTERVAL 7 DAY)
  GROUP BY f.cohort_day
),
cohort_retention AS (
  SELECT
    c.cohort_day,
    SAFE_DIVIDE(COALESCE(r1.retained_day_1, 0), c.cohort_size) * 100 AS day_1_retention_pct,
    SAFE_DIVIDE(COALESCE(r7.retained_day_7, 0), c.cohort_size) * 100 AS day_7_retention_pct
  FROM cohort_sizes c
  LEFT JOIN retained_day_1 r1 USING (cohort_day)
  LEFT JOIN retained_day_7 r7 USING (cohort_day)
),
retention_rollup AS (
  SELECT
    d.metric_date,
    (
      SELECT AVG(r.day_1_retention_pct)
      FROM cohort_retention r
      WHERE r.cohort_day BETWEEN DATE_SUB(d.metric_date, INTERVAL 30 DAY) AND DATE_SUB(d.metric_date, INTERVAL 1 DAY)
    ) AS day_1_retention_pct,
    (
      SELECT AVG(r.day_7_retention_pct)
      FROM cohort_retention r
      WHERE r.cohort_day BETWEEN DATE_SUB(d.metric_date, INTERVAL 30 DAY) AND DATE_SUB(d.metric_date, INTERVAL 7 DAY)
    ) AS day_7_retention_pct
  FROM days d
),
conversion_events AS (
  SELECT DISTINCT event_day, user_key
  FROM `YOUR_GCP_PROJECT.prism_dash.ga4_events`
  WHERE user_key IS NOT NULL
    AND (
      event_name = 'subscription_conversion'
      OR (event_name = 'subscription_purchase_result' AND result = 'success')
      OR (event_name = 'subscription_restore_result' AND result = 'success')
    )
),
conversion_28d AS (
  SELECT
    d.metric_date,
    COUNT(DISTINCT c.user_key) AS conversion_users_28d
  FROM days d
  LEFT JOIN conversion_events c
    ON c.event_day BETWEEN DATE_SUB(d.metric_date, INTERVAL 27 DAY) AND d.metric_date
  GROUP BY d.metric_date
),
ai_coins AS (
  SELECT
    event_day AS metric_date,
    ai_generations_success AS ai_generations_per_day,
    ad_watches_per_free_user_per_day
  FROM `YOUR_GCP_PROJECT.prism_dash.ai_coins_daily`
),
geo AS (
  SELECT event_day AS metric_date, western_user_pct
  FROM `YOUR_GCP_PROJECT.prism_dash.geo_mix_daily`
),
revenue_30d AS (
  SELECT
    d.metric_date,
    SUM(COALESCE(r.revenuecat_net_usd, 0)) AS revenuecat_30d_usd,
    SUM(COALESCE(r.admob_estimated_usd, 0)) AS admob_30d_usd,
    SUM(COALESCE(r.play_non_rc_usd, 0)) AS play_non_rc_30d_usd,
    SUM(COALESCE(r.total_revenue_usd, 0)) AS monthly_revenue_usd
  FROM days d
  LEFT JOIN `YOUR_GCP_PROJECT.prism_dash.revenue_blend_daily` r
    ON r.event_day BETWEEN DATE_SUB(d.metric_date, INTERVAL 29 DAY) AND d.metric_date
  GROUP BY d.metric_date
),
quality AS (
  SELECT
    event_day AS metric_date,
    crash_free_users_pct,
    fatal_crash_count
  FROM `YOUR_GCP_PROJECT.prism_dash.quality_daily`
),
freshness AS (
  SELECT
    (SELECT MAX(event_day) FROM `YOUR_GCP_PROJECT.prism_dash.ga4_events`) AS ga4_latest_day,
    (SELECT MAX(event_day) FROM `YOUR_GCP_PROJECT.prism_raw.revenuecat_daily`) AS revenuecat_latest_day,
    (SELECT MAX(event_day) FROM `YOUR_GCP_PROJECT.prism_raw.admob_daily`) AS admob_latest_day,
    (SELECT MAX(event_day) FROM `YOUR_GCP_PROJECT.prism_raw.play_non_rc_daily`) AS play_latest_day,
    (SELECT MAX(event_day) FROM `YOUR_GCP_PROJECT.prism_dash.quality_daily`) AS crashlytics_latest_day
)
SELECT
  d.metric_date,
  dau.dau,
  mau.mau,
  rr.day_1_retention_pct,
  rr.day_7_retention_pct,
  SAFE_DIVIDE(dau.dau, NULLIF(mau.mau, 0)) * 100 AS dau_mau_pct,
  SAFE_DIVIDE(c28.conversion_users_28d, NULLIF(mau.mau, 0)) * 100 AS pro_conversion_pct,
  ai.ad_watches_per_free_user_per_day,
  ai.ai_generations_per_day,
  geo.western_user_pct,
  rev.monthly_revenue_usd,
  SAFE_DIVIDE(rev.monthly_revenue_usd, NULLIF(mau.mau, 0)) AS arpu_usd,
  quality.crash_free_users_pct,
  quality.fatal_crash_count,
  rev.revenuecat_30d_usd,
  rev.admob_30d_usd,
  rev.play_non_rc_30d_usd,
  f.ga4_latest_day,
  LEAST(f.revenuecat_latest_day, f.admob_latest_day, f.play_latest_day) AS revenue_latest_day,
  f.crashlytics_latest_day,
  IFNULL(DATE_DIFF(CURRENT_DATE(), f.ga4_latest_day, DAY) > 2, TRUE) AS ga4_data_stale,
  (
    CASE
      WHEN f.revenuecat_latest_day IS NULL OR f.admob_latest_day IS NULL OR f.play_latest_day IS NULL THEN TRUE
      ELSE DATE_DIFF(CURRENT_DATE(), LEAST(f.revenuecat_latest_day, f.admob_latest_day, f.play_latest_day), DAY) > 2
    END
  ) AS revenue_data_stale,
  IFNULL(DATE_DIFF(CURRENT_DATE(), f.crashlytics_latest_day, DAY) > 2, TRUE) AS crashlytics_data_stale
FROM days d
LEFT JOIN dau USING (metric_date)
LEFT JOIN mau USING (metric_date)
LEFT JOIN retention_rollup rr USING (metric_date)
LEFT JOIN conversion_28d c28 USING (metric_date)
LEFT JOIN ai_coins ai USING (metric_date)
LEFT JOIN geo USING (metric_date)
LEFT JOIN revenue_30d rev USING (metric_date)
LEFT JOIN quality USING (metric_date)
CROSS JOIN freshness f;
