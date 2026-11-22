# Coin packs (roadmap J2)

Users buy Prism Coins with real money. Each pack is a consumable in-app purchase sold through RevenueCat. The server grants the coins. The app never grants them.

The feature is behind the Remote Config flag `coin_packs_enabled`. The default is `false`.

## Packs

| Product id | Base coins | Bonus | Coins granted | Price (US) | Price (IN) |
|---|---|---|---|---|---|
| `prism_coins_100` | 100 | 0% | 100 | $0.99 | ₹29 |
| `prism_coins_300` | 300 | +10% | 330 | $2.99 | ₹89 |
| `prism_coins_700` | 700 | +20% | 840 | $6.99 | ₹199 |
| `prism_coins_1600` | 1600 | +30% | 2080 | $14.99 | ₹449 |

- The product id names the base coins. The bonus is added on top.
- Prices keep the same base rate: about $0.99 or ₹29 for each 100 base coins.
- `docs/REVENUE.md` caps packs at $6.99 or ₹199. The first three packs fit. `prism_coins_1600` cannot fit at the same rate. It is set at $14.99. If you want to keep the cap, do not create that product. The sheet shows only packs that exist both in RevenueCat and in server config, so a missing product hides itself.
- The coin amounts live in server config: `economyConfig/current`, field `coinPacks`, a list of `{productId, coins, bonusPercent}`. The app reads the same doc to show the amounts. The server reads it to decide the grant. The app never decides how many coins a pack gives.
- The price comes from the store, through the RevenueCat offering `coins`. The app shows the localized `priceString`.

## Trust

The server grants coins only after RevenueCat confirms the purchase. The app and Firestore rules cannot grant coins.

```text
App                     verifyCoinPurchase           RevenueCat REST          Firestore
 | purchase (StoreKit /    |                              |                       |
 | Play Billing via RC)    |                              |                       |
 |--{transactionId}------->|--GET /v1/subscribers/{uid}-->|                       |
 |                         |<--non_subscriptions----------|                       |
 |                         |--grant transaction (once)------------------------->  |
 |<--{status, coins, balance}                             |                       |

RevenueCat webhook  ----->  revenueCatWebhook (Authorization header check)
  NON_RENEWING_PURCHASE      same REST read, same grant transaction
  CANCELLATION / REFUND      revoke transaction (once)
```

### One grant path

Both entry points run the same steps:

1. Find the purchase in RevenueCat: `GET https://api.revenuecat.com/v1/subscribers/{uid}` with the secret key `REVENUECAT_SECRET_KEY` (the same secret `syncSubscription` uses). Look in `subscriber.non_subscriptions` for the entry whose `store_transaction_id` (or RevenueCat `id`) equals the transaction id.
2. Decide. The product must be a pack in `coinPacks`. The store must be the App Store or Google Play. A sandbox purchase (`is_sandbox: true`) grants only when the functions param `COIN_PACKS_ALLOW_SANDBOX` is `true`.
3. Grant in one Firestore transaction (see "Exactly once").

The webhook body is not trusted for the grant. It only names the user and the transaction. The grant always comes from the REST read. So a leaked webhook header can at most trigger a REST check. It cannot invent a purchase.

### `verifyCoinPurchase` (callable)

- Input: `{transactionId}`. The id is `StoreTransaction.transactionIdentifier` from `purchases_flutter`: the StoreKit transaction id on iOS, the Play order id (`GPA.…`) on Android. Pattern `^[A-Za-z0-9._:-]{1,128}$`.
- The caller must be signed in with a real provider. Anonymous (guest) callers get `unauthenticated`.
- The caller's own RevenueCat customer is read. A user cannot claim another user's transaction, because it is not in their customer record.
- No `usersv2/{uid}` doc gives `not-found`. A deleted or closing account (`deleted: true`, or `creatorDeletionState/{uid}.closed`) gives `failed-precondition`, and no coins move.
- The coin pack catalog is read fresh from `economyConfig/current`. If that read fails, the call gives `unavailable`. It never falls back to the default amounts.
- RevenueCat down gives `unavailable`. The app retries.
- Throttle: 20 calls in 10 minutes per user, so one account cannot burn the RevenueCat rate limit that `syncSubscription` also needs.

| `status` | Meaning | App shows |
|---|---|---|
| `granted` | Coins added now. | Success, new balance. |
| `already_granted` | This transaction was granted before (by the webhook or an earlier call). | Success, current balance. |
| `not_found` | RevenueCat does not list this transaction for this user yet. | The app retries 3 times (1.5 s, 3 s, 6 s). Then "Pending. Your coins arrive in a few minutes." The webhook grants them. |
| `refused` | `reason`: `unknown_product`, `store_not_allowed`, `sandbox_not_allowed`, `other_user`. | Failed. |
| `revoked` | The purchase was refunded before it was granted. | Failed. |

