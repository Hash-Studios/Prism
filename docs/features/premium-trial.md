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

Live state on 2026-11-02: the current paywall has no trial text. Its annual card says "Full access for just $39.99/yr" and its button says "Continue".

1. In Product catalog, Offerings, open `v3_default`. Do not change the current offering.
2. Open the `$rc_annual` package. It must have App Store product `prism_v3_pro_annual` and Play Store product `prism_v3_pro_annual:annual`. Do not change `$rc_monthly` or `$rc_lifetime`.
3. In Product catalog, Products, make sure both annual products are attached to entitlement `prism_v3_pro_access`.
4. Open the `v3_default` paywall in the Paywalls editor. Make the 3 changes below. Each change uses an **Offer type** rule set to **Introductory offer**. The rule shows the text only to a user that the store makes eligible. Other users see the current text.
   - Annual card subtitle: select the text "Full access for just ...". Add a text rule, Offer type, Introductory offer. Enter text A.
   - Purchase button: select the text "Continue". Add a text rule, Offer type, Introductory offer. Enter text B.
   - Trial terms: add a new text component under the purchase button, above "Restore Purchases". Use the caption style of the footer links. Enter text C. Add a visibility rule, Offer type, Introductory offer, Show layer. The base state is hidden.
5. Add the text for each language that the paywall has. Keep the `{{ }}` variables as they are. The device localizes "1 week" and the price.
6. Do not add static trial text outside a rule. Do not mention a reminder: old app versions do not schedule one.
7. Publish the paywall. Check the preview with the Introductory offer state on and off.

| Text | Language | Value |
|---|---|---|
| A | en | `{{ product.offer_period_with_unit }} free, then {{ product.price_per_period_abbreviated }}` |
| A | de | `{{ product.offer_period_with_unit }} kostenlos, dann {{ product.price_per_period_abbreviated }}` |
| A | es | `{{ product.offer_period_with_unit }} gratis, luego {{ product.price_per_period_abbreviated }}` |
| A | hi | `{{ product.offer_period_with_unit }} मुफ़्त, फिर {{ product.price_per_period_abbreviated }}` |
| A | id | `Gratis {{ product.offer_period_with_unit }}, lalu {{ product.price_per_period_abbreviated }}` |
| A | pt-BR | `{{ product.offer_period_with_unit }} grátis, depois {{ product.price_per_period_abbreviated }}` |
| B | en | `Try free for {{ product.offer_period_with_unit }}` |
| B | de | `{{ product.offer_period_with_unit }} kostenlos testen` |
| B | es | `Prueba gratis durante {{ product.offer_period_with_unit }}` |
| B | hi | `{{ product.offer_period_with_unit }} मुफ़्त आज़माएँ` |
| B | id | `Coba gratis selama {{ product.offer_period_with_unit }}` |
| B | pt-BR | `Teste grátis por {{ product.offer_period_with_unit }}` |
| C | en | `{{ product.offer_period_with_unit }} free, then {{ product.price_per_period }}. Renews until you cancel. To avoid the charge, cancel at least 24 hours before the trial ends.` |
| C | de | `{{ product.offer_period_with_unit }} kostenlos, dann {{ product.price_per_period }}. Verlängert sich, bis du kündigst. Kündige mindestens 24 Stunden vor Ende des Testzeitraums, um die Zahlung zu vermeiden.` |
| C | es | `{{ product.offer_period_with_unit }} gratis, luego {{ product.price_per_period }}. Se renueva hasta que canceles. Para evitar el cargo, cancela al menos 24 horas antes de que termine la prueba.` |
| C | hi | `{{ product.offer_period_with_unit }} मुफ़्त, फिर {{ product.price_per_period }}. रद्द करने तक यह रिन्यू होता है. शुल्क से बचने के लिए ट्रायल खत्म होने से कम से कम 24 घंटे पहले रद्द करें.` |
| C | id | `Gratis {{ product.offer_period_with_unit }}, lalu {{ product.price_per_period }}. Diperpanjang sampai kamu membatalkan. Agar tidak ditagih, batalkan paling lambat 24 jam sebelum masa uji coba berakhir.` |
| C | pt-BR | `{{ product.offer_period_with_unit }} grátis, depois {{ product.price_per_period }}. Renova até você cancelar. Para evitar a cobrança, cancele pelo menos 24 horas antes do fim do teste.` |

For an eligible user in the US, the annual card shows "1 week free, then $39.99/yr", the button shows "Try free for 1 week", and the terms show "1 week free, then $39.99/year. ...". When the user selects monthly or lifetime, the button shows "Continue" and the terms are hidden, because those products have no offer.

### 2. App Store Connect: 7 days free on annual, in all territories

Live state on 2026-11-02: app `6670200846`, group `prism_v3` (`21940856`) has `prism_v3_pro_annual` and `prism_v3_pro_monthly`. Both are in `WAITING_FOR_REVIEW`. The annual product has no introductory offer. `asc` needs `--profile prism`.

