-- Validation pack for Prism success-metrics dashboard.
-- Run each block independently in BigQuery after materializing curated tables.

-- 1) Formula correctness: KPI recomputation tolerance <= 1%.
WITH recomputed AS (
  SELECT
    k.metric_date,
    SAFE_DIVIDE(conv.conversion_users_28d, NULLIF(k.mau, 0)) * 100 AS recomputed_pro_conversion_pct,
    k.pro_conversion_pct AS reported_pro_conversion_pct,
    SAFE_DIVIDE(ABS((SAFE_DIVIDE(conv.conversion_users_28d, NULLIF(k.mau, 0)) * 100) - k.pro_conversion_pct), NULLIF(k.pro_conversion_pct, 0))
      AS relative_error
  FROM `YOUR_GCP_PROJECT.prism_dash.kpi_daily` k
  LEFT JOIN (
    SELECT
      d.metric_date,
      COUNT(DISTINCT e.user_key) AS conversion_users_28d
    FROM (SELECT DISTINCT metric_date FROM `YOUR_GCP_PROJECT.prism_dash.kpi_daily`) d
    LEFT JOIN `YOUR_GCP_PROJECT.prism_dash.ga4_events` e
      ON e.user_key IS NOT NULL
     AND e.event_day BETWEEN DATE_SUB(d.metric_date, INTERVAL 27 DAY) AND d.metric_date
     AND (
      e.event_name = 'subscription_conversion'
      OR (e.event_name = 'subscription_purchase_result' AND e.result = 'success')
      OR (e.event_name = 'subscription_restore_result' AND e.result = 'success')
     )
    GROUP BY d.metric_date
  ) conv USING (metric_date)
)
SELECT *
FROM recomputed
WHERE relative_error > 0.01
ORDER BY metric_date DESC;

-- 2) Threshold boundary tests.
WITH boundary AS (
  SELECT * FROM UNNEST([
    STRUCT('day_1_retention_pct' AS metric_key, 29.99 AS value, 'amber' AS expected_status),
    STRUCT('day_1_retention_pct', 30.00, 'green'),
    STRUCT('day_7_retention_pct', 11.99, 'amber'),
    STRUCT('day_7_retention_pct', 12.00, 'green'),
    STRUCT('dau_mau_pct', 14.99, 'amber'),
    STRUCT('dau_mau_pct', 15.00, 'green'),
    STRUCT('pro_conversion_pct', 1.99, 'amber'),
    STRUCT('pro_conversion_pct', 2.00, 'green'),
    STRUCT('ad_watches_per_free_user_per_day', 2.99, 'amber'),
    STRUCT('ad_watches_per_free_user_per_day', 3.00, 'green'),
    STRUCT('ai_generations_per_day', 999.0, 'amber'),
    STRUCT('ai_generations_per_day', 1000.0, 'green')
  ])
),
evaluated AS (
  SELECT
    b.*,
    CASE
      WHEN b.metric_key = 'day_1_retention_pct' THEN CASE WHEN b.value >= 30 THEN 'green' WHEN b.value >= 25 THEN 'amber' ELSE 'red' END
      WHEN b.metric_key = 'day_7_retention_pct' THEN CASE WHEN b.value >= 12 THEN 'green' WHEN b.value >= 10 THEN 'amber' ELSE 'red' END
      WHEN b.metric_key = 'dau_mau_pct' THEN CASE WHEN b.value >= 15 THEN 'green' WHEN b.value >= 12 THEN 'amber' ELSE 'red' END
      WHEN b.metric_key = 'pro_conversion_pct' THEN CASE WHEN b.value >= 2 THEN 'green' WHEN b.value >= 1.5 THEN 'amber' ELSE 'red' END
      WHEN b.metric_key = 'ad_watches_per_free_user_per_day' THEN CASE WHEN b.value >= 3 THEN 'green' WHEN b.value >= 2 THEN 'amber' ELSE 'red' END
      WHEN b.metric_key = 'ai_generations_per_day' THEN CASE WHEN b.value >= 1000 THEN 'green' WHEN b.value >= 700 THEN 'amber' ELSE 'red' END
      ELSE 'red'
    END AS actual_status
  FROM boundary b
)
SELECT *
FROM evaluated
WHERE actual_status != expected_status;

-- 3) RAG table integrity: each KPI appears exactly once per day.
SELECT
  metric_date,
  metric_key,
  COUNT(*) AS row_count
