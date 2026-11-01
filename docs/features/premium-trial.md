# Premium free trial

The annual Prism Pro plan has a 7-day free trial. Monthly and lifetime have no trial and keep their prices. Before an eligible user starts the trial, the app shows a timeline of what happens on each day.

## Where to find it

Every paywall goes through `PaywallOrchestrator.present`. When the user can get the trial, the app shows the timeline before the RevenueCat paywall. When the user cannot get the trial, the app shows the normal RevenueCat paywall.

Code:

- `lib/core/purchases/annual_trial.dart`: trial eligibility and the trial in `CustomerInfo`.
- `lib/core/purchases/trial_reminder.dart`: the reminder and the trial analytics.
- `lib/core/purchases/paywall_orchestrator.dart`: the timeline step and the purchase.
- `lib/features/premium/views/pages/trial_timeline_page.dart`: the timeline screen.
- `lib/features/premium/views/pages/premium_page.dart`: the trial state.

## Who sees the timeline

The app shows the timeline only when all of these are true:

1. The `v3_default` offering has an annual package.
2. The annual store product has a free first phase that is counted in days or weeks.
3. The store says that this user can get it.

| Platform | Rule |
|---|---|
| iOS | `introductoryPrice` has price 0 and 1 cycle, and `checkTrialOrIntroductoryPriceEligibility` returns `eligible`. `unknown` and `ineligible` show no trial. |
| Android | `defaultOption.freePhase` exists on the annual product. Google Play returns only the offers that this user can buy. |

A user who cannot get the trial sees the normal paywall. The app adds no trial words. The app logs `trial_not_eligible_shown` with `reason`: `noTrialOffer`, `ineligible` or `eligibilityUnknown`.

## The timeline

The screen shows 3 steps. It uses the device's local calendar dates, so the dates still advance by one calendar day across daylight-saving changes. The trial length comes from the store product. The format follows the app language.

1. **Today**: "You get full access to Prism Pro. You pay nothing today."
2. **Day 5** (trial length minus 2): "We remind you that your trial ends soon." When the user turns off the reminder, the step reads "No reminder. You turned it off below." A trial of 2 days or less has no reminder step.
3. **Day 7** (trial length): "You pay <price>, unless you cancel at least 24 hours before." The price is `StoreProduct.priceString`, so the store formats it.

The screen also shows:

- The plan summary: "Prism Pro yearly. 7 days free, then <price> a year."
- The switch "Remind me 2 days before the trial ends". It is on by default.
- The renewal terms, a link to the store subscription settings, Terms of use, and Privacy policy.
- "Start 7-day free trial". Before buying, the app checks that the account is still the one that opened the timeline and reloads the offer. It stops if the user is no longer eligible or the product, trial length, or price changed. It then buys the annual package with `Purchases.purchase`. A cancelled or failed purchase leaves the timeline open so the user can retry.
- "See all plans". This opens the RevenueCat paywall with every plan.
- A close button in the header. The header does not scroll, so the button is always visible.

The app logs `trial_timeline_shown` and `trial_reminder_toggled`.

### App Store guideline 3.1.2

| Requirement | Where |
|---|---|
| Name of the subscription | "Prism Pro yearly" in the plan summary and the terms |
| Length of the subscription | "a year" in the plan summary and the terms |
| Price | The store price in the plan summary, Day 7 step and terms |
| Free trial length and what happens after it | Plan summary, Day 7 step, button label |
| Auto-renewal and how to cancel | Terms: "renews at <price> a year until you cancel", "cancel at least 24 hours before the trial or a renewal ends" |
| Link to manage the subscription | "Cancel any time in App Store settings" |
| Terms of use and Privacy policy | Links under the terms |
| Restore purchases | Settings, and the RevenueCat paywall from "See all plans" |

## The reminder

`TrialReminder.apply` runs for each `CustomerInfo` that `PurchasesService` applies: at app start, after a purchase or a restore, and on each update from RevenueCat. It is safe to run many times. It ignores updates for a different signed-in account. An account change invalidates queued reminder work; logout clears the active trial and pending reminder. During startup, the app keeps a scheduled notification that belongs to the resolved account and clears one that belongs to another account. Trial analytics state stays saved. The app records an inbox fallback once per user and trial end date, and keeps that record when reminder state is reset. A missing scheduled request does not mean the operating system delivered a notification.

1. The trial comes from an active, unexpired paid entitlement with `periodType == trial`. The end date is its `expirationDate`, which is the date the store charges. An expired trial is ignored.
2. The reminder time is the end date minus 2 days. The app never uses the time of the tap.
3. The app keeps the reminder only when the trial is active, auto-renew is on, and the user left the switch on.
4. When notifications are allowed, the app schedules local notification `290729` on channel `subscription`. If the end date changes, the app moves the notification. It does not schedule a new notification after the reminder time. If the matching request is still pending after that time, the app keeps it so a late operating-system delivery remains possible.
5. When notifications are not allowed, the app puts the reminder in the in-app inbox after the reminder time and before the end date, once for each user and end date. If a previously scheduled request is missing, that alone does not suppress the inbox fallback. Its `local_` ID includes the user and end date. Inbox sync keeps local-only items, so a server refresh does not remove this reminder.
6. When the trial converts, is cancelled, or is refunded, the app removes the notification.

