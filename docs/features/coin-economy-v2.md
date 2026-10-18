# Coin economy v2

Status: implementation spec, 2026-10-17. Owner decision: full scope, option A (Pro pays half, never zero).
Revision 2 after two independent design reviews (GPT 6.1 Sol, Claude Opus 5.5).

## Why

Free users earn about 15 coins a day from the streak and a download costs 5, so nobody needs an ad.
Pro users bypass every spend except AI and freezes, yet earn 50 coins a day. Balances pile up with nothing to buy.
Coins are a currency with no store, no status, no scarcity and no daily loop.

## Model

One currency. Coins stay the engagement currency. Pro stays the convenience and status subscription.
XP is separate from coins: XP is never spent, so progress is stable. Coins are spent, so they must feel scarce.

```text
earn  ──▶ coins ──▶ spend (sinks)        earn ──▶ xp ──▶ rank (status, never spent)
streak      │        downloads, AI, drops, shop,       quests, streak, ads, badges
quests      │        boosts, gifts, passes, draw
ads         │
referral    │
badges      ▼
         balance (target median < 200)
```

## Server config

Every price, award and flag lives in one Firestore doc, `economyConfig/current`. Functions read it with a 60 s cache and
fall back to `DEFAULT_ECONOMY` in `functions/src/economy.ts`. `parseEconomy` validates: prices are bounded non-negative
integers, `aiGeneration`, `dropWall` and `dropPack` can never be in the bypass set, ranks are sorted, the spin table and
the streak table have the right shape. The client reads the same doc once at startup and again when the Rewards tab
opens if the copy is older than an hour; it falls back to the same defaults in `lib/core/coins/economy_config.dart`.
`CoinPolicy` keeps its names but reads the loaded config, so every existing call site shows the live number.

Shape (defaults):

```jsonc
{
  "version": 2,
  "spend": {
    "wallpaperDownload": 10, "premiumWallpaperDownload": 25, "liveWallpaperStyle": 20,
    "premiumFilter": 5, "premiumPreview24h": 10, "autoRotatePass7d": 50,
    "streakFreeze": 50, "streakRescue": 100,
    "aiFast": 10, "aiBalanced": 75, "aiQuality": 100,
    "dropWall": 30, "dropPack": 150, "boostWall": 100, "giftPremiumPass": 20, "drawTicket": 20,
    "spinWheel": 10
  },
  "proDiscountActions": ["aiGeneration", "dropWall", "dropPack"],   // Pro pays ceil(price / 2)
  "proBypassActions": ["wallpaperDownload", "premiumWallpaperDownload", "liveWallpaperStyle", "premiumFilter", "premiumPreview24h", "autoRotatePass7d"],
  "award": {
    "rewardedAd": 10, "rewardedAdFirstOfDay": 20, "rewardedAdMaxPerDay": 20,
    "firstWallpaperUpload": 50, "profileCompletion": 25,
    "referral": 100, "referralMaxPerDay": 3, "referralMaxLifetime": 20,
    "streakDaily": [3, 3, 5, 5, 8, 8, 10], "streakChestMin": 15, "streakChestMax": 40,
    "proStreakMultiplier": 1.5,
    "proSpin": [{"coins": 20, "weight": 40}, {"coins": 30, "weight": 25}, {"coins": 50, "weight": 20}, {"coins": 75, "weight": 10}, {"coins": 100, "weight": 5}],   // legacy, 3.6.0 and older only
    "spinWheelMaxPerDay": 5,
    "spinWheel": [
      {"kind": "coins", "coins": 10, "weight": 18}, {"kind": "coins", "coins": 1, "weight": 22},
      {"kind": "coins", "coins": 5, "weight": 30}, {"kind": "coins", "coins": 100, "weight": 1},
      {"kind": "coins", "coins": 20, "weight": 8}, {"kind": "coins", "coins": 2, "weight": 12},
      {"kind": "coins", "coins": 50, "weight": 3}, {"kind": "cosmetic", "fallbackCoins": 50, "weight": 6}
    ],
    "questCoins": 2, "questXp": 25, "questChestMin": 5, "questChestMax": 20, "questChestCosmeticChance": 0.1,
    "weeklyQuestCoins": 50, "weeklyQuestXp": 150,
    "graceDownloads": 3
  },
  "xp": { "perCoinEarned": 1, "ranks": [{"id": "bronze", "min": 0}, {"id": "silver", "min": 500}, {"id": "gold", "min": 2000}, {"id": "prism", "min": 6000}] },
  "flags": { "drawEnabled": false, "foundersUntil": "2026-11-30T00:00:00Z", "dropsEnabled": true },
  "shopPrices": {}
}
```

