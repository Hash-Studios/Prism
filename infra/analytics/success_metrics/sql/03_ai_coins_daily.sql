CREATE OR REPLACE TABLE `YOUR_GCP_PROJECT.prism_dash.ai_coins_daily`
PARTITION BY event_day AS
WITH user_day_membership AS (
  SELECT
    event_day,
    user_key,
    MAX(
      COALESCE(
        SAFE_CAST(event_is_premium AS INT64),
        SAFE_CAST(user_is_premium AS INT64),
        CASE
          WHEN LOWER(COALESCE(event_subscription_tier, user_subscription_tier, '')) IN ('pro', 'lifetime') THEN 1
          ELSE 0
        END
      )
    ) AS is_premium_user
  FROM `YOUR_GCP_PROJECT.prism_dash.ga4_events`
  WHERE user_key IS NOT NULL
  GROUP BY event_day, user_key
),
base AS (
  SELECT
    e.event_day,
    COUNTIF(e.event_name = 'ai_generate_started') AS ai_generations_started,
    COUNTIF(e.event_name = 'ai_generate_success') AS ai_generations_success,
    COUNTIF(e.event_name = 'ai_generate_failure') AS ai_generations_failed,
    COUNTIF(e.event_name = 'coin_earned' AND e.action = 'rewarded_ad') AS rewarded_ad_watches,
    SUM(IF(e.event_name = 'coin_earned' AND e.action = 'rewarded_ad', COALESCE(e.amount, 0), 0)) AS rewarded_ad_coins,
    SUM(IF(e.event_name = 'coin_earned', COALESCE(e.amount, 0), 0)) AS coins_earned_total,
    SUM(IF(e.event_name = 'coin_spent', COALESCE(e.amount, 0), 0)) AS coins_spent_total,
    COUNTIF(e.event_name = 'coin_watch_and_download_used') AS watch_and_download_used
  FROM `YOUR_GCP_PROJECT.prism_dash.ga4_events` e
  GROUP BY e.event_day
),
free_users AS (
  SELECT
    event_day,
    COUNT(DISTINCT IF(is_premium_user = 0, user_key, NULL)) AS free_active_users_1d,
    COUNT(DISTINCT user_key) AS active_users_1d
  FROM user_day_membership
  GROUP BY event_day
)
SELECT
  b.event_day,
  b.ai_generations_started,
  b.ai_generations_success,
  b.ai_generations_failed,
  SAFE_DIVIDE(b.ai_generations_success, NULLIF(b.ai_generations_started, 0)) * 100 AS ai_generation_success_pct,
  b.rewarded_ad_watches,
  b.rewarded_ad_coins,
  b.coins_earned_total,
  b.coins_spent_total,
  b.watch_and_download_used,
  f.free_active_users_1d,
  f.active_users_1d,
  SAFE_DIVIDE(b.rewarded_ad_watches, NULLIF(f.free_active_users_1d, 0)) AS ad_watches_per_free_user_per_day
FROM base b
LEFT JOIN free_users f USING (event_day);
