# Prism Success-Metrics Dashboard (GA4 + Looker Studio)

This package implements the full data model and status logic for the traffic-light dashboard requested in `ROADMAP.md`, `GROWTH.md`, and `REVENUE.md`.

## What this package creates
- `prism_dash.kpi_targets`
- `prism_dash.subscription_funnel_daily`
- `prism_dash.ai_coins_daily`
- `prism_dash.geo_mix_daily`
- `prism_dash.quality_daily`
- `prism_dash.kpi_daily`
- `prism_dash.kpi_status_daily`
- `prism_dash.not_green_metrics_daily`

## Source dependencies
You need these canonical daily source tables first:
- `prism_raw.revenuecat_daily(event_day, net_revenue_usd)`
- `prism_raw.admob_daily(event_day, estimated_revenue_usd)`
- `prism_raw.play_non_rc_daily(event_day, non_rc_revenue_usd)`
- `prism_raw.crashlytics_daily(event_day, crash_free_users_pct, fatal_issue_count)`
- GA4 BigQuery export dataset (`analytics_<property_id>.events_*`)

## Execution order
1. Run `/Users/akshaymaurya/Development/codenameakshay/Prism/infra/analytics/success_metrics/sql/00_staging_and_sources.sql`
2. Run `/Users/akshaymaurya/Development/codenameakshay/Prism/infra/analytics/success_metrics/sql/01_kpi_targets.sql`
3. Run `/Users/akshaymaurya/Development/codenameakshay/Prism/infra/analytics/success_metrics/sql/02_subscription_funnel_daily.sql`
4. Run `/Users/akshaymaurya/Development/codenameakshay/Prism/infra/analytics/success_metrics/sql/03_ai_coins_daily.sql`
5. Run `/Users/akshaymaurya/Development/codenameakshay/Prism/infra/analytics/success_metrics/sql/04_geo_mix_daily.sql`
6. Run `/Users/akshaymaurya/Development/codenameakshay/Prism/infra/analytics/success_metrics/sql/05_quality_daily.sql`
7. Run `/Users/akshaymaurya/Development/codenameakshay/Prism/infra/analytics/success_metrics/sql/06_kpi_daily.sql`
8. Run `/Users/akshaymaurya/Development/codenameakshay/Prism/infra/analytics/success_metrics/sql/07_kpi_status_daily.sql`
9. Run `/Users/akshaymaurya/Development/codenameakshay/Prism/infra/analytics/success_metrics/sql/08_validation_checks.sql`

## Scheduling
Create one scheduled query pipeline in this order:
1. `02_subscription_funnel_daily.sql`
2. `03_ai_coins_daily.sql`
3. `04_geo_mix_daily.sql`
4. `05_quality_daily.sql`
5. `06_kpi_daily.sql`
6. `07_kpi_status_daily.sql`

Run daily after all source ingestions complete.

## RAG policy implemented
Primary launch thresholds:
- Day 1 retention: Green >= 30, Amber >= 25, Red < 25
- Day 7 retention: Green >= 12, Amber >= 10, Red < 10
- DAU/MAU: Green >= 15, Amber >= 12, Red < 12
- Pro conversion: Green >= 2, Amber >= 1.5, Red < 1.5
- Ad watches/free user/day: Green >= 3, Amber >= 2, Red < 2
- AI generations/day: Green >= 1000, Amber >= 700, Red < 700
- Crash-free users: custom (includes fatal crash override)
- Fatal crash count: Green 0, Amber 1, Red > 1

Secondary trajectory targets:
- Month 6: DAU >= 30K, Western users >= 30%, Revenue >= $5K, D1 retention >= 35%
- Month 12: DAU >= 60K, Revenue >= $10K

Freshness override:
- If required source is stale by >48h, status is forced to `gray` with `Data stale (>48h)`.

No-data handling:
- If metric value is null, status is forced to `gray` with `No data`.

## Looker Studio
Use `/Users/akshaymaurya/Development/codenameakshay/Prism/infra/analytics/success_metrics/looker_studio/dashboard_spec.md` as the page-by-page implementation blueprint.

## Validation
Run `/Users/akshaymaurya/Development/codenameakshay/Prism/infra/analytics/success_metrics/sql/08_validation_checks.sql` for:
- Formula correctness
- Boundary checks
- RAG integrity
- Revenue reconciliation
- Western % validation
- Crash metric validation
- Freshness enforcement