Rules: `economyConfig/{doc}` is readable by anyone signed in, write false. Admins change it with
`npm run economy:config -- --set spend.wallpaperDownload=10 --apply`.

`award.spinWheel` is the wheel table, in wheel order. A segment is `coins` (1..1000 coins) or
`cosmetic` (`fallbackCoins` 1..1000, paid when the user owns every common item). Each has a `weight` of 0..1000. The
table needs 2 to 12 segments and a positive weight sum. If any part is wrong, including a legacy `xp` segment,
the server and client use the whole default coin-only table.
The rules, the odds and the UI are in `docs/features/spin-wheel.md`.

### Pricing version and old clients

Old clients show the old prices and cannot confirm new ones, so the server must not charge them more than they see.
`spendCoins` reads `pricingVersion` from the request. Absent or below 2 means a legacy client: it pays the legacy prices
(download 5, premium wall 15, filter 5, preview 10) and gets no grace downloads. `pricingVersion: 2` (sent by every v2
client call) pays the config prices. Awards, the streak and the referral need no version: old clients render the amount
the server returns. The legacy `proDailyBonus` award keeps working and shares its daily receipt with the Pro spin.

## Before and after

| | Today | v2 |
|---|---|---|
| Streak cycle | 5,5,8,8,12,12,15 + 40 | 3,3,5,5,8,8,10 + chest 15..40 |
| Pro streak | +5 a day, +20 day 7 | 1.5x on the day's coins, chest included |
| Pro daily | flat 50 | One free wheel spin a day: 7.86 direct coins on average, or a cosmetic (10.86 when all common cosmetics are owned); no XP. 3.6.0 and older keep the Pro spin, 20..100, mean 38. |
| Download | 5 | 10, first 3 ever free (grace) |
| Premium wall | 15 | 25 |
| Live wallpaper paid style | Pro only | 20 per apply, Pro free |
| Auto-rotate | Pro only | 7-day pass for 50, Pro free |
| AI | 10 / 75 / 100, Pro pays full | same, Pro pays half |
| Rewarded ad | 10 | first of the day 20, then 10, cap 20 a day |
| Referral | 100, 10 a day, 100 lifetime | 100, 3 a day, 20 lifetime |
| Sinks for Pro | AI, freeze | AI half, drops half, shop, boosts, gifts, draw |
| Status | badges | badges + XP + ranks + weekly leaderboard |

Cohort budget, free user who does everything every day: streak 42 + chest about 27, quests 42, quest chests about 87,
one ad 140, weekly quest 50. About 390 coins a week. Two downloads a day spend 140. The rest is meant for a Drop pack
every two weeks (150), a cosmetic a month (100 to 300) and AI. The config is the tuning knob; the metrics section says
what to watch.

## Firestore

### `usersv2/{uid}` root fields (readable by any signed-in user; social only)

```text
xp: int                                  lifetime XP, never decreases
xpWeek: {weekKey: 'YYYY-Www', xp: int}   resets when weekKey changes
cosmetics: {frame?: itemId, nameGlow?: itemId}   equipped, shown on profiles and leaderboards
coinState.proSpinDate: 'YYYY-MM-DD'      shared with the legacy proDailyBonus action (which also honours proDailyBonusDate)
```

