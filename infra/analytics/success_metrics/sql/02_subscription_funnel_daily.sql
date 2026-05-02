CREATE OR REPLACE TABLE `YOUR_GCP_PROJECT.prism_dash.subscription_funnel_daily`
PARTITION BY event_day AS
SELECT
  event_day,
  COUNTIF(event_name = 'paywall_impression') AS paywall_impressions,
  COUNTIF(event_name = 'subscription_purchase_started') AS purchase_started,
  COUNTIF(event_name = 'subscription_purchase_result' AND result = 'success') AS purchase_success,
  COUNTIF(event_name = 'subscription_purchase_result' AND result = 'not_entitled') AS purchase_not_entitled,
  COUNTIF(event_name = 'subscription_purchase_result' AND result = 'failure') AS purchase_failed,
  COUNTIF(event_name = 'subscription_restore_started') AS restore_started,
  COUNTIF(event_name = 'subscription_restore_result' AND result = 'success') AS restore_success,
  COUNT(DISTINCT IF(event_name = 'subscription_conversion', user_key, NULL)) AS conversion_users,
  COUNT(DISTINCT IF(event_name = 'paywall_impression', user_key, NULL)) AS paywall_users,
  COUNT(DISTINCT IF(event_name = 'subscription_purchase_result' AND result = 'success', user_key, NULL)) AS purchaser_users,
  SAFE_DIVIDE(
    COUNT(DISTINCT IF(event_name = 'subscription_purchase_result' AND result = 'success', user_key, NULL)),
    COUNT(DISTINCT IF(event_name = 'paywall_impression', user_key, NULL))
  ) * 100 AS paywall_to_purchase_pct
FROM `YOUR_GCP_PROJECT.prism_dash.ga4_events`
GROUP BY event_day;
