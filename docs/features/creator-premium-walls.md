# Creator premium walls

A creator puts a coin price on one of their own uploads. A buyer pays once and gets the full-quality original, forever, on every device where they sign in. The creator gets 70% of the price. Prism keeps 30%. The thumbnail stays free for everyone.

This is the "Premium Creator Content" row in `docs/REVENUE.md`. Coins move only through the `unlockCreatorWall` callable. Prices change only through the `setWallPrice` callable. Clients cannot write `creatorPrice`, the unlock markers, the sales totals or the caps.

## The model

| Thing | Where | Written by |
|---|---|---|
| Price | `walls/{docId}.creatorPrice`: an integer coin price. Missing means free. | `setWallPrice` only |
| Price list | `economyConfig/current.creatorWalls.prices`, default `[20, 40, 75]` | Admins |
| Server switch | `economyConfig/current.flags.creatorWallsEnabled`, default `false` | Admins |
| App switch | Remote Config `creator_premium_walls_enabled`, default `false` | Admins |
| Unlock marker | `usersv2/{buyer}/creatorWallUnlocks/{wallDocId}`: `wallId`, `wallDocId`, `creatorUid`, `price`, `creatorShare`, `transactionId`, `unlockedAt`, and `refundedAt` after a refund | `unlockCreatorWall`, refund trigger |
| Buyer ledger | `coinTransactions/ctx_cwbuy_{buyer}_{requestId}`: `action: creatorWallUnlock`, `delta: -price` | `unlockCreatorWall` |
| Creator ledger | `coinTransactions/ctx_cwsale_{buyer}_{requestId}`: `action: creatorWallSale`, `delta: +creatorShare` | `unlockCreatorWall` |
| Sales totals | `creatorSales/{creator}`: `count`, `coins` (creator share), per ISO week (last 9) and per wall doc ID. Same shape as `creatorTips`. | `unlockCreatorWall` |
| Caps | `creatorWallSaleDaily/{key}`: buyer, pair and creator docs per UTC day | `unlockCreatorWall` |

UID parts in document IDs are escaped like tips: `encodeURIComponent`, and `_` becomes `%5F`.

The original is never written to Firestore for a buyer. Creator walls are protected originals in the private R2 bucket. After an unlock, `resolveOriginalAccess` reads the marker and signs a 2-minute URL each time the buyer downloads or sets the wall, at 0 coins. So "forever, on all devices" is the marker, not a stored URL. This is stronger than `unlockDrop`, which stores a full URL in the buyer's private doc.

## Who can sell

The creator rule is the tip receiver rule, with a stricter account check:

| Rule | Check |
|---|---|
| Account | Firebase Auth user with a verified email, a provider that is not anonymous, not disabled, 7 days old or more. A `usersv2` profile that is not deleted, and no closed `creatorDeletionState`. |
| Track record | 1 approved wall or more (`approvedWall`: `review == true`, `wallpaper_provider == prism`, `origin != studio`). |
| The wall | The caller owns it (`creatorUid`, or a verified email match when `creatorUid` is not set yet). |
| Original upload | Not Studio (`origin`, `byStudio`), not AI (`isAiGenerated`, `aiGenerationId`), not a remix (`remixOf`), not a live wall (`kind == live`), not a streak or Drop wall, provider `prism` (never Wallhaven or Pexels). |
| Protected | Approved walls: `originalProtected == true`, `wallpaper_url == ""`, and `ownedAssets/{id}` is `ready` with `provenance.kind == "owned"` from the same creator. Pending walls: `wallpaper_url == ""` (a private upload). Legacy GitHub uploads keep a public copy in the walls repo, so they cannot sell. |
| Not held | `heldForReview != true`. |

A price can go on an approved wall or on the creator's own pending upload, so the upload screen can set it. A pending wall sells only after approval, when the full check passes.

## Prices and split

| Rule | Value |
|---|---|
| Prices | One of `creatorWalls.prices`. Default `[20, 40, 75]`. A bad list falls back to the default. Each entry is an integer from 10 to 1000. |
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

The creator always gets their own walls at 0 coins (basis `owner`).

## Pro and the premium pass

**My pick: they do not unlock creator walls. Pro and pass users pay the full price.** A free unlock has nobody to pay the creator. In `resolveOriginalAccess` the creator check runs before the Pro and pass checks, so `premium: true` cannot reach the original of a locked wall.

**Decision for the owner (2 options):**

