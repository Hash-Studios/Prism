# Promo codes

An admin makes a code for a post, a giveaway or a creator collab. A signed-in user enters the code in the app and gets coins or Pro days. The server keeps every limit. App Store and Google Play offer codes have their own entry point.

The `redeemCode` callable is the only path that grants a code. Clients cannot read or write `promoCodes`, its `redemptions` subcollection, or `promoRedeemRate`.

## Where users enter a code

| Entry | Where | What it opens |
|---|---|---|
| Redeem a Prism code | Settings, Codes group | The redeem sheet (`source: settings`) |
| Redeem a code | Rewards, Earn coins | The redeem sheet (`source: rewards`) |
| `https://prismwalls.com/redeem?code=X` | A link in a post | Rewards with the redeem sheet open and the code filled in (`source: link`). The user must tap Redeem. The link never redeems by itself. |
| Redeem an App Store code | Settings, Codes group, iOS | Apple's offer code sheet (`Purchases.presentCodeRedemptionSheet`) |
| Redeem a Play code | Settings, Codes group, Android | `https://play.google.com/redeem` in the Play Store |

The Codes group has one line that says which code goes where. On iOS: "Prism codes give coins. App Store codes give Pro." On Android: "Prism codes give coins or Pro days. Play codes give Pro."

## Code types

| Type | Amount | Grant |
|---|---|---|
| `coins` | 1 to 1,000 | In the redeem transaction: `usersv2/{uid}.coins` goes up by the amount, and the transaction writes `coinTransactions/ctx_promo_{codeId}_{uid}` (`action: promoCode`, `type: credit`). This is the same balance and ledger shape as `awardCoins`. No XP, quest or rank reads it. |
| `premiumDays` | 1 to 90 | In the redeem transaction: `usersv2/{uid}/private/economy.passes.premiumPassUntil` becomes `max(now, current end) + days`. This is the pass that `giftPremiumPass` writes. It unlocks Pro content. |

### Pro days on iOS

App Review guideline 3.1.1 requires In-App Purchase for Pro access on iOS. The old Enter Code feature was removed for this reason (commit `460bd315a`). The server refuses a `premiumDays` code when the client sends `platform: ios`, with the reason `premium_not_on_ios`. Coin codes work on both platforms. On iOS, Pro offers go through App Store offer codes.

`platform` is supplied by the client, not attested. This rejects normal iOS app requests, but does not stop a modified client from claiming Android or an Android pass from later being used on iOS.

## Limits

| Limit | Rule | Reason |
|---|---|---|
| Sign-in | Signed in, verified email, provider is not anonymous | `unauthenticated` error |
| Auth account | Auth account still exists, checked for every valid grant and replay even when no age rule is set | `not-found` error |
| Format | Uppercase, spaces and `-` removed. 10 to 32 characters from `ABCDEFGHJKLMNPQRSTUVWXYZ23456789`. This is the uppercase part of the short-link alphabet, so it has no I, O, 0 or 1. | `invalid_code` |
| Rate, user | 10 attempts an hour. Every attempt counts, also a success. | `rate_limited` |
| Rate, IP | 30 misses an hour (`invalid_code` and `not_found` only). Successes do not count. Once the miss limit is reached, all new attempts from that IP are refused until the next hour, including valid codes. | `rate_limited` |
| Exists | `promoCodes/{codeId}` | `not_found` |
| Turned off | `disabled: true` | `disabled` |
| Expiry | `expiresAt` is in the future | `expired` |
| Total | `redemptionCount < maxRedemptions` | `limit_reached` |
| Once per user | `promoCodes/{codeId}/redemptions/{uid}` does not exist | `already_redeemed` |
| Account age | Auth account is `minAccountAgeDays` old or more | `account_too_new` |
| New users only | When `newUsersOnlyDays` is set, the Auth account is that many days old or less | `new_users_only` |
| Pro on iOS | `premiumDays` code and `platform: ios` | `premium_not_on_ios` |
| Paid subscriber | `premiumDays` code and `usersv2.premium == true` | `already_premium`. Nothing is written and the code is not used up. |
| Busy | The transaction gave up after its retries. Nothing was written. | `busy` |
| Profile | No `usersv2` profile, `deleted: true`, or an account deletion in progress | `not-found` error |

