CREATE OR REPLACE TABLE `YOUR_GCP_PROJECT.prism_dash.kpi_status_daily`
PARTITION BY metric_date AS
WITH launch_context AS (
  SELECT MIN(metric_date) AS launch_date
  FROM `YOUR_GCP_PROJECT.prism_dash.kpi_daily`
  WHERE dau IS NOT NULL
),
metrics AS (
  SELECT metric_date, 'dau' AS metric_key, CAST(dau AS FLOAT64) AS metric_value, 'ga4' AS source_group
  FROM `YOUR_GCP_PROJECT.prism_dash.kpi_daily`
  UNION ALL
  SELECT metric_date, 'mau', CAST(mau AS FLOAT64), 'ga4'
  FROM `YOUR_GCP_PROJECT.prism_dash.kpi_daily`
  UNION ALL
  SELECT metric_date, 'day_1_retention_pct', day_1_retention_pct, 'ga4'
  FROM `YOUR_GCP_PROJECT.prism_dash.kpi_daily`
  UNION ALL
  SELECT metric_date, 'day_7_retention_pct', day_7_retention_pct, 'ga4'
  FROM `YOUR_GCP_PROJECT.prism_dash.kpi_daily`
  UNION ALL
  SELECT metric_date, 'dau_mau_pct', dau_mau_pct, 'ga4'
  FROM `YOUR_GCP_PROJECT.prism_dash.kpi_daily`
  UNION ALL
  SELECT metric_date, 'pro_conversion_pct', pro_conversion_pct, 'ga4'
  FROM `YOUR_GCP_PROJECT.prism_dash.kpi_daily`
  UNION ALL
  SELECT metric_date, 'ad_watches_per_free_user_per_day', ad_watches_per_free_user_per_day, 'ga4'
  FROM `YOUR_GCP_PROJECT.prism_dash.kpi_daily`
  UNION ALL
  SELECT metric_date, 'ai_generations_per_day', CAST(ai_generations_per_day AS FLOAT64), 'ga4'
  FROM `YOUR_GCP_PROJECT.prism_dash.kpi_daily`
  UNION ALL
  SELECT metric_date, 'western_user_pct', western_user_pct, 'ga4'
  FROM `YOUR_GCP_PROJECT.prism_dash.kpi_daily`
  UNION ALL
  SELECT metric_date, 'monthly_revenue_usd', monthly_revenue_usd, 'revenue'
  FROM `YOUR_GCP_PROJECT.prism_dash.kpi_daily`
  UNION ALL
  SELECT metric_date, 'arpu_usd', arpu_usd, 'revenue'
  FROM `YOUR_GCP_PROJECT.prism_dash.kpi_daily`
  UNION ALL
  SELECT metric_date, 'crash_free_users_pct', crash_free_users_pct, 'quality'
  FROM `YOUR_GCP_PROJECT.prism_dash.kpi_daily`
  UNION ALL
  SELECT metric_date, 'fatal_crash_count', CAST(fatal_crash_count AS FLOAT64), 'quality'
  FROM `YOUR_GCP_PROJECT.prism_dash.kpi_daily`
),
joined AS (
  SELECT
    m.metric_date,
    m.metric_key,
    m.metric_value,
    m.source_group,
    t.metric_label,
    t.unit,
    t.launch_direction,
    t.launch_green_threshold,
    t.launch_amber_threshold,
    t.month_6_target,
    t.month_12_target,
    t.recommended_action,
    t.display_order,
    k.fatal_crash_count,
    k.ga4_data_stale,
    k.revenue_data_stale,
    k.crashlytics_data_stale,
    lc.launch_date,
    DATE_DIFF(m.metric_date, lc.launch_date, DAY) AS days_since_launch
  FROM metrics m
  LEFT JOIN `YOUR_GCP_PROJECT.prism_dash.kpi_targets` t
    ON t.metric_key = m.metric_key
  LEFT JOIN `YOUR_GCP_PROJECT.prism_dash.kpi_daily` k
    ON k.metric_date = m.metric_date
  CROSS JOIN launch_context lc
),
scored AS (
  SELECT
    j.*,
    CASE
      WHEN j.source_group = 'ga4' THEN j.ga4_data_stale
      WHEN j.source_group = 'revenue' THEN j.revenue_data_stale
      WHEN j.source_group = 'quality' THEN j.crashlytics_data_stale
      ELSE TRUE
    END AS source_data_stale,
    CASE
      WHEN j.launch_date IS NULL THEN NULL
      WHEN j.month_6_target IS NULL AND j.month_12_target IS NULL THEN NULL
      WHEN j.days_since_launch < 0 THEN NULL
      WHEN j.days_since_launch < 180 THEN
        CASE
          WHEN j.month_6_target IS NULL THEN NULL
          ELSE j.month_6_target * SAFE_DIVIDE(j.days_since_launch, 180)
        END
      WHEN j.days_since_launch < 365 THEN
        CASE
          WHEN j.month_12_target IS NULL THEN j.month_6_target
          WHEN j.month_6_target IS NULL THEN j.month_12_target
          ELSE j.month_6_target + (j.month_12_target - j.month_6_target) * SAFE_DIVIDE(j.days_since_launch - 180, 185)
        END
      ELSE COALESCE(j.month_12_target, j.month_6_target)
    END AS trajectory_target
  FROM joined j
),
status_eval AS (
  SELECT
    s.*,
    CASE
      WHEN s.source_data_stale THEN 'gray'
      WHEN s.metric_value IS NULL THEN 'gray'
      WHEN s.metric_key = 'crash_free_users_pct' THEN
        CASE
          WHEN s.metric_value >= 99.5 AND COALESCE(s.fatal_crash_count, 0) = 0 THEN 'green'
          WHEN (s.metric_value >= 99.0 AND s.metric_value < 99.5) OR COALESCE(s.fatal_crash_count, 0) = 1 THEN 'amber'
          ELSE 'red'
        END
      WHEN s.launch_direction = 'higher_is_better' THEN
        CASE
          WHEN s.metric_value >= s.launch_green_threshold THEN 'green'
          WHEN s.metric_value >= s.launch_amber_threshold THEN 'amber'
          ELSE 'red'
        END
      WHEN s.launch_direction = 'lower_is_better' THEN
        CASE
          WHEN s.metric_value <= s.launch_green_threshold THEN 'green'
          WHEN s.metric_value <= s.launch_amber_threshold THEN 'amber'
          ELSE 'red'
        END
      WHEN s.trajectory_target IS NOT NULL THEN
        CASE
          WHEN s.metric_value >= s.trajectory_target THEN 'green'
          WHEN s.metric_value >= (s.trajectory_target * 0.85) THEN 'amber'
          ELSE 'red'
        END
      ELSE 'gray'
    END AS status,
    CASE
      WHEN s.source_data_stale THEN 'Data stale (>48h)'
      WHEN s.metric_value IS NULL THEN 'No data'
      WHEN s.metric_key = 'crash_free_users_pct' THEN 'Launch threshold + fatal issue override'
      WHEN s.launch_direction IN ('higher_is_better', 'lower_is_better') THEN 'Launch threshold'
      WHEN s.trajectory_target IS NOT NULL THEN 'Trajectory target'
      ELSE 'No threshold configured'
    END AS status_reason
  FROM scored s
)
SELECT
  metric_date,
  metric_key,
  metric_label,
  unit,
  metric_value AS current_value,
  launch_green_threshold AS launch_target,
  trajectory_target,
  status,
  status_reason,
  CASE
    WHEN status IN ('green', 'gray') THEN 0
    WHEN metric_key = 'crash_free_users_pct' THEN
      GREATEST(99.5 - COALESCE(metric_value, 0), 0) + GREATEST(CAST(COALESCE(fatal_crash_count, 0) AS FLOAT64), 0)
    WHEN launch_direction = 'lower_is_better' AND launch_green_threshold IS NOT NULL THEN
      GREATEST(COALESCE(metric_value, 0) - launch_green_threshold, 0)
    WHEN launch_green_threshold IS NOT NULL THEN
      GREATEST(launch_green_threshold - COALESCE(metric_value, 0), 0)
    WHEN trajectory_target IS NOT NULL THEN
      GREATEST(trajectory_target - COALESCE(metric_value, 0), 0)
    ELSE 0
  END AS gap_to_target,
  recommended_action,
  source_group,
  source_data_stale,
  ga4_data_stale,
  revenue_data_stale,
  crashlytics_data_stale,
  display_order
FROM status_eval;

CREATE OR REPLACE VIEW `YOUR_GCP_PROJECT.prism_dash.not_green_metrics_daily` AS
SELECT
  metric_date,
  metric_key,
  metric_label,
  current_value,
  launch_target,
  trajectory_target,
  status,
  gap_to_target,
  status_reason,
  recommended_action,
  source_group
FROM `YOUR_GCP_PROJECT.prism_dash.kpi_status_daily`
WHERE status IN ('red', 'amber')
ORDER BY
  metric_date DESC,
  CASE status WHEN 'red' THEN 0 WHEN 'amber' THEN 1 ELSE 2 END,
  gap_to_target DESC,
  display_order;
