-- Prism success-metrics dashboard staging layer.
--
-- Run this file first. Replace `YOUR_GCP_PROJECT` and the GA4 export dataset
-- (`analytics_123456789`) with your actual identifiers before execution.
--
-- Expected canonical source tables (daily grain):
--   `YOUR_GCP_PROJECT.prism_raw.revenuecat_daily`
--     - event_day DATE
--     - net_revenue_usd FLOAT64
--   `YOUR_GCP_PROJECT.prism_raw.admob_daily`
--     - event_day DATE
--     - estimated_revenue_usd FLOAT64
--   `YOUR_GCP_PROJECT.prism_raw.play_non_rc_daily`
--     - event_day DATE
--     - non_rc_revenue_usd FLOAT64
--   `YOUR_GCP_PROJECT.prism_raw.crashlytics_daily`
--     - event_day DATE
--     - crash_free_users_pct FLOAT64
--     - fatal_issue_count INT64

CREATE SCHEMA IF NOT EXISTS `YOUR_GCP_PROJECT.prism_dash`;

CREATE OR REPLACE VIEW `YOUR_GCP_PROJECT.prism_dash.ga4_events` AS
SELECT
  PARSE_DATE('%Y%m%d', event_date) AS event_day,
  TIMESTAMP_MICROS(event_timestamp) AS event_ts,
  event_name,
  user_pseudo_id,
  NULLIF(TRIM(user_id), '') AS user_id,
  COALESCE(NULLIF(TRIM(user_id), ''), user_pseudo_id) AS user_key,
  geo.country AS country,
  IF(
    geo.country IN (
      'United States',
      'United Kingdom',
      'Canada',
      'Australia',
      'New Zealand',
      'Austria',
      'Belgium',
      'Bulgaria',
      'Croatia',
      'Cyprus',
      'Czechia',
      'Denmark',
      'Estonia',
      'Finland',
      'France',
      'Germany',
      'Greece',
      'Hungary',
      'Ireland',
      'Italy',
      'Latvia',
      'Lithuania',
      'Luxembourg',
      'Malta',
      'Netherlands',
      'Poland',
      'Portugal',
      'Romania',
      'Slovakia',
      'Slovenia',
      'Spain',
      'Sweden'
    ),
    1,
    0
  ) AS is_western_country,
  (SELECT ep.value.string_value FROM UNNEST(event_params) ep WHERE ep.key = 'source') AS source,
  (SELECT ep.value.string_value FROM UNNEST(event_params) ep WHERE ep.key = 'source_context') AS source_context,
  (SELECT ep.value.string_value FROM UNNEST(event_params) ep WHERE ep.key = 'placement') AS placement,
  (SELECT ep.value.string_value FROM UNNEST(event_params) ep WHERE ep.key = 'result') AS result,
  (SELECT ep.value.string_value FROM UNNEST(event_params) ep WHERE ep.key = 'rc_or_fallback') AS rc_or_fallback,
  (SELECT ep.value.string_value FROM UNNEST(event_params) ep WHERE ep.key = 'action') AS action,
  (SELECT ep.value.string_value FROM UNNEST(event_params) ep WHERE ep.key = 'mode') AS mode,
  (SELECT ep.value.string_value FROM UNNEST(event_params) ep WHERE ep.key = 'package_type') AS package_type,
  (SELECT ep.value.string_value FROM UNNEST(event_params) ep WHERE ep.key = 'product_id') AS product_id,
  (SELECT ep.value.string_value FROM UNNEST(event_params) ep WHERE ep.key = 'currency') AS currency,
  (SELECT ep.value.string_value FROM UNNEST(event_params) ep WHERE ep.key = 'subscription_tier') AS event_subscription_tier,
  (SELECT ep.value.string_value FROM UNNEST(event_params) ep WHERE ep.key = 'premium_content') AS premium_content,
  COALESCE(
    (SELECT CAST(ep.value.int_value AS STRING) FROM UNNEST(event_params) ep WHERE ep.key = 'is_premium'),
    (SELECT ep.value.string_value FROM UNNEST(event_params) ep WHERE ep.key = 'is_premium')
  ) AS event_is_premium,
  COALESCE(
    (SELECT ep.value.int_value FROM UNNEST(event_params) ep WHERE ep.key = 'amount'),
    CAST((SELECT ep.value.double_value FROM UNNEST(event_params) ep WHERE ep.key = 'amount') AS INT64),
    CAST((SELECT ep.value.float_value FROM UNNEST(event_params) ep WHERE ep.key = 'amount') AS INT64)
  ) AS amount,
  COALESCE(
    (SELECT ep.value.double_value FROM UNNEST(event_params) ep WHERE ep.key = 'price'),
    CAST((SELECT ep.value.int_value FROM UNNEST(event_params) ep WHERE ep.key = 'price') AS FLOAT64),
    CAST((SELECT ep.value.float_value FROM UNNEST(event_params) ep WHERE ep.key = 'price') AS FLOAT64)
  ) AS price,
  COALESCE(
    (SELECT ep.value.int_value FROM UNNEST(event_params) ep WHERE ep.key = 'coins_spent'),
    CAST((SELECT ep.value.double_value FROM UNNEST(event_params) ep WHERE ep.key = 'coins_spent') AS INT64),
    CAST((SELECT ep.value.float_value FROM UNNEST(event_params) ep WHERE ep.key = 'coins_spent') AS INT64)
  ) AS coins_spent,
  COALESCE(
    (SELECT ep.value.int_value FROM UNNEST(event_params) ep WHERE ep.key = 'required_coins'),
    CAST((SELECT ep.value.double_value FROM UNNEST(event_params) ep WHERE ep.key = 'required_coins') AS INT64),
    CAST((SELECT ep.value.float_value FROM UNNEST(event_params) ep WHERE ep.key = 'required_coins') AS INT64)
  ) AS required_coins,
  (SELECT up.value.string_value FROM UNNEST(user_properties) up WHERE up.key = 'subscription_tier') AS user_subscription_tier,
  COALESCE(
    (SELECT CAST(up.value.int_value AS STRING) FROM UNNEST(user_properties) up WHERE up.key = 'is_premium'),
    (SELECT up.value.string_value FROM UNNEST(user_properties) up WHERE up.key = 'is_premium')
  ) AS user_is_premium