The response is `{ok: true, reward, coinBalance?, premiumUntil?, replayed}` or `{ok: false, reason}`.

## Documents

| Path | Fields |
|---|---|
| `promoCodes/{codeId}` | `code`, `reward` (`{type: coins, coins}` or `{type: premiumDays, days}`), `maxRedemptions`, `redemptionCount`, `expiresAt`, `minAccountAgeDays`, `newUsersOnlyDays`, `disabled`, `label`, `createdBy`, `createdAt`, `lastRedeemedAt` |
| `promoCodes/{codeId}/redemptions/{uid}` | `uid`, `requestId`, `reward`, `platform`, `redeemedAt`, `coinBalance` and `transactionId`, or `premiumUntil` |
| `promoRedeemRate/u_{uid}_{hour}` and `ip_{hash}_{hour}` | `count`, `expiresAt`. A TTL policy deletes them. The limit does not depend on the TTL, because each hour has its own document. |

`codeId` is the first 32 hex characters of the SHA-256 of the code. Document paths, ledger IDs and logs never hold the code itself. Only the `code` field of the code document holds it.

The old `codes` collection is not used. Its documents had one `code`, a `redeemed` flag and a `winner` copy of the whole user profile. They had no type, amount, limits or count. The `codes` rules stay admin-only.

## Idempotency and races

- The client sends a `requestId`. It keeps the same `requestId` while it retries one code after `network`, `busy` or `unknown`. It makes a new one for a new code or after a definite answer.
- The server reads the user's redemption document before rate limiting. A replay still requires a live Auth account and a transaction that checks the profile, deletion barrier and stored redemption. The platform rule also applies: iOS cannot replay a Pro grant. With the same `requestId`, an eligible caller gets the stored grant with `replayed: true`, even after the code expired, ran out, or the user subscribed. With another `requestId` the answer is `already_redeemed`.
- After checking Auth existence, one Firestore grant transaction reads the code, redemption, profile and deletion barrier. It checks code limits, account-age eligibility, platform and paid-subscriber status before writing the grant, ledger or pass, count and redemption. At the last redemption exactly one transaction wins. Other users retry against fresh data and get `limit_reached`.
- The redemption and ledger documents are created with `create`. Same-user retries check the redemption before code limits. Collision recovery rechecks profile, deletion and platform before replaying the stored grant; Auth was checked before the grant attempt.

Known client limitation: a `CoinsService.refreshBalance` started before a fresh Pro grant can complete later and overwrite the new pass with stale state. This needs refresh ordering in `lib/core/coins/coins_service.dart`; the race remains unresolved.

## Abuse review

Before code, a reviewer checked the model for brute force, alt-account farming and races.

| Question | Verdict | Change |
|---|---|---|
| Can someone guess codes? | Random codes have 32^10 (about 10^15) values. Short vanity codes are the risk. | Minimum length 10 for all codes. The user rate limit counts every attempt in a transaction before the lookup, so parallel calls cannot pass it. |
| Is the IP real? | The implementation uses the last `X-Forwarded-For` hop. Its identity and resistance to spoofing are not proven on a live deploy yet. | Successes do not add to the miss counter, but hitting the counter blocks valid codes too. A shared proxy address can block unrelated users. Check it after deploy (see below). |
| Alt-account farming | Account age only delays it. Each alt still needs a verified email. | Verified email required. The real control is the budget: `maxRedemptions` times the amount. Keep giveaway codes small. |
| Race at the limit | Firestore transactions are serializable. | A burst on one hot code can give `busy`. The client retries with the same `requestId`. |
| Retry after a limit changed | The first model checked the redemption last, so a retry after expiry said `expired`. | The redemption is checked first. |
| Pass shortening | `giftPremiumPass` wrote `now + 24 h` over a longer pass. A gift cut a 90-day promo pass to one day. | `giftPremiumPass` keeps `max(now + 24 h, current end)`. Gifts do not shorten a longer pass, but do not add a day to it either. Promo days stack from the current end. |
| Leaks | A code in a document ID, a ledger ID or a log can leak it. | `codeId` is a hash. Analytics events carry the source, type, reason or platform, never the code. |
| Deleted users | Not checked in the first model. | Grants and replays require Auth existence and a live profile with no deletion barrier. Gifts check sender and recipient profiles and deletion barriers. |
| Kill switch | Not in the first model. | `disabled` and `setPromoCodeDisabled`. |

