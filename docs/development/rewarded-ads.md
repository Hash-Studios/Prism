# Verified rewarded ads

## Contract and deployment boundary

The new `beginRewardedSession`, `getRewardedSession`, and HTTP `admobRewardedSsv`
functions run in `us-central1`, matching `appFunctions`. No deployment is part
of this change. Deploy and enable only with owner approval before shipping clients.

Authenticated `beginRewardedSession({requestId, placement, platform})` accepts an
8–64 character request ID (`A-Za-z0-9_-`), a 1–120 character source tag
(`A-Za-z0-9_.-`), and `android` or `ios`. Unknown fields are rejected.
Its version-1 reserved response contains `status`, `sessionId`, `userId`,
`customData`, `adUnitId`, `rewardCoins`, `showBeforeMs`, `callbackBeforeMs`, and
`adsRemaining`. Send `userId` and the **entire opaque customData** to Google's
SSV options before showing the returned unit. Never construct customData locally.
The customData format is an internal session ID plus a random token, not client proof.

Unavailable responses contain `version: 1`, `status: unavailable`,
`reason: daily_limit | cooldown | active_session | disabled`, `adsRemaining`,
and optional `retryAtMs`. Unavailable attempts do not consume a request ID.
Successful reservations persist indefinitely and replay the original response,
even after settlement or expiry. Reusing the ID with different placement/platform
is rejected. Clients must poll rather than show an old replay past showBeforeMs.

Owner-only `getRewardedSession({sessionId})` or `({requestId})` returns
`version: 1`, `sessionId`, `status: reserved | settled | expired`, `rewardCoins`,
optional `transactionId`, `currentBalance`, and today's `adsRemaining`.
There is no claim endpoint. Client reward callbacks never authorize coins.

## Reservation and delivery policy

The transaction reserves the amount, daily capacity, and first-of-day bonus
before display. UTC days use the existing economy limits. Legacy rewards and
new reservations share `coinAdRateDaily`; pending reservations count toward
the cap and first bonus. The user-wide display lock lasts at most ten minutes,
including across midnight. Settlement releases its own display lock and starts
a 20-second cooldown. A late settlement does not clear a newer session's lock.
Abandoned ads do not lock display for a day.

Google's signed timestamp must lie within the reservation's ten-minute earning
window. Delivery may arrive up to 24 hours after that window ends. Capacity and
bonus remain reserved until that grace ends. Polling reports reserved throughout
grace because a delayed callback can still settle. Expired capacity is reclaimed
lazily. Midnight creates a new daily budget; delayed settlement counts on the
reservation's original UTC day. The quest event uses settlement day. No XP is
granted for ads. Balance, ledger, original-day ad count, quest progress, session
status, and Google transaction receipt commit atomically.

Account deletion removes `rewardedAdSessions` and the user's display lock.
Only `rewardedAdGoogleTransactions` replay records remain, containing the opaque
session hash without UID, request ID, token, placement or timestamps. The existing
`creatorDeletionState` permanent barrier closes before private economy and
ledger deletion; both reservation and settlement read it in their transactions.
Deleted or missing profiles are never recreated. A callback cannot credit a
removed session. Do not remove the deletion barrier or reuse deleted UIDs.

## Fail-closed configuration

Set all of these in the deployed Functions environment:

- `REWARDED_AD_ENABLED=true` (all other values disable the new path).
- `REWARDED_AD_ANDROID_UNIT_ID` and `REWARDED_AD_IOS_UNIT_ID`: exact production
  `ca-app-pub-<16 digits>/<10 digits>` rewarded units.
- `REWARDED_AD_GOOGLE_REWARD_TYPE`: exact AdMob reward item (1–64 ASCII letters,
  digits, spaces, underscore, dot, or hyphen).
- `REWARDED_AD_GOOGLE_REWARD_AMOUNT`: exact positive integer AdMob reward amount.

Google reward metadata is not Prism's coin amount. Prism's amount is frozen from
the server economy at reservation. Google's sample publisher ID is refused,
including its Android and iOS test units. Configure AdMob SSV to the deployed
`admobRewardedSsv` HTTPS URL. Test units cannot settle production coins.
Disabling new reservations or changing unit/reward configuration does not cancel
accepted reservations. Settlement checks the metadata frozen in that reservation.

The verifier uses Node crypto ECDSA P-256/SHA-256 over the exact raw query prefix
before `&signature=...&key_id=...`, never decoded or reordered parameters.
Duplicate fields and malformed suffixes are refused. Public keys come only from
`https://www.gstatic.com/admob/reward/verifier-keys.json`, with a one-hour cache,
20-key bound, five-second timeout, and coalesced refresh. Unknown keys trigger
refresh at most once per 30 seconds. Key-service/network/Firestore failures
return HTTP 503 so Google can retry; invalid callbacks return 400.

## Legacy rollout exposure

`awardCoins(action: rewardedAd)` still trusts the client by default to preserve
installed clients. It is **not SSV-secure**, regardless of app version, request
ID, cooldown, or cap. New SSV enablement alone does not remove that exposure.
Owner approval is required to set `REWARDED_AD_LEGACY_UNTIL` to an ISO timestamp.
Before that instant old behavior remains; at and after it all legacy rewarded
awards fail with failed-precondition. An unset cutoff preserves compatibility;
an invalid configured cutoff disables legacy awards. No client-version signal
bypasses the cutoff. Deploy/config changes and the final cutoff are separate
owner-approved rollout steps. Do not describe production rewards as exclusively
verified until the legacy cutoff is effective.

## Local proof

Run `cd functions && npm ci && npm run build && node --test 'lib/__tests__/*.test.js'`.
Rewarded tests use the existing in-memory transaction pattern and locally
generated ECDSA fixtures. They do not call Google, Firestore, or production.
Hosted CI, emulator/device SSV configuration, deployment, and a real signed
Google callback remain separate checks.

Google documents the SSV `ad_unit` as the numeric unit suffix. Settlement accepts
that value or the full frozen unit ID. A real signed Google callback is still
required before rollout. Automatic post-watch upsells no longer run inside the
coin gate, so an upsell cannot delay the requested action or change its result.