### `usersv2/{uid}/private/economy` (owner read, write false, server-written)

```text
rev: int                                 monotonic, bumped on every write; clients ignore older replies
quests: {dayKey, items: [{id, event, target, progress, claimed}], bonus: {id, event, target, progress, claimed},
         chestOpened, chestDoubled, weekKey, weekly: {id, event, target, progress, claimed}}
inventory: {owned: {itemId: purchasedAtMs}}
drops: {unlocked: {wallId: {weekKey, url}}}
passes: {premiumPassUntil: ms, autoRotatePassUntil: ms}
graceDownloadsUsed: int
```

The create rule for `usersv2` must refuse `xp`, `xpWeek`, `cosmetics`, `quests`, `inventory`, `drops` on the root
doc. `ownerCoinStateOk` drops `premiumPreviewUnlocks` (server owns it).

### New collections

| Collection | Doc | Read | Write |
|---|---|---|---|
| `economyConfig` | `current` | signed in | false |
| `drops` | `{weekKey}` `{weekKey, title, startsAt, endsAt, priceWall, pricePack, count, walls: [{id, title, thumb, resolution, by, seriesId}]}` (no full url) | signed in | false |
| `boosts` | `{wallId}` `{wallId, uid, startsAt, endsAt}` | signed in | false |
| `draws` | `{weekKey}` `{weekKey, status: open|settled, closesAt, tickets, participants, prize: {proMonths, itemId}, winnerUid?, winnerName?, settledAt?, prizeItemGranted?, prizeProGranted?, prizeGrantError?}` | signed in | false |
| `drawTickets` | `{weekKey}_{uid}` `{weekKey, uid, count}` | owner | false |
| `leaderboards` | `{weekKey}` and `current` `{weekKey, updatedAt, entries: [{uid, name, username, photo, xp, rank, frame?}]}` | signed in | false |
| `questEventRate` | `{uid}_{dayKey}_{event}` `{count, expireAt}` | none | false |
| `giftRateDaily` | `{uid}_{day}` `{day, count}` | none | false |

Indexes: `usersv2 (xpWeek.weekKey asc, xpWeek.xp desc)`, `walls (dropReserved asc, review asc, createdAt asc)`,
`boosts (endsAt asc, startsAt desc)`. TTL override on `questEventRate.expireAt`.

### `walls` new fields

`dropReserved: bool` (admin sets it from the review queue), `dropWeek: weekKey` (planner sets it), `boostedUntil: ms`.
Owners may not write any of the three; the rules refuse them for non-admins on create and update.

## Callables

All in region `asia-south1`, `cors: true`. Every money-like input is validated. Every purchase is one transaction that
reads every doc it needs before its first write. Every purchase takes a `requestId` (`^[A-Za-z0-9_-]{8,64}$`) and uses
a fixed transaction doc id with a callable-specific prefix so a replay returns the stored result (store the result
fields on the tx doc). Response base shape is the existing one: `{success, changed, previousBalance, currentBalance,
delta, reason, transactionId}` plus action fields. XP: every callable sums the XP it grants and calls `grantXp` once
per user per transaction. Activity XP uses fixed configured amounts independent of coin rewards. Ads, referrals,
refunds, purchases, the legacy Pro bonus and paid/free spins grant none. `perCoinEarned` remains readable only for
compatibility. See `docs/features/xp-and-creator-milestones.md` for the current XP policy.

### Changed

- `awardCoins`
  - `rewardedAd`: amount is `rewardedAdFirstOfDay` when today's count is 0, else `rewardedAd`. Reply adds `adsRemaining`
    and `delta` carries the real amount.
  - `proDailyBonus`: legacy clients only. Refused when either `coinState.proSpinDate` or `coinState.proDailyBonusDate`
    is today; pays the lowest spin value; writes both dates.
