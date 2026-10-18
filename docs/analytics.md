# Analytics tracking reference

The typed contract is `lib/core/analytics/schema/analytics_events.yaml`. Run
`make analytics-gen` after edits. `make analytics-check` verifies enum parity,
raw SDK usage boundaries, and generated output. Existing event names remain
available; optional correlation fields are additive.

## Identity, sessions, and delivery

The app exposes one stable analytics facade. Before the provider is attached,
it retains at most 256 calls for up to two minutes. Overflow drops the old
batch and retains the current identity snapshot with subsequent calls. Expired
startup events are dropped. Identity commands and events replay in order.
Startup callers do not wait for provider initialization. Provider failures are
contained and do not cancel downloads, paid generations, or purchases. Delivery
is best effort; a completed analytics future is not proof of ingestion.

Signed-in account changes reset before identifying the next account. Logout
resets once; an initial guest state does not reset the anonymous device on
every launch. A provider replacement receives the current identity and user
properties. Runtime reset discards old queued calls.
The Mixpanel provider reads the persisted `logged_in` super-property so that
an initial guest sync clears a stale signed identity while retaining a stable
anonymous device ID. Startup into the same persisted account identifies
without an extra reset; switching to a different account resets first. SDK
state without that historical marker cannot be classified reliably and is
preserved.

Native events include `analytics_schema_version=2` and `analytics_session_id`.
A session is the lifetime of a provider instance in the app process, not an
idle-timeout session or a promise of cross-device identity. The marketing site
uses an anonymous sessionStorage ID and does not join it to an app account.

## Journey events and joins

| Journey | Events and interpretation | Join fields |
| --- | --- | --- |
| Discovery | `wallpaper_impression`, `surface_action_tapped` (`tile_opened` / `carousel_item_opened`), navigation `screen_view` | item/provider/source and `request_id` where available; screen views are separate navigation records |
| Search | `search_submitted`, `search_results_loaded`, `search_result_opened` | `search_id`; submitted provider can be `auto`, loaded provider is actual |
| Download | `download_attempt`, `download_result`, legacy successful `download_wallpaper` | `operation_id`, item/provider/source, originating `request_id` |
| Set wallpaper | `set_wall` reports platform result with target and failure code | `operation_id`, item/provider/source, originating `request_id` |
| Follow | `follow_result` includes creator, source, action and result | creator identity and source |
| AI | charge preparation/commit/rollback and generation result events | `operation_id`, available transaction/generation IDs, duration, error category, refund result |
| Purchase | `paywall_result`, `purchase_verified`, `subscription_conversion` | transaction/product ID, source and placement where available |
| Rewards | `streak_lifecycle`, `referral_result` | server-provided streak milestone; referral role, outcome and reason |

An impression requires at least 50% visible area continuously for 500 ms.
Clipping by ancestor viewports, scrolling, app backgrounding and route coverage
interrupt eligibility. It is deduplicated per provider/item within the shared
request session. A new feed/search request creates a new impression scope.
Not every legacy navigation path supplies a request ID; do not manufacture one
to claim an origin that was not captured.

Search replacement emits cancellation for superseded in-flight work rather
than claiming a failed search. Download result stages distinguish access,
preparation and transfer outcomes. Join attempts to terminal results before
computing success rates; raw result counts can contain retries. AI refund
states distinguish confirmed/already-completed refunds, retryable pending
refunds, terminal denials/failures and cases where no charge occurred.
Deferred AI refund recovery emits `ai_charge_rolled_back` with the original
charge transaction ID; an unavailable original operation ID is omitted.
Streak milestones come from the server, not client modulo
arithmetic.

Useful funnels are impression → tap → detail → download/set, search submitted
→ loaded → result opened, paywall shown → result → verified purchase, and AI
charge prepared → committed → generation result → refund outcome. Filter by
provider/source and join correlation IDs before comparing conversion rates.
Screen views are navigation observations, not visibility impressions.

## Revenue reporting

`purchase_verified` represents the completed SDK transaction or an explicitly
marked restore. `subscription_conversion.price_type=catalog` means the package
catalog price and currency at checkout. It does not establish the amount
charged, a paid renewal, a refund, or recognized revenue. Free trials, offers,
taxes and store settlement can differ from this value. Never sum catalog
prices as collected revenue. Restore events are not new sales.

For authoritative revenue, configure RevenueCat's Mixpanel integration in the
RevenueCat project dashboard with the Mixpanel project token and matching
RevenueCat app-user IDs. Confirm which purchase, renewal, cancellation,
expiration and refund lifecycle events the integration supports and emits.
Verify a sandbox purchase, renewal and refund against RevenueCat's event history and Mixpanel
Live View. Build revenue reports from RevenueCat's charged amount/currency
and transaction identifiers, deduplicating initial purchases against native
receipt events. Do not enable both a webhook importer and the integration
without one transaction/event deduplication policy. Dashboard configuration,
credentials and live validation are separate release steps and are not
applied by this code change.

## Marketing site

The static export sends direct HTTPS Mixpanel requests only when built with
`NEXT_PUBLIC_MIXPANEL_TOKEN`. It records `web_landing_viewed`,
`web_store_clicked` and `web_qr_viewed`, with path, store and allowlisted UTM
campaign values. It sends no account ID or arbitrary query string; transport
failure cannot block navigation. Session storage is best effort. Configure
the public token in the hosting build environment and rebuild the export to
enable collection; no hosting settings or deployment are changed here.