### `revenueCatWebhook` (HTTPS)

- RevenueCat sends the `Authorization` header value set in its dashboard. The function compares it with the secret `REVENUECAT_WEBHOOK_AUTH` in constant time. A missing or wrong header gives `401` and changes nothing.
- Only `POST`. Other methods give `405`.
- The webhook gets every RevenueCat event, also subscription events. An event whose `product_id` is not a configured pack gets `200` and is ignored.
- `NON_RENEWING_PURCHASE` for a pack: resolve the user, run the grant path. The user is the first of `app_user_id`, `original_app_user_id`, then `aliases` that is not a `$RCAnonymousID:` id and has a `usersv2` doc. No such user gives `200` with a log line (`unknown_user`), so RevenueCat does not retry forever.
- `CANCELLATION` or `REFUND` for a pack: run the revoke path. A refund must also carry a valid `X-RevenueCat-Webhook-Signature` header: `t=<unix seconds>,v1=<hex HMAC-SHA256>` over `"<t>.<raw body>"` with the secret `REVENUECAT_WEBHOOK_SIGNING_SECRET`, at most 5 minutes old. A missing, altered or stale signature gives `401`. Grants do not need the signature, because every grant reads RevenueCat's REST API again. Refunds cannot be checked that way, so the signature stops a leaked Authorization header from taking coins away.
- The refund must match the receipt's product, store and environment. A mismatch changes nothing.
- A RevenueCat REST failure or a `not_found` gives `503`, so RevenueCat retries (up to 5 times, with backoff).
- Everything else gives `200`.

## Exactly once

The state of each store transaction lives in `coinPackReceipts/{transactionId}`. Clients cannot read or write this collection.

```text
            grant                 refund
 (none) ------------> granted -------------> revoked
   |                                            ^
   +--------------- refund (tombstone) ---------+
```