- `spendCoins`
  - prices from config, legacy prices without `pricingVersion: 2` (see above).
  - new actions `liveWallpaperStyle` (a paid motion or gradient style, per apply) and `autoRotatePass7d` (writes
    `passes.autoRotatePassUntil = max(now, current) + 7d`; auto-rotate is Pro-only today, the pass opens it for 7 days).
  - Pro bypass set from config (still needs `allowPremiumBypass: true` from the client).
  - `aiGeneration`: v2 clients send `qualityTier` (`fast|balanced|quality`), never an amount; the server picks the config
    price and charges `proPrice` for Pro. Legacy clients send `amount` in {10, 75, 100}, mapped to a tier. The tx doc
    records `qualityTier` and `basePrice`. The AI worker's charge check accepts `-delta` equal to the tier price or its
    Pro half (`infra/cloudflare/worker/src/ai.ts`, deploy with the functions).
  - grace: `wallpaperDownload` and `premiumWallpaperDownload` with `pricingVersion: 2`, while
    `graceDownloadsUsed < graceDownloads`: no charge, increment, reply `bypassed: true, reason: 'grace_download',
    graceDownloadsLeft`.
  - premium pass: `premiumWallpaperDownload` and `premiumPreview24h` bypass while `passes.premiumPassUntil > now`.
- `unlockPremiumPreview`: price from config, premium-pass bypass.
- `claimDailyStreak`: daily table from config, day 7 pays `daily + chest` with the chest in
  `[streakChestMin, streakChestMax]`; Pro total is `ceil((daily + chest) × proStreakMultiplier)`; `proBonusReward` keeps
  carrying the Pro extra so old clients still render. Reply adds `isChest: true` on day 7.
- `processReferral`: caps and reward from config.
- `deleteAccount`: also deletes `private/economy`, the user's `drawTickets`, and `boosts` the user bought; leaderboard
  snapshots skip `deleted` users.

### New

