# Creator premium walls

A creator puts a coin price on one of their own uploads. A buyer pays once and gets access to the full-quality original on every device where they sign in, while the wall remains available. The creator gets 70% of the price, rounded down to whole coins. The remaining coins leave circulation. The thumbnail stays free for everyone.

This is the "Premium Creator Content" row in `docs/REVENUE.md`. The `unlockCreatorWall` callable handles purchases; a deletion trigger handles refunds. Prices change only through the `setWallPrice` callable. Clients cannot write `creatorPrice`, the unlock markers, the sales totals or the caps.

## The model

| Thing | Where | Written by |
|---|---|---|
| Price | `walls/{docId}.creatorPrice`: an integer coin price. Missing means free. | `setWallPrice` only |
| Price list | `economyConfig/current.creatorWalls.prices`, default `[20, 40, 75]` | Admins |
| Server switch | `economyConfig/current.flags.creatorWallsEnabled`, default `false` | Admins |
| App switch | Remote Config `creator_premium_walls_enabled`, default `false` | Admins |
| Unlock marker | `usersv2/{buyer}/creatorWallUnlocks/{wallDocId}`: `wallId`, `wallDocId`, `creatorUid`, `price`, `creatorShare`, `transactionId`, `unlockedAt`, the wall creation time (millis and nanoseconds), and `pendingRefundKey`. A refund replaces that key with `refundedAt`. | `unlockCreatorWall`, refund trigger |
| Buyer ledger | `coinTransactions/ctx_cwbuy_{buyer}_{requestId}`: `action: creatorWallUnlock`, `delta: -price` | `unlockCreatorWall` |
| Creator ledger | `coinTransactions/ctx_cwsale_{buyer}_{requestId}`: `action: creatorWallSale`, `delta: +creatorShare` | `unlockCreatorWall` |
| Sales totals | `creatorSales/{creator}`: `count`, `coins` (creator share), per ISO week (last 9) and per wall doc ID. Same shape as `creatorTips`. | `unlockCreatorWall`, refund trigger |
| Caps | `creatorWallSaleDaily/{key}`: buyer, pair and creator docs per UTC day | `unlockCreatorWall` |

UID parts in document IDs are escaped like tips: `encodeURIComponent`, and `_` becomes `%5F`.

The private R2 original stays out of Firestore. The app receives a signed URL valid for two minutes. Each new delivery request, including a receipt retry, checks the current wall, its protected asset and its moderation state. On a priced wall, only the owner or a buyer with an unrefunded marker for this exact wall document and creation time can get the URL. A previous free, Pro or pass receipt cannot unlock a newly priced wall. A delivery receipt issued to a buyer or owner can only be retried while that same access still applies.

## Who can sell

The creator rule is the tip receiver rule, with a stricter account check:

| Rule | Check |
|---|---|
| Account | Firebase Auth user with a verified email, a provider that is not anonymous, not disabled, 7 days old or more. A `usersv2` profile that is not deleted, and no closed `creatorDeletionState`. |
| Track record | 1 approved wall or more (`approvedWall`: `review == true`, `wallpaper_provider == prism`, `origin != studio`). |
| The wall | The caller owns it (`creatorUid`, or a verified email match when `creatorUid` is not set yet). |
| Original upload | Not Studio (`origin`, `byStudio`), not AI (`isAiGenerated`, `aiGenerationId`), not a remix (`remixOf`), not a live wall (`kind == live`), not a streak or Drop wall, provider `prism` (never Wallhaven or Pexels). |
| Protected | An approved wall needs a unique share ID, a ready manifest bound to its document path and creation time, and private upload provenance for the seller. The original and public thumbnail must both be owned uploads from the seller, with distinct bytes and valid registry records. The original cannot match the original or thumbnail of another ready wall at the time of pricing or purchase. A legacy GitHub upload cannot sell. |
| Not held | `heldForReview != true`. |

The upload screen saves the wall first, then calls `setWallPrice`. If the price write fails, the upload still exists without the requested price. The creator can retry in the metadata editor. A pending wall can carry a price, but it cannot sell until approval and verification of its protected original.

## Prices and split