```sh
asc --profile prism subscriptions offers introductory list --app 6670200846 --subscription-id prism_v3_pro_annual --output table
asc --profile prism subscriptions offers introductory create --app 6670200846 --subscription-id prism_v3_pro_annual \
  --all-territories --offer-duration ONE_WEEK --offer-mode FREE_TRIAL --number-of-periods 1 --dry-run
asc --profile prism subscriptions offers introductory create --app 6670200846 --subscription-id prism_v3_pro_annual \
  --all-territories --offer-duration ONE_WEEK --offer-mode FREE_TRIAL --number-of-periods 1 --output table
asc --profile prism subscriptions offers introductory list --app 6670200846 --subscription-id prism_v3_pro_annual --output table
```

- The first `list` must be empty. A territory can have only one introductory offer.
- The last `list` must show one row for each territory: `ONE_WEEK`, `FREE_TRIAL`, 1 period, no end date.
- If a territory fails, run the same `create` with `--territory <code>` for that territory only.
- Do not add an offer to `prism_v3_pro_monthly`.
- Apple gives an introductory offer one time per subscription group. A user who had monthly or annual in `prism_v3` is not eligible.
- The offer goes live with the subscription. While the subscription is in review, only sandbox sees it.

App Store Connect UI, if you do not use `asc`: Apps, Prism, Monetization, Subscriptions, `prism_v3`, Prism v3 Pro Annual, Subscription Prices, the add button, Create Introductory Offer. Countries: all. Start date: today. End date: No end date. Type: Free. Duration: 1 week.

### 3. Google Play: 7-day free trial for new customers

Live state on 2026-11-02: package `com.hash.prism`, subscription `prism_v3_pro_annual`, base plan `annual` (P1Y, active). It has region configs for ET, IN and US and an "other regions" price. It has no offers.

Eligibility is "Never had any subscription in this app". This is near to Apple's rule: a user who had monthly cannot get a free week by switching to annual.

```sh
cat > /tmp/free-trial-7d.json <<'JSON'
{
  "phases": [
    {
      "recurrenceCount": 1,
      "duration": "P7D",
      "regionalConfigs": [
        {"regionCode": "ET", "free": {}},
        {"regionCode": "IN", "free": {}},
        {"regionCode": "US", "free": {}}
      ],
      "otherRegionsConfig": {"free": {}}
    }
  ],
  "regionalConfigs": [
    {"regionCode": "ET", "newSubscriberAvailability": true},
    {"regionCode": "IN", "newSubscriberAvailability": true},
    {"regionCode": "US", "newSubscriberAvailability": true}
  ],
  "otherRegionsConfig": {"otherRegionsNewSubscriberAvailability": true},
  "targeting": {"acquisitionRule": {"scope": {"anySubscriptionInApp": {}}}}
}
JSON
gplay offers list --package com.hash.prism --product-id prism_v3_pro_annual --base-plan-id annual --output table
gplay offers create --package com.hash.prism --product-id prism_v3_pro_annual --base-plan-id annual \
  --offer-id free-trial-7d --json @/tmp/free-trial-7d.json --pretty
gplay offers activate --package com.hash.prism --product-id prism_v3_pro_annual --base-plan-id annual --offer-id free-trial-7d
gplay offers get --package com.hash.prism --product-id prism_v3_pro_annual --base-plan-id annual --offer-id free-trial-7d --pretty
```

- The first `list` must be empty.
- The last `get` must show `"state": "ACTIVE"`, one phase `P7D` with `free`, and `anySubscriptionInApp`.
- If `create` asks for a regions version, run it again with `--regions-version` set to the version in the error message.
- Do not add the `rc-ignore-offer` tag. RevenueCat then picks this offer as the default option.
- Do not change `prism_v3_pro_monthly` or the lifetime product.

Play Console UI, if you do not use `gplay`: Monetize with Play, Products, Subscriptions, `prism_v3_pro_annual`, base plan `annual`, Add offer. Offer ID: `free-trial-7d`. Eligibility: New customer acquisition, "Never had any subscription". Tags: none. Phases: Add phase, Free trial, 7 days. Regions: all. Save, then Activate.

### 4. Check before the release

Sandbox and Play license testing make a 1-week trial last about 3 minutes. So the reminder time (end minus 2 days) is already past when the trial starts, and the app schedules no notification. Check the reminder with the unit tests, not with sandbox.

1. On an iOS sandbox account with no history, open a paywall. The timeline shows 7 days free and $39.99.
2. Tap "See all plans". The annual card shows "1 week free, then $39.99/yr" and the button shows "Try free for 1 week".
3. Start the trial. The App Store sheet shows the free trial. Premium shows "Trial, ends <date>".
4. On a sandbox account that had monthly or annual, open a paywall. The normal paywall shows with no trial text.
5. Repeat 1 to 4 with a Play license tester on Android.
6. Open a paywall in the current store version of the app (no timeline). Eligible users see the RevenueCat trial text. Ineligible users see the old text.