| Callable | Input | Effect | Reply extras |
|---|---|---|---|
| `claimProSpin` | `{requestId}` | legacy, for 3.6.0 and older (newer clients use `spinWheel`). Premium only, once per UTC day (refused when `proSpinDate` or `proDailyBonusDate` is today), weighted pick from `proSpin`, writes both dates | `{coins, segment}` |
| `spinWheel` | `{requestId, maxCost, sourceTag}` | everyone can spin. Pro members get one free spin per UTC day; it shares its receipt with `claimProSpin` and `proDailyBonus`. A paid spin costs `spend.spinWheel`, at most `spinWheelMaxPerDay` a day. Refused with `spin_wheel_price_changed` when the cost is above `maxCost`, `spin_wheel_daily_limit` at the cap, `spin_wheel_insufficient_balance` when short. Otherwise grants coins or an unowned common cosmetic (fallback coins when all are owned), never XP. Ledger doc `ctx_spinWheel_{uid}_{requestId}` retains the original outcome; replay refreshes live balances, status, absolute XP, revision and inventory without another award. See `docs/features/spin-wheel.md` | Every reply includes `{status: {freeSpinAvailable, paidSpinsLeft, price}, xpPolicyVersion, xp, xpWeek, xpAwarded: 0, rev, owned}`; a win adds `{cost, free, segment, prize: {kind, coins, xp: 0, itemId}, segments}`. Historical replays can retain an old XP prize. |
| `progressQuest` | `{event?, eventId?, requestId?}` | rebuilds `quests` for today if stale (daily items reset on `dayKey`, weekly on `weekKey`; the day's assignment is persisted and never reshuffled), bumps progress on every daily, bonus and weekly item with that event, grants coins + XP when an item reaches its target. `event` omitted = sync only. `questEventRate` caps an event at 2 × its largest target per day. Bumps `rev`. | `{quests, awarded: [{id, coins, xp}]}` |
| `openQuestChest` | `{requestId}` | needs the three daily items claimed and `!chestOpened`; coins in `[questChestMin, questChestMax]`, doubled when the bonus item is claimed; 10 % chance of a random unowned `common` cosmetic; tx id `ctx_questChest_{uid}_{dayKey}` | `{coins, doubled, itemId?}` |
| `purchaseShopItem` | `{itemId, requestId}` | catalog price (config can override by id), checks `proOnly`, `minRank`, `founders` window, not owned; writes `inventory.owned` | `{itemId, owned}` |
| `equipCosmetic` | `{slot: 'frame'|'nameGlow', itemId: string|null}` | item must be owned and of that kind; a `proOnly` item needs current premium to equip; writes root `cosmetics.{slot}` | `{cosmetics}` |
| `unlockDrop` | `{weekKey, wallId?, requestId}` | drop must be live; `wallId` null means the pack; pack price is `min(pricePack, remaining × priceWall)`, zero remaining means nothing to buy; Pro half after that; writes `drops.unlocked.{wallId} = {weekKey, url}` with the url read from the wall doc | `{unlocked: [{id, url}]}` |
| `boostWall` | `{wallId, requestId}` | wall `review == true`, `email == caller`, not studio, no active boost, fewer than 10 active boosts (`boost_slots_full`); writes `boosts/{wallId}`, `walls.boostedUntil`, and prepends the id to `trending/current.wallIds` in the same transaction so the boost is live at once | `{endsAt}` |
| `giftPremiumPass` | `{recipientUid, requestId}` | not self, recipient exists and not deleted, sender under 10 gifts a day; recipient `passes.premiumPassUntil = max(now, current) + 24h`; after commit, one in-app notification with a deterministic doc id | `{expiresAt}` |
| `buyDrawTicket` | `{requestId}` | `flags.drawEnabled`, draw `status == open` and `now < closesAt`, max 5 tickets per user per week (enforced on the ticket doc) | `{tickets, closesAt}` |

### Scheduled

| Function | Schedule (UTC) | Work |
|---|---|---|
| `planWeeklyDrop` | Monday 00:30 | if `drops/{weekKey}` exists, return; take up to 10 `walls` with `dropReserved == true`, `review == false`, `origin == 'studio'`, oldest first; need at least 4 or skip; one batch writes the drop doc with inline snapshots (thumb only, no full url) and sets `dropWeek`, clears `dropReserved` |
| `settleDraw` | Monday 00:10 | settle last week: transaction sets `status: settled`, `winnerUid`, `settledAt` once; then grant steps each flip their own flag (`prizeItemGranted`, `prizeProGranted` through a RevenueCat promotional entitlement); a later run retries missing flags; notify the winner once |
| `snapshotLeaderboard` | every 3 h | top 50 `usersv2` by `xpWeek.xp` for the current week, skip deleted → `leaderboards/{weekKey}` and `leaderboards/current` |
| `computeTrending` (changed) | existing | keep active boost ids (up to 10, newest first) at the front of `trending/current.wallIds` |

### XP

`grantXp(userData, xp, nowMs)` in `functions/src/economy.ts` returns the `{xp, xpWeek}` fields to merge into the one
user update. Rank is derived with `rankFor(xp, config)` on both sides and never stored.

## Quests

Pool (id → event × target, title):

| id | event | target | title |
|---|---|---|---|
| `set_wall` | `set_wallpaper` | 1 | Set a wallpaper |
| `fav_3` | `favourite` | 3 | Favourite 3 walls |
| `wotd_view` | `view_wotd` | 1 | Open today's Wall of the Day |
| `colour_search` | `colour_search` | 1 | Search by colour |
| `trending_view` | `view_trending` | 1 | See what's trending |
| `share_wall` | `share` | 1 | Share a wallpaper |
| `download_2` | `download` | 2 | Download 2 walls |
| `browse_10` | `view_wallpaper` | 10 | Look at 10 walls |

Bonus item (not required for the chest, doubles it): `watch_ad` (`watch_ad` × 1, Watch a video) for free users,
`pro_spin` (`pro_spin` × 1, Open your Pro spin) for Pro. Daily set: three items from the pool, `seededPick(dayKey, 3)`,
the same for everyone, UTC days. Weekly: `set_wall` × 5, ISO week, `weeklyQuestCoins` / `weeklyQuestXp`. Each daily
item pays `questCoins` + `questXp`. The bonus item pays nothing by itself.

Ad and spin progress is granted by the server inside the ad credit and the spin, not by a client event. The client
reports the other events with `progressQuest({event, eventId})` from: set wallpaper success, favourite added, Wall of
the Day opened, colour search run, Trending opened, share completed, download success, wallpaper detail opened. Calls
are fire-and-forget with a 10 s timeout; a reply with a lower `rev` than the current state is ignored.

## Shop catalog

`functions/src/shopCatalog.ts` and `lib/features/shop/domain/shop_catalog.dart` carry the same list. Kinds: `theme`,
`appIcon`, `frame`, `nameGlow`. Themes and icons are device settings, so ownership is enough. Frames and name glows are
shown on the public profile, so they have an `equipped` slot in root `cosmetics`. `common` marks chest-eligible items.

| id | kind | price | notes |
|---|---|---|---|
| `theme_rose`, `theme_cotton_blue`, `theme_olive`, `theme_deep_ocean`, `theme_jungle`, `theme_pepper`, `theme_sky`, `theme_steel` | theme | 150 | Frost White, Coffee, Material Dark and AMOLED stay free. A theme already selected stays selected; locking applies to switching to it. common |
| `icon_noir`, `icon_glass`, `icon_sunset`, `icon_mono` | appIcon | 200 | iOS alternate icons and Android activity aliases |
| `frame_ring` | frame | 120 | accent ring, common |
| `frame_aurora` | frame | 200 | gradient ring |
| `frame_prism` | frame | 300 | rainbow ring, `proOnly` (ownership survives a lapse, equipping does not) |
| `frame_gold` | frame | 250 | `minRank: gold` |
| `frame_founders` | frame | 1000 | `founders`, sold until `flags.foundersUntil` |
| `glow_ember`, `glow_ocean` | nameGlow | 100 | common |
| `glow_aurora` | nameGlow | 200 | `minRank: silver` |
| `glow_founders` | nameGlow | 1000 | `founders` |

Glint skins are out: the mascot keeps the logo colours on every theme (`.impeccable.md`). Name glows replace them.

## Client

### Core (`lib/core/coins/`)

- `EconomyConfig` entity + loader (startup, `economyConfig/current`, defaults mirror the server).
- `CoinPolicy` getters read `EconomyConfig.current`.
- `CoinSpendAction` adds `liveWallpaperStyle`, `autoRotatePass7d`, `dropWall`, `dropPack`, `boostWall`,
  `giftPremiumPass`, `drawTicket`, `shopItem`. `CoinEarnAction` adds `proSpin`, `quest`, `questChest`, `streakChest`.
  `coin_transaction_label.dart` gets labels for each.
- `CoinsService` sends `pricingVersion: 2` on every spend, sends `qualityTier` for AI, logs the server `delta` in
  analytics, and exposes typed wrappers for every new callable plus notifiers for XP, quests, inventory, unlocked drops
  and passes (read from `private/economy`).
- `CoinGate`: the premium shortcut applies only to actions in the bypass set; new sinks call their own service method.
  When the balance is short the sheet offers "Watch a video" with the real amount (`+20` for the first of the day).
- Pass checks: premium collections and premium walls open while the premium pass is active; auto-rotate runs while the
  auto-rotate pass is active. Pass holders get no spin and no discount.

### Rewards page order

1. Hero: streak, rank chip, XP bar to next rank.
2. Today card: three quests with progress, bonus row, chest state, weekly quest row.
3. Pro spin card (Pro) or one quiet line for free users.
4. Weekly Drop card: cover, countdown, price, Pro price.
5. Freeze card, Balance card (existing).
6. Use your coins grid: AI, Drops, Shop, Premium collection, Boost, Gift, Streak freeze, Downloads.
7. Earn coins list (updated amounts, first ad of the day).
8. Leaderboard row, Draw card (flag), Badges, Streak collection, Activity.

### New features (canonical layout)

| Feature | Pages | Notes |
|---|---|---|
| `quests` | none, widgets only | bloc + repo, Today card, chest sheet |
| `shop` | `/shop` | catalog grid by kind, item sheet (price, watch ad shortcut), owned and equipped states; theme lock in theme picker; app icon switch through a Pigeon host API; frame + name glow rendering on profile pages |
| `drops` | `/drops`, `/drops/:weekKey` | live drop grid with blurred thumbs, unlock one or all, vault of past unlocks (urls from the private doc), card for Rewards and Home; admin review gets a "Reserve for Drop" action |
| `leaderboard` | `/leaderboard` | Friends (followed users' root docs, sorted by weekly XP then uid) and Global (`leaderboards/current`) |
| `draw` | `/draw` | tickets, pot, closes-in, last winner; hidden when `drawEnabled` is false |
| boosts | in `wallpaper_detail`, `trending` and the home carousel | Boost button for the owner of an approved wall; boosted walls show in the home carousel on the For you tab (after the Wall of the Day) and lead the Trending tab, with a "Boosted" tag; see [trending.md](trending.md) |
| gifts | in `public_profile` | "Gift a 24 h pass" button |

### Analytics

New events: `pro_spin_claimed`, `quest_progressed`, `quest_completed`, `quest_chest_opened`, `shop_item_purchased`,
`cosmetic_equipped`, `drop_viewed`, `drop_unlocked`, `boost_purchased`, `gift_sent`, `draw_ticket_bought`,
`leaderboard_viewed`, `rank_up`. Coin events log the server delta, not the requested amount.

## Rollout

1. Deploy indexes, rules, functions, the AI worker, then `npm run economy:config -- --init --apply`.
2. Release the client. Old clients keep working at legacy prices until they update.
3. Flip `flags.drawEnabled` only after legal and store review of the mechanism (Apple 5.3.2 official rules, Google
   Play contests policy). It ships dark.

Deferred: coin packs as RevenueCat consumables. They need store products and a RevenueCat webhook before any code is
useful, and a review of earned versus purchased balance rules.

## Metrics

Spent / earned between 0.7 and 0.9, computed from the server ledger with refunds netted out. Median balance under 200.
Rewarded ads per DAU. D7 and D30 retention. Pro conversions from Draw winners and gift passes. Quest completion rate.
Chest open rate and doubled share.

## Revision 3 deltas (after the Opus review; these override the sections above)

- **Quest events the server already sees are counted on the server.** `recordWallpaperAction` (`download`, `set`, `share`, only when the action counted), `onFavouriteWritten` (favourite added), `recordWallpaperView` (`view_wallpaper`) call `progressQuestForUser(uid, event)` from `functions/src/quests.ts`. The `progressQuest` callable accepts only `view_wotd`, `colour_search`, `view_trending` from the client (and sync). The `set_wall` quest counts `set` or `download` ("Set or save a wallpaper"); the weekly quest is "Save or set 5 walls".
- **Numbers.** `questChestMin 5`, `questChestMax 15`, `weeklyQuestCoins 30`. Gift pass costs 50. Ads, referrals and spins grant coins or their configured cosmetic prizes without XP. The leaderboard skips accounts younger than 7 days.
- **Legacy pricing window.** `pricingVersion` below 2 gets legacy prices only while `flags.legacyPricingUntil` (default `2027-01-31T00:00:00Z`) is in the future. After that everyone pays v2.
- **Pass and grace bypass never need `allowPremiumBypass`.** Grace applies to `wallpaperDownload` only. `unlockPremiumPreview` also honours the premium pass.
- **`coinState.adsToday {day, count}`** is written by the ad credit so the client can label the first ad of the day correctly.
- **Gift limits.** Recipient at most one gift a day and never extended past `now + 24h`; recipient must not be premium; sender account at least 7 days old, at most 3 gifts a day; refuse when the recipient blocked the sender.
- **Draw.** Premium users cannot buy tickets (`draw_pro_not_eligible`). `buyDrawTicket` creates the week's draw doc in its own transaction when missing. Settlement counts tickets from the ticket docs; the counters on the draw doc are display only.
- **Boosts.** `boost_slots_full` replies carry `nextFreeAt`.
- **Drops.** Walls from drops older than 30 days after `endsAt` are released to the public feed by the planner (`review: true`). The admin review queue hides walls with `dropWeek`.
- **Live wallpaper.** `liveWallpaperStyle` is a 7-day unlock of one paid style: input `styleId`, writes `passes.liveStyles.{styleId} = until`. Live wallpaper and auto-rotate tiles are hidden on iOS.
- **Config.** `economyConfig` is readable by everyone (guests see prices). `parseEconomy` bounds: spend and shop prices integers 0..10000, awards 0..1000, chest min ≤ max, spin weights with a positive sum. The client refreshes the config on resume when older than an hour.
- **Keep `premiumPreviewUnlocks` in the owner allow list** until clients below 3.4.1 are gone.
- **Themes.** Themes selected before the upgrade are grandfathered on that device: the client stores the selected light and dark ids under a local "legacy themes" key on first run of v2 and treats them as owned. Guests are locked only when switching.
- **Cosmetics.** Catalog ids are never deleted, only `retired`. A `proOnly` frame renders only while the profile is premium.
- **UI.** The Drop card lives on Rewards only, no Home card. Earn coins sits above Use your coins. "Watch a video" appears only when the balance is short. Spin and chest sheets use a coin animation, not Glint; Celebrate is for rank-up and streak milestones only. Spin and chest sheets show their odds.
- **Day boundaries.** Quests, spin and ads use UTC days; the streak keeps its locked local day. Documented, accepted.

## As built (2026-10-17)

Differences from the text above that the code settled:

- Drop prices are snapshotted on the drop doc at planning time and `unlockDrop` charges those, so a mid-week config change never changes a live drop.
- The day 7 chest is its own ledger action, `streakChest` (reason `streak_day_7_chest`).
- Every free spend outcome (grace, pass, premium bypass) with a `requestId` writes a zero-delta receipt so a replay cannot burn a second grace download. The app hides zero-delta rows from the activity list.
- Quest events the server counts carry a dedupe id (`uid_wallId_day`, or the trigger event id for favourites), so a set and a download of one wall on one day count once.
- The client sends `pricingVersion: 2` and `qualityTier` for AI. The AI worker accepts the receipt's `basePrice` or its Pro half and requires the receipt tier to match.
- `economyConfig` is readable by guests. `premiumPreviewUnlocks` stays in the owner allow list until clients below 3.4.1 are gone.
- Android alternate icons: `MainActivity` keeps the launcher filter; each icon alias carries the launcher and deep-link filters; the widget opens the app through the package launch intent.
- The economy simulation test (`functions/src/__tests__/economySim.test.ts`) reports about 50 coins a day for an engaged free user with the defaults. The owner's "first ad pays 20" sets that floor; lower `rewardedAdFirstOfDay` or the quest chest to tighten.
- Deferred: coin packs; AdMob server-side verification; a device pass for app icon switching, the Shop, Drops, the Leaderboard and the Draw.