FROM `YOUR_GCP_PROJECT.prism_dash.kpi_status_daily`
GROUP BY metric_date, metric_key
HAVING COUNT(*) != 1
ORDER BY metric_date DESC, metric_key;

-- 4) Source reconciliation: monthly revenue blend check.
SELECT
  k.metric_date,
  k.monthly_revenue_usd AS dashboard_monthly_revenue,
  (k.revenuecat_30d_usd + k.admob_30d_usd + k.play_non_rc_30d_usd) AS recomputed_monthly_revenue,
  ABS(k.monthly_revenue_usd - (k.revenuecat_30d_usd + k.admob_30d_usd + k.play_non_rc_30d_usd)) AS absolute_diff
FROM `YOUR_GCP_PROJECT.prism_dash.kpi_daily` k
WHERE ABS(k.monthly_revenue_usd - (k.revenuecat_30d_usd + k.admob_30d_usd + k.play_non_rc_30d_usd)) > 0.01
ORDER BY k.metric_date DESC;

-- 5) Segmentation validity: Western % explicit country-set check.
WITH explicit AS (
  SELECT
    event_day,
    SAFE_DIVIDE(
      COUNT(DISTINCT IF(is_western_country = 1, user_key, NULL)),
      COUNT(DISTINCT user_key)
    ) * 100 AS western_pct_explicit
  FROM `YOUR_GCP_PROJECT.prism_dash.ga4_events`
  WHERE user_key IS NOT NULL
  GROUP BY event_day
)
SELECT
  g.event_day,
  g.western_user_pct AS dashboard_western_pct,
  e.western_pct_explicit,
  ABS(g.western_user_pct - e.western_pct_explicit) AS pct_diff
FROM `YOUR_GCP_PROJECT.prism_dash.geo_mix_daily` g
JOIN explicit e ON e.event_day = g.event_day
WHERE ABS(g.western_user_pct - e.western_pct_explicit) > 0.01
ORDER BY g.event_day DESC;

-- 6) Crash metric validity against canonical quality table.
SELECT
  s.metric_date,
  MAX(IF(s.metric_key = 'crash_free_users_pct', s.current_value, NULL)) AS dashboard_crash_free_pct,
  MAX(IF(s.metric_key = 'fatal_crash_count', s.current_value, NULL)) AS dashboard_fatal_count,
  q.crash_free_users_pct AS quality_crash_free_pct,
  q.fatal_crash_count AS quality_fatal_count
FROM `YOUR_GCP_PROJECT.prism_dash.kpi_status_daily` s
LEFT JOIN `YOUR_GCP_PROJECT.prism_dash.quality_daily` q
  ON q.event_day = s.metric_date
WHERE s.metric_key IN ('crash_free_users_pct', 'fatal_crash_count')
GROUP BY s.metric_date, q.crash_free_users_pct, q.fatal_crash_count
HAVING ABS(COALESCE(MAX(IF(s.metric_key = 'crash_free_users_pct', s.current_value, NULL)), -1) - COALESCE(q.crash_free_users_pct, -1)) > 0.001
   OR ABS(COALESCE(MAX(IF(s.metric_key = 'fatal_crash_count', s.current_value, NULL)), -1) - COALESCE(CAST(q.fatal_crash_count AS FLOAT64), -1)) > 0.001
ORDER BY s.metric_date DESC;

-- 7) Freshness handling: any stale source should force Gray.
SELECT
  metric_date,
  metric_key,
  status,
  source_group,
  ga4_data_stale,
  revenue_data_stale,
  crashlytics_data_stale
FROM `YOUR_GCP_PROJECT.prism_dash.kpi_status_daily`
WHERE (
    (source_group = 'ga4' AND ga4_data_stale)
    OR (source_group = 'revenue' AND revenue_data_stale)
    OR (source_group = 'quality' AND crashlytics_data_stale)
  )
  AND status != 'gray'
ORDER BY metric_date DESC, metric_key;

-- 8) Performance check: should stay under 10s in Looker Studio default range.
-- This query estimates the row count scanned by dashboard's default (last 30 days) scorecards.
SELECT
  COUNT(*) AS rows_last_30d
FROM `YOUR_GCP_PROJECT.prism_dash.kpi_status_daily`
WHERE metric_date BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 29 DAY) AND CURRENT_DATE();
