# Looker Studio Spec: Prism Success-Metrics Traffic-Light Dashboard

## Data sources
- `YOUR_GCP_PROJECT.prism_dash.kpi_status_daily`
- `YOUR_GCP_PROJECT.prism_dash.kpi_daily`
- `YOUR_GCP_PROJECT.prism_dash.subscription_funnel_daily`
- `YOUR_GCP_PROJECT.prism_dash.ai_coins_daily`
- `YOUR_GCP_PROJECT.prism_dash.geo_mix_daily`
- `YOUR_GCP_PROJECT.prism_dash.quality_daily`
- `YOUR_GCP_PROJECT.prism_dash.revenue_blend_daily`

## Global controls
- Date range control default: `Last 30 days`
- Timezone: GA4 property timezone
- Filter control: `status IN (green, amber, red, gray)`

## Page 1: Executive Scoreboard (RAG)
1. Add 12 scorecards from `kpi_status_daily` filtered to latest `metric_date` per metric.
2. Scorecard dimension: `metric_label`
3. Scorecard metric: `current_value`
4. Color by `status`:
   - green -> `#1E8E3E`
   - amber -> `#F9AB00`
   - red -> `#D93025`
   - gray -> `#5F6368`
5. Show secondary text: `launch_target`, `trajectory_target`, `status_reason`.

### Not Green table
Use `prism_dash.not_green_metrics_daily`.
Columns:
- `metric_label`
- `status`
- `current_value`
- `launch_target`
- `trajectory_target`
- `gap_to_target`
- `recommended_action`
Sort:
1. `status` custom order: red, amber
2. `gap_to_target` desc

## Page 2: Retention & Stickiness
Data: `kpi_daily`
Charts:
- Time series: `day_1_retention_pct`, `day_7_retention_pct`
- Time series: `dau`, `mau`, `dau_mau_pct`
- Reference lines:
  - D1 = 30
  - D7 = 12
  - DAU/MAU = 15

## Page 3: Growth & Geo Mix
Data: `geo_mix_daily` and `kpi_daily`
Charts:
- Geo map by country from `ga4_events` (optional direct source)
- Time series: `western_user_pct` with target line 30
- Time series: `new_users` vs `returning_users`

## Page 4: Monetization
Data: `subscription_funnel_daily`, `kpi_daily`, `revenue_blend_daily`
Charts:
- Funnel: `paywall_impressions -> purchase_started -> purchase_success`
- Stacked bars: `revenuecat_net_usd`, `admob_estimated_usd`, `play_non_rc_usd`
- Time series: `pro_conversion_pct`, `arpu_usd`, `monthly_revenue_usd`

## Page 5: AI + Coin Economy
Data: `ai_coins_daily`
Charts:
- Time series: `ai_generations_started`, `ai_generations_success`, `ai_generations_failed`
- Time series: `coins_earned_total`, `coins_spent_total`
- Time series: `rewarded_ad_watches`, `watch_and_download_used`
- Scorecard: `ad_watches_per_free_user_per_day`

## Page 6: Quality
Data: `quality_daily`, `kpi_status_daily`
Charts:
- Time series: `crash_free_users_pct`
- Time series: `fatal_crash_count`
- Table: top fatal issues (optional direct Crashlytics export source)
- Add URL field `crashlytics_issue_link` (if available from source) for drill-down.

## Required calculated fields (if needed in Looker)
- `status_sort`:
  - `CASE WHEN status='red' THEN 1 WHEN status='amber' THEN 2 WHEN status='green' THEN 3 ELSE 4 END`
- `is_not_green`:
  - `CASE WHEN status IN ('red','amber') THEN 1 ELSE 0 END`

## Dashboard acceptance checks
- Every KPI has one latest scorecard row
- Not Green table only shows red/amber rows
- Any source stale >48h renders impacted metrics gray
- Default dashboard load under 10 seconds for last 30 days