1. Pro pays full price (shipped). Simple, and the creator gets 70% of every unlock.
2. Pro gets a discount that comes out of Prism's 30% only. For example 20% off: a 75-coin wall costs Pro 60, the creator still gets 52, Prism keeps 8. This gives Pro a perk without cutting creator pay. It needs one more test and copy.

## Caps and abuse

| Rule | Value | Reason |
|---|---|---|
| Buyer account | Verified email, not anonymous, 7 days old or more, profile not deleted | The tips rule. New accounts get free coins (profile, first upload). Without the age gate, a creator could farm those through fresh alts. |
| Buyer daily cap | 10 unlocks a UTC day | Stops a runaway client or a stolen session from draining a balance. |
| Pair cap | 3 unlocks a UTC day from one buyer to one creator | Slows one alt moving coins into one creator. |
| Creator daily cap | 500 coins of creator share a UTC day | Bounds coin laundering. An unlock that would pass it is refused. |
| Self-buy | Refused (`creator_wall_self`). The owner reads their wall free. | No reason to buy your own wall, and it would mint a fake sale. |
| Blocks | Refused when either user blocked the other (`creator_wall_blocked`) | Same as tips. |
| Double buy | The marker is read in the transaction. A second unlock of the same wall, with any `requestId`, returns `already_unlocked` and moves no coins. | Two devices or two taps cannot charge twice. |
| Retry | The same `requestId` returns the stored result. | Idempotency, like tips. |

### Farming check

| Question | Verdict |
|---|---|
| Does an unlock mint coins? | No. The buyer's coins move. 30% is burned, so a ring of alts loses coins on every pass. |
| Can alts pool coins into one creator? | Only coins they earned, minus 30%, at most 3 unlocks per alt per creator a day, and at most 500 coins per creator a day. Each alt must also be verified and 7 days old. |
| Can a sale farm XP, quests, badges, ranks or milestones? | No. `unlockCreatorWall` never calls `grantXp`, and nothing reads `creatorWallSale` credits. |
| Can a sale farm the Creator fund? | No. See below. |
| Refunds | `creatorWallUnlock` is not in `REFUNDABLE_ACTIONS`, so `awardCoins` refuses a generic refund. |
| UTC day edge | The caps reset at 00:00 UTC. A burst across midnight can reach 2 times a cap, as with tips. |

## Refunds and moderation

An unlock delivers an entitlement, not a file. Download and set go through `resolveOriginalAccess` at 0 coins and can be retried forever, so a failed download is never a reason to refund. The generic refund path refuses `creatorWallUnlock`.

| Case | Result |
|---|---|
| Wall held for review (`heldForReview`) | It cannot sell. Nobody, buyers included, gets the original until an admin decides. Re-approved: buyers get it back. |
| Wall removed (the wall document is deleted, for example by an admin rejection) | **Buyers are refunded in full.** |
| Price removed or changed | Buyers keep their unlocks. |

**Why refund and not "stays readable":** a deleted wall's original is tombstoned in R2, so it cannot stay readable. And a takedown usually means the creator had no right to sell it (stolen art, policy). Keeping it readable would keep distributing it. A refund is the only promise we can keep.

The refund trigger (`onCreatorWallDeleted`) runs when a wall with a `creatorPrice` is deleted. For each unlock marker of that wall it runs one transaction: credit the buyer the full price (`creatorWallRefund`), take back the creator share up to the creator's balance (`creatorWallSaleReversal`, never below 0), and stamp `refundedAt` on the marker. A stamped marker is skipped, so a retried trigger never refunds twice. If the creator spent the coins, Prism covers the gap.

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
| Retry of a finished unlock | The stored result | No (already moved once) |

## Rules, indexes and deploy order

- `creatorPrice` joins `wallServerKeysAbsent` and `wallServerKeysUntouched`.
- `usersv2/{uid}/creatorWallUnlocks/{wallDocId}`: the owner reads, nobody writes.
- `creatorSales` and `creatorWallSaleDaily` have no client rule, so clients cannot read or write them.
- Index: a collection-group field override on `creatorWallUnlocks.wallDocId`, for the refund trigger.

Deploy order:

1. Functions: `setWallPrice`, `unlockCreatorWall`, `onCreatorWallDeleted` (new), `resolveOriginalAccess`, `wallpaperPreview`, `getCreatorStats`, `deleteAccount`.
2. Rules.
3. Indexes.
4. The app build. Wait for adoption: an app without this change shows a priced wall as a normal wall and fails at download.
5. Turn on `economyConfig/current.flags.creatorWallsEnabled`, then Remote Config `creator_premium_walls_enabled`.