| Rule | Value |
|---|---|
| Prices | One of `creatorWalls.prices`. Default `[20, 40, 75]`. A bad list falls back to the default. The list accepts 1 to 6 distinct integers from 10 to 1000. Prices of 716 or more cannot sell under the daily creator cap. |
| Remove a price | `setWallPrice` with `price: 0`. Buyers keep their unlocks. |
| Creator share | `floor(price * 70 / 100)`: 20 gives 14, 40 gives 28, 75 gives 52. The share is a code constant, not config. |
| Prism share | `price - creatorShare`: 6, 12, 23. These coins leave circulation. |
| Price at sale | The stored `creatorPrice`, if it is an integer from 10 to 1000. A list change does not reprice old walls. |
| Price changed | The client sends `expectedPrice`, the price the sheet showed. If the stored price differs, the result is `creator_wall_price_changed` with the new price, and no coins move. The buyer never pays a price they did not see. |

## What the buyer gets

| | Before unlock | After unlock |
|---|---|---|
| Tile and detail thumbnail | Yes | Yes |
| Public 2560 px web preview (`wallpaperPreview`) | No. Refused for priced walls. | No |
| Download, set, edit, desktop companion | No: `resolveOriginalAccess` returns `creator_locked` with the price | Yes, 0 coins, basis `creator` |

The creator gets their own priced wall at 0 coins (basis `owner`). Removing the price keeps existing buyers at 0 coins (basis `creator`); others follow the normal original-access rules.

## Pro and the premium pass

Pro, premium passes and grace downloads do not unlock a priced creator wall. The server checks the creator entitlement first. These buyers pay the displayed price and the creator receives the same share.

## Caps and abuse

| Rule | Value | Reason |
|---|---|---|
| Buyer account | Verified email, not anonymous, 7 days old or more, profile not deleted | The tips rule. New accounts get free coins (profile, first upload). Without the age gate, a creator could farm those through fresh alts. |
| Buyer daily cap | 10 unlocks a UTC day | Stops a runaway client or a stolen session from draining a balance. |
| Pair cap | 3 unlocks a UTC day from one buyer to one creator | Slows one alt moving coins into one creator. |
| Creator daily cap | 500 coins of creator share a UTC day | A price of 715 pays 500 coins and uses the full daily cap. A price of 716 pays 501, so it is refused even with no earlier sales that day. |
| Self-buy | Refused (`creator_wall_self`). The owner reads their wall free. | No reason to buy your own wall, and it would mint a fake sale. |
| Blocks | Refused when either user blocked the other (`creator_wall_blocked`) | Same as tips. |
| Double buy | The marker is read in the transaction. A second unlock of the same wall with a new `requestId` returns `already_unlocked` and moves no coins. | Two devices or two taps cannot charge twice. |
| Retry | The original `requestId` returns the stored result only if the wall creation time and the active, unrefunded purchase marker still match that receipt. | Idempotency, like tips. |

### Farming check

| Question | Verdict |
|---|---|
| Does an unlock mint coins? | No. The buyer's coins move. At least 30% is burned, so a ring of alts loses coins on every pass. |
| Can alts pool coins into one creator? | Only coins in the buyer's balance, less Prism's share, at most 3 unlocks per alt per creator a day, and at most 500 coins per creator a day. Each alt must also be verified and 7 days old. |
| Can a sale farm XP, quests, badges, ranks or milestones? | No. `unlockCreatorWall` never calls `grantXp`, and nothing reads `creatorWallSale` credits. |
| Can a sale farm the Creator fund? | No. See below. |
| Refunds | `creatorWallUnlock` is not in `REFUNDABLE_ACTIONS`, so `awardCoins` refuses a generic refund. |
| UTC day edge | The caps reset at 00:00 UTC. A burst across midnight can reach 2 times a cap, as with tips. |

## Refunds and moderation

An unlock delivers an entitlement, not a file. Download and set go through `resolveOriginalAccess` at 0 coins while the approved wall remains available, so a failed download is never a reason to refund. The generic refund path refuses `creatorWallUnlock`.

| Case | Result |
|---|---|
| Wall held for review (`heldForReview`) | It cannot sell. New requests for the original are refused, including requests from buyers. Re-approved: buyers get it back. |
| Wall removed (the wall document is deleted, for example by an admin rejection) | **Active buyers are refunded in full.** |
| Price removed or changed | Buyers keep their unlocks. |

Holding or removing a wall stops new grants. It cannot recall a signed URL already issued or erase a file someone already saved.