The review keeps the existing farming policy: verified email and optional Auth-age rules slow account creation, but do not establish one human per account. The code's redemption limit and reward amount bound the giveaway budget. No stronger identity or device restriction was added.

## Admin

Admins open Admin review, then Promo codes (`/admin-promo-codes`, `_adminGuard`).

On iOS, the admin form offers coin codes only; existing Pro codes can still be listed and enabled or disabled.

| Callable | What it does |
|---|---|
| `createPromoCode` | Validates the type, amount, `maxRedemptions` (1 to 100,000), `expiresAtMs` (in the future, at most 366 days), `minAccountAgeDays` (0 to 365), `newUsersOnlyDays` (1 to 365 and above `minAccountAgeDays`), an optional custom code and a note. It makes a random 10-character code when no code is given. It refuses a custom code that exists. |
| `listPromoCodes` | The 50 newest codes with their redemption counts |
| `setPromoCodeDisabled` | Turns a code off or on |

All three require `isAdminCaller` (the `admin` claim, or a verified email in `admin_users` or `config/adminNotifications`).

### Batch codes for a giveaway

```sh
cd functions
npm run promo:create -- --project <id> --count 50 --type coins --amount 100 --expires-days 30 --label "Giveaway" --dry-run
npm run promo:create -- --project <id> --count 50 --type coins --amount 100 --expires-days 30 --label "Giveaway" --out codes.csv
```

`--dry-run` prints the plan and writes nothing. Without it, the script writes each created code to the `--out` CSV file (mode 600) before creating the next. A failed batch leaves prior rows in a partial CSV; inspect it before retrying. A process or file-system failure between creating a code and saving its row can still leave that code absent from the CSV. The script prints only the count and the path, never codes or backend error details, so codes do not get into terminal or CI logs. Other flags: `--max`, `--min-age-days`, `--new-users-days`.

## Analytics

| Event | Field |
|---|---|
| `redeem_sheet_opened` | `source`: `settings`, `rewards` or `link` |
| `redeem_succeeded` | `type`: `coins` or `premium_days` |
| `redeem_failed` | `reason`: one of the reasons above, or `signed_out`, `network`, `unknown` |
| `store_code_sheet_opened` | `platform`: `ios` or `android` |

No event carries the code.

## Local verification boundary

Functions unit tests cover promo grants, gifts and batch failures. Worker tests cover redeem landings and log redaction. Flutter tests cover the redeem flow and route contract. Builds and linters are separate checks. These local checks do not prove deployed proxy headers, real Firestore contention, device behavior or App Review acceptance; live Firebase and device verification are separate gates.

## Deploy order

All of these go before the store build that ships the redeem UI:

1. Firestore rules (`firestore.rules`): server-only `promoCodes`, `redemptions` and `promoRedeemRate`.
2. Firestore indexes (`firestore.indexes.json`): the TTL policy on `promoRedeemRate.expiresAt`.
3. Functions: `redeemCode`, `createPromoCode`, `listPromoCodes`, `setPromoCodeDisabled` (new), and `giftPremiumPass` (preserves a longer pass).
4. Cloudflare Worker: `/redeem` as an app page, `/redeem` and `/redeem/*` in the Apple app site association.

Before a giveaway, verify the trusted proxy chain on the actual callable deployment. Google's external Application Load Balancer can append both the client IP and load balancer IP to `X-Forwarded-For`, so its last hop is not universally the client. Do not switch blindly to another hop without checking which proxies are trusted.

After the functions deploy, send wrong-code requests from phones on different public networks and inspect the `promoRedeemRate` document IDs. They must not all share one `ip_` counter. Also check that adding an attacker-supplied `X-Forwarded-For` prefix does not change the counter for the same client. A shared proxy address can block unrelated users after 30 misses; a spoofable address lets attackers evade the limit. Both must be resolved before a giveaway. Local mocked headers do not prove either property.
