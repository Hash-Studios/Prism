# GA4 Custom Definitions for Prism Success Dashboard

Register these definitions in GA4 Admin before validating Looker Studio cards.

## Event-scoped custom dimensions
- `source`
- `source_context`
- `placement`
- `result`
- `rc_or_fallback`
- `action`
- `mode`
- `package_type`
- `product_id`
- `currency`
- `subscription_tier`
- `premium_content`
- `is_premium`

## Event-scoped custom metrics
- `amount`
- `price`
- `coins_spent`
- `required_coins`

## Conversion event registration
Mark these events as key events in GA4:
- `subscription_conversion`
- `subscription_purchase_result` (optional, filtered by `result=success` in reporting)
- `subscription_restore_result` (optional, filtered by `result=success`)

## User properties to register
- `subscription_tier`
- `is_premium`

## Notes
- App instrumentation emits canonical snake_case names.
- Legacy aliases (`reportSetup`, `reportWall`) are normalized in-app.
- For `is_premium`, values are emitted as string flags (`0`/`1`).