FROM `YOUR_GCP_PROJECT.analytics_123456789.events_*`
WHERE _TABLE_SUFFIX BETWEEN FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 550 DAY))
  AND FORMAT_DATE('%Y%m%d', CURRENT_DATE());

CREATE OR REPLACE VIEW `YOUR_GCP_PROJECT.prism_dash.revenue_blend_daily` AS
WITH days AS (
  SELECT event_day FROM `YOUR_GCP_PROJECT.prism_raw.revenuecat_daily`
  UNION DISTINCT
  SELECT event_day FROM `YOUR_GCP_PROJECT.prism_raw.admob_daily`
  UNION DISTINCT
  SELECT event_day FROM `YOUR_GCP_PROJECT.prism_raw.play_non_rc_daily`
),
rc AS (
  SELECT event_day, SUM(net_revenue_usd) AS revenuecat_net_usd
  FROM `YOUR_GCP_PROJECT.prism_raw.revenuecat_daily`
  GROUP BY event_day
),
admob AS (
  SELECT event_day, SUM(estimated_revenue_usd) AS admob_estimated_usd
  FROM `YOUR_GCP_PROJECT.prism_raw.admob_daily`
  GROUP BY event_day
),
play AS (
  SELECT event_day, SUM(non_rc_revenue_usd) AS play_non_rc_usd
  FROM `YOUR_GCP_PROJECT.prism_raw.play_non_rc_daily`
  GROUP BY event_day
)
SELECT
  d.event_day,
  COALESCE(rc.revenuecat_net_usd, 0) AS revenuecat_net_usd,
  COALESCE(admob.admob_estimated_usd, 0) AS admob_estimated_usd,
  COALESCE(play.play_non_rc_usd, 0) AS play_non_rc_usd,
  COALESCE(rc.revenuecat_net_usd, 0) + COALESCE(admob.admob_estimated_usd, 0) + COALESCE(play.play_non_rc_usd, 0)
    AS total_revenue_usd
FROM days d
LEFT JOIN rc USING (event_day)
LEFT JOIN admob USING (event_day)
LEFT JOIN play USING (event_day);

CREATE OR REPLACE VIEW `YOUR_GCP_PROJECT.prism_dash.quality_daily_raw` AS
SELECT
  event_day,
  AVG(crash_free_users_pct) AS crash_free_users_pct,
  SUM(fatal_issue_count) AS fatal_crash_count
FROM `YOUR_GCP_PROJECT.prism_raw.crashlytics_daily`
GROUP BY event_day;