Text: "Your free trial ends on <date>" and "After that, you pay for Prism Pro yearly. To avoid the charge, cancel in <store> settings at least 24 hours before." A tap opens `/premium`.

Android needs `ScheduledNotificationReceiver`, `ScheduledNotificationBootReceiver` and `RECEIVE_BOOT_COMPLETED` in `AndroidManifest.xml`. The app uses inexact alarms, so it does not need the exact alarm permission.

## Trial analytics

The app compares each `CustomerInfo` with the last trial state that it saved for the user (`trialState.<uid>`).

| Event | When |
|---|---|
| `trial_started` | A trial appears for the first time on this device |
| `trial_cancelled`, `reason: auto_renew_off` | Auto-renew goes from on to off during the trial |
| `trial_converted` | The trial ends and the same product is active with a normal period |
| `trial_cancelled`, `reason: refunded` or `ended` | The trial ends with auto-renew on and no paid period |

## Premium during a trial

The Premium screen shows "Trial, ends <date>" and a "Manage subscription" button. When auto-renew is off, it also shows "Auto-renew is off. You will not be charged when the trial ends."

A trial user gets full Pro. RevenueCat reports a trial as an active entitlement that expires at the trial end. `syncSubscription` and `PurchasesService.tierFromCustomerInfo` count it as `pro`. No server change was necessary.

## Old app versions

Old versions use the same `v3_default` offering and the RevenueCat paywall. After the store setup, the store gives an eligible user the trial when the user buys annual in an old version. The App Store and Google Play purchase sheets show the trial. Old versions schedule no reminder. Make the RevenueCat template honest for them (step 3 below).

## Store and RevenueCat setup

Do these steps in this order. The app release can come before or after them: without a store offer, the app shows the normal paywall. Change the RevenueCat paywall first, so that old app versions show trial text only when the store gives a trial.

### 1. RevenueCat

1. In Product catalog, open the `v3_default` offering. Make sure the `$rc_annual` package has the iOS annual product and the Play annual product with base plan `<BASE_PLAN_ID>`. Do not change the monthly or lifetime packages. Do not change the current offering.
2. Open the `v3_default` paywall. Put all trial text inside an "Introductory offer" rule, with the normal price text as the fallback. Use `{{ product.offer_period }}` and `{{ product.offer_price_with_zero }}`. Do not add static trial text. Do not promise a reminder, because old app versions do not schedule one.
3. Check the paywall preview with an eligible and an ineligible sandbox account.

### 2. App Store Connect: 7 days free on annual, in all territories

The iOS annual product is `prism_v3_pro_annual` (read from the live `v3_default` offering on 2026-11-01). `asc` takes a product ID with `--app`.

```sh
asc subscriptions offers introductory list --app "$ASC_APP_ID" --subscription-id prism_v3_pro_annual --output table
asc subscriptions offers introductory create --app "$ASC_APP_ID" --subscription-id prism_v3_pro_annual \
  --all-territories --offer-duration ONE_WEEK --offer-mode FREE_TRIAL --number-of-periods 1 --dry-run
asc subscriptions offers introductory create --app "$ASC_APP_ID" --subscription-id prism_v3_pro_annual \
  --all-territories --offer-duration ONE_WEEK --offer-mode FREE_TRIAL --number-of-periods 1
asc subscriptions offers introductory list --app "$ASC_APP_ID" --subscription-id prism_v3_pro_annual --output table
```

- Make sure the `list` shows no other introductory offer on annual before you create one. A territory can have only one.
- Do not add an offer to the monthly subscription.
- Apple gives an introductory offer one time for each subscription group. A user who had any subscription in the group is not eligible.

### 3. Google Play: 7-day free trial for new customers

In Play Console, open Monetize, Subscriptions, the annual subscription, and the yearly base plan. Add an offer:

| Field | Value |
|---|---|
| Offer ID | `free-trial-7d` |
| Eligibility | New customer acquisition: "Never had this subscription" |
| Phase 1 | Free trial, 7 days |
| Tags | None. Do not add `rc-ignore-offer`. |
| Regions | All regions of the base plan |

Then activate the offer. Do not change the monthly subscription or the lifetime product.

### 4. Check before the release

1. On an iOS sandbox account with no history, open a paywall. The timeline shows.
2. On a sandbox account that had annual, open a paywall. The normal paywall shows with no trial text.
3. On a Play license tester with no history, open a paywall. The timeline shows.
4. Start a trial. Premium shows "Trial, ends <date>". A notification is pending 2 days before that date.