- Grant (one transaction): read the user and the receipt. No receipt: add the coins to `usersv2/{uid}.coins`, write the receipt as `granted`, and write the ledger row `coinTransactions/ctx_coinpack_{transactionId}`. A `granted` receipt for the same user returns `already_granted` and writes nothing. A receipt for another user returns `refused/other_user`. A `revoked` receipt returns `revoked`.
- Revoke (one transaction): a `granted` receipt takes its coins back from the user named in the receipt (never from the webhook's user), sets the receipt to `revoked`, and writes `coinTransactions/ctx_coinpack_refund_{transactionId}`. No receipt writes a `revoked` tombstone, so a late callable or webhook can never grant it. A `revoked` receipt does nothing.
- The receipt key is always the store transaction id, never RevenueCat's own id. A callable that sends RevenueCat's id resolves to the same receipt, so one purchase cannot be granted under two keys.
- So the callable and the webhook can arrive in any order, any number of times, and the coins move once.

## Refunds and chargebacks: the balance may go negative

A refund takes back the full pack, even when the user already spent the coins. The balance can go below 0.

Why negative and not "stop at 0 and flag":

- Coins can leave the account for value that cannot be taken back: tips to a creator, gifts, Drops, boosts. Stopping at 0 lets a user buy, spend or tip, then refund, and keep the value. That is free coins, paid for by the refund.
- A negative balance is self-healing. Every spend already checks `balance >= cost`, so the user cannot spend until earned or bought coins cover the debt. No manual review queue is needed.
- A flag needs someone to read it. There is no ops queue for coin abuse today.

The refund ledger row shows the full amount, so the user sees why the balance dropped.

## Bought coins and earned coins

- The ledger keeps the source. A pack row has `action: "coinPack"` and `source: "purchase"`, plus `productId`, `store`, `environment` and `storeTransactionId`. A refund row has `action: "coinPackRefund"`.
- Bought coins grant no XP and do not progress quests. Rank and quests measure play, not spend.
- Bought coins spend like earned coins. A tip paid with bought coins counts the same for the creator.

## Guests and sandbox

- Guests cannot buy. The app hides every buy entry for a guest, and the callable refuses anonymous callers.
- Sandbox purchases grant only when `COIN_PACKS_ALLOW_SANDBOX=true` in the functions env. Production leaves it unset (default `false`). The local emulator sets it in `functions/.env.local`.
- Risk: Apple App Review buys with sandbox accounts against the production backend. With sandbox off, a reviewer gets no coins. Before you submit the consumables for review, either keep the flag off for the review build (the reviewer then cannot find the packs, and Apple may ask for them), or turn sandbox on in production only for the review window. The ledger row keeps `environment`, so sandbox grants are easy to find and remove.

## App

- Flag: Remote Config `coin_packs_enabled`, default `false`. With the flag off, no buy entry shows anywhere.
- Sheet: "Get coins". It loads the RevenueCat offering `coins` and keeps the packages whose product id is in `coinPacks`. Each row shows coins, bonus and the store price.
- Purchase states: idle, purchasing (the row shows a spinner, other rows are disabled), verifying, success (new balance from the server), pending (store pending, or server `not_found` after retries), failed. A store cancel goes back to idle with no error.
- After success or pending the app reloads the balance from the server (`CoinsService.refreshBalance`).
- Entry points: the wallet (Rewards balance card), the shared coin gate sheet (downloads, original access, collections, premium filters), the short-balance sheet (spin wheel, daily chest), and every other place that says "not enough coins" (AI, photo wallpaper, Drops, tips, gift pass, boost, live style, auto-rotate, draw, shop, streak freeze and rescue, folder Save all).
- Analytics: `coin_pack_viewed` (source), `coin_pack_purchase_started` (pack), `coin_pack_purchased` (pack, outcome). Revenue is reported by RevenueCat, not Mixpanel.

## Limits

- `REFUND_REVERSED` (App Store only) is ignored. A refund that Apple reverses stays revoked. Grant it back by hand if a user asks.
- The webhook does not sync subscriptions. `syncSubscription` and `reconcileSubscriptions` still own premium.
- The RevenueCat v1 customer record must list `store_transaction_id` on non-subscription entries. An entry without it stays `not_found` (pending), so it can never be granted under a second key.
- A refund for a deleted account marks the receipt `revoked` and writes no ledger row.
- Remove a pack from `coinPacks` only after it is gone from the stores and the `coins` offering. A refund for a product that is no longer configured, arriving before its grant, leaves no tombstone.
- Open owner decision: when RevenueCat merges two real Prism accounts (aliases), the v1 record can list one purchase for both. Today the first eligible account is paid, once. Options: (1) keep that, or (2) hold such purchases as pending for manual reconciliation. Recommended: (2).

## Owner setup

Do these in order. Nothing here is done by the PR.

1. App Store Connect: create 4 consumable in-app purchases with the product ids above, the prices above, a display name and description in each store language, and a review screenshot.
2. Play Console: create 4 one-time products with the same ids and prices. Activate them.
3. RevenueCat: import the 8 products. Create the offering `coins` with 4 packages, one per pack (custom package ids, for example `coins_100`). No entitlement is needed.
4. Generate a long random string. Store it in Doppler `prd` as `REVENUECAT_WEBHOOK_AUTH`.
5. RevenueCat: Integrations, Webhooks, add `https://us-central1-prism-wallpapers.cloudfunctions.net/revenueCatWebhook`. Set the Authorization header to the string from step 4. Environment: both. Turn on HMAC signing and copy its signing secret into Doppler `prd` as `REVENUECAT_WEBHOOK_SIGNING_SECRET`. Without it, every refund gets `401` and refunded coins stay with the user.
6. Run `make functions-secrets-sync`. It syncs every name in `FUNCTIONS_SECRETS`, including both new ones.
7. Write `coinPacks` into `economyConfig/current` (or keep the defaults in `economy.ts`).
8. Deploy functions: `make functions-deploy`.
9. Ship the app.
10. After the deploy, send a test event from RevenueCat and check for `200` in the function logs.
11. Turn on `coin_packs_enabled` in Remote Config.

## How to test

1. `cd functions && npm run build && node --test lib/__tests__/coinPacks.test.js`
2. `fvm flutter test test/features/coin_packs/ test/core/coins/economy_config_coin_packs_test.dart`
3. Local QA (no real store, no real RevenueCat). Use a checkout without real native Firebase config (`ios/Runner/GoogleService-Info.plist`, `android/app/google-services.json`); the weekly QA preflight that `prepare` runs refuses them. `seed` resets the viewer to 50 coins and clears the coin pack receipts, ledger rows and fake RevenueCat state. `node tool/coin_packs_qa.cjs` runs the real `verifyCoinPurchase` and `revenueCatWebhook` in the Functions emulator. A relay on `https://localhost:19375` plays RevenueCat's REST API, and the app's local QA build replaces only the StoreKit step (`lib/core/debug/local_qa_coin_packs.dart`). Commands: `prepare`, `serve`, `emulators`, `seed`, `build-ios`, `run-ios <udid>`, `hold-on`, `hold-off`, `cancel-next`, `webhook <tx>`, `webhook-bad <tx>`, `refund <tx>`, `refund-unsigned <tx>`, `verify <tx>`, `ledger`.
4. Real store, from Xcode: `ios/Runner/PrismCoins.storekit` lists the 4 consumables. Select it in the Runner scheme (Run, Options, StoreKit Configuration) and run from Xcode; `flutter run` does not apply a StoreKit file. RevenueCat accepts these local transactions only after you upload the StoreKit test certificate in the RevenueCat dashboard.