`onCreatorWallDeleted` runs on every wall deletion, including after a creator removed the price. It derives `pendingRefundKey` from the deleted document path and creation time and reads matching unlocks in pages of 100. Reusing the same wall ID does not carry an unlock or refund over to the replacement.

Each refund transaction checks the key and creation time again, credits the active buyer the full price, and uses `creatorWallSaleReversal` to recover at most the available creator balance. It removes the sale from existing totals, including the wall and retained sale week, then replaces the pending key with `refundedAt`. Retries skip completed refunds. Prism covers any shortfall; daily caps do not rewind. A deleted buyer is not credited and the creator keeps that sale.

## Creator fund

**A purchase is not a fund event.** The fund pays from a weekly pool by engagement (saves, sets, downloads, remixes, folder adds). A sale already pays the creator directly. Counting it again would pay twice, and alts could buy walls to pull money from the pool. A buyer's later download or set is a normal engagement event, the same as for any wall, so the fund math does not change.

## Account deletion

| Who | Result |
|---|---|
| Buyer | `deleteAccount` already deletes the user's subcollections; it now also deletes `creatorWallUnlocks`. The ledger rows go with the account, as today. The creator keeps the coins and the sale in their totals. |
| Creator | Their walls stay, as "Deleted Account", because `deleteAccount` keeps walls. Buyers keep access. New unlocks are refused (`creator_wall_unavailable`). `creatorSales/{uid}` and the creator's cap docs are deleted. |

## Failure cases

| Case | Result | Coins moved |
|---|---|---|
| Not signed in | `unauthenticated` | No |
| Bad `wallId`, `expectedPrice` or `requestId` | `invalid-argument` | No |
| Server switch off | `creator_wall_disabled` | No |
| Buyer is the creator | `creator_wall_self` | No |
| Guest, anonymous or unverified buyer | `creator_wall_buyer_ineligible` | No |
| Buyer younger than 7 days | `creator_wall_buyer_too_new` | No |
| Wall missing, unpriced, held, not approved, not protected or not an original | `creator_wall_unavailable` | No |
| Creator deleted, disabled or missing | `creator_wall_unavailable` | No |
| A block in either direction | `creator_wall_blocked` | No |
| Price differs from `expectedPrice` | `creator_wall_price_changed`, with `price` | No |
| Already unlocked | `success: true`, `reason: already_unlocked` | No |
| Buyer cap, pair cap or creator cap | `creator_wall_daily_limit`, `creator_wall_pair_limit`, `creator_wall_creator_limit` | No |
| Balance below the price | `creator_wall_insufficient_balance`, `insufficientBalance: true` | No |
| Retry of the same active purchase on the same wall | The stored result | No (already charged) |
| Retry after refund, wall deletion or replacement | `creator_wall_unavailable` | No |
| Reuse the request ID for another wall document | `already-exists` | No |

## Rules, indexes and deploy order

- Clients, including configured admin clients, cannot write `creatorPrice` or change the priced wall's original or thumbnail identity. Server code sets the price.
- Buyers can read their own `creatorWallUnlocks` markers. Configured admin clients cannot read another buyer's markers. Clients cannot write markers or read or write `creatorSales` or `creatorWallSaleDaily`.
- The refund query needs the ascending collection-group index on `creatorWallUnlocks.pendingRefundKey`.

An earlier branch wrote unlock markers without the wall creation time or `pendingRefundKey`. The current delivery check cannot grant access from those markers, and the deletion trigger cannot find them for refunds. If that build was ever enabled with real wallets, inventory those purchases and reconcile their entitlements and refund records before rollout. No migration has been performed.

Keep both flags off during rollout:

1. Deploy the rules and index. Wait for the collection-group index to be ready before enabling refunds or sales.
2. Deploy the purchase, delivery, refund, eligibility, public catalog, preview, creator stats and account deletion functions together.
3. Resolve the Cloudflare Worker preview cache before enabling sales. The Firebase preview origin refuses priced walls and sends `no-store`, but the Worker can serve a cached phone rendition from when the wall was free. Its desktop-image and download routes already bypass this cache. Update that cache path to enforce current eligibility and invalidate previously cached renditions. The Worker change is outside this feature.
4. Release the app and allow time for adoption. Older clients cannot show the unlock flow.
5. Enable `economyConfig/current.flags.creatorWallsEnabled`, then Remote Config `creator_premium_walls_enabled`.
