# Daily moment

The daily moment groups the streak receipt, daily chest, and available free Pro spin in one flow.
The Remote Config key is `daily_moment_v1`. Its local default is on in debug and off in release.
The old Rewards page and reward pages remain available when the flag is off.

## Reward contracts

These values are server defaults. `economyConfig/current` can override them. The UI displays confirmed server results.

| Reward | Trigger and callable | Default amount or odds | Limit | Existing screen |
| --- | --- | --- | --- | --- |
| Daily streak | App open; `claimDailyStreak(timezoneOffsetMinutes, reminderEnabled)` | Days 1 to 7 pay 3, 3, 5, 5, 8, 8, 10. Day 7 adds a uniform 15 to 40. Pro multiplies the total by 1.5 and rounds up. Each claim adds 5 XP. Day 7 adds 25 more XP. | Once per locked local day | Daily claim sheet and Rewards |
| Daily chest | Open; `openDailyChest(requestId, maxCost)` | 5 coins 34%, 8 coins 28%, 12 coins 15%, 20 coins 11%, cosmetic 8%, 40 coins 3%, 100 coins 1%. Cosmetic fallback is 25. Completed bonus doubles coins. Each chest adds 10 XP. | Once per UTC day. Free after three daily quests, otherwise 8 coins. | Daily chest |
| Wheel | Spin; `spinWheel(requestId, maxCost)` | 10 coins 18%, 1 coin 22%, 5 coins 30%, 100 coins 1%, 20 coins 8%, 2 coins 12%, 50 coins 3%, cosmetic 6%. Cosmetic fallback is 50. | One free Pro spin per UTC day, then up to five paid spins at 10 coins | Spin wheel |
| Daily quests | Accepted action; `progressQuest(event, eventId)` or the server action handler | Each required quest pays 2 coins and 25 XP. The bonus pays no coins itself. | Each of three quests once per UTC day | Rewards quests |
| Weekly quest | Five sets or saves; same quest pipeline | 30 coins and 150 XP | Once per ISO week, reset Monday UTC | Rewards quests |
| Rewarded video | Completed ad; `awardCoins(action: rewardedAd, sourceTag, requestId)` | First ad pays 20, later ads pay 10 | 20 per UTC day, minimum 20-second gap | Earn coins |
| First upload | Verified submission or qualifying community wall; `awardCoins(action: firstWallpaperUpload, sourceTag, reason)` | 50 coins and 50 XP | Once per account | Upload and Earn coins |
| Profile completion | Complete profile; `awardCoins(action: profileCompletion, sourceTag, reason)` | 25 coins and 25 XP | Once per account | Profile and Earn coins |
| Badge milestones | `checkBadges()` checks server evidence | Week Warrior 25 coins/25 XP; Streak Master 100/100; Creator (first approved wallpaper) 50/0; AI Artist 30/30; Prism Veteran 75/75. Collector, Art Curator, Social Butterfly, and Profile Complete pay no coins or XP. | Each badge once per account | Badge celebration, profile, and Rewards |
| Rank rewards | XP award transactions or `reconcileRankRewards(sourceTag)` | Silver at 500 XP grants Aurora glow; Gold at 2,000 grants Gold frame; Prism at 6,000 grants Prism glow. No coins. | Each item once per account | Rank card and shop |
| Referral | Accepted referral; `processReferral(inviterUserId)` | 100 coins for each account | Referee once; inviter three per day and 20 lifetime | Invite friends |
| Legacy Pro spin | `claimProSpin(requestId)` | 20 coins 40%, 30 coins 25%, 50 coins 20%, 75 coins 10%, 100 coins 5% | Shares the free Pro spin receipt | No current client caller |
| Legacy Pro daily bonus | `awardCoins(action: proDailyBonus, sourceTag, reason)` | Lowest legacy spin prize, default 20 | Shares the free Pro spin receipt | No current client caller |
| Legacy quest chest | `openQuestChest(requestId)` | Uniform 5 to 15 coins, bonus doubles coins, 10% cosmetic chance, and 10 XP | All three quests required. Shares the daily chest receipt. | No current client caller |
| Drops, shop, freeze | Existing purchase callables | Spend or unlock features. No new coin reward. | Existing ownership and purchase rules | Drops, shop, and Rewards |

Sources are `functions/src/economy.ts`, `streak.ts`, `quests.ts`, `coinsCallables.ts`, `questCatalog.ts`, `wallStats.ts`, `badges.ts`, and `rankRewards.ts`.

## Flow decision

The `gpt-6-astra` design review compared chained legacy pages with one shared sheet.
The shared sheet owns the step, primary button, dismissal, and continuation. This avoids separate navigation stacks for each reward.

The order is streak, chest, then an available free spin. Startup keeps its existing streak claim.
The sheet shows that claim's receipt. A manual entry can check the same claim callable when necessary.
The chest button states the price and passes the displayed price as `maxCost`.
The free spin passes `maxCost: 0`. Paid spins remain a separate explicit action.

The Pro spin can complete the chest bonus. Opening the chest first can therefore forgo that multiplier.
The flow preserves the requested order and never promises a doubled chest before the bonus is complete.

The presentation day is separate from reward eligibility. Streak eligibility uses the locked local day.
Chest, quests, and spin eligibility use UTC. Closing the sheet does not consume an unclaimed reward.
An account change clears the displayed receipt and stops that flow.
Automatic presentation waits until an active deep-link target is left.

| Old entry point | Flag on | Flag off |
| --- | --- | --- |
| Automatic daily claim sheet | One daily moment, subject to startup, purchase, and deep-link gates | Existing claim sheet |
| Rewards hero and balance card | One Today card with balance and remaining rewards | Existing cards |
| Chest banner and `/daily-chest` | Daily moment at the chest step | Existing chest page |
| Free spin and `/spin-wheel` | Daily moment at the spin step | Existing wheel page |
| Paid spin | Explicit wheel entry under More | Existing wheel entry |
| New `/daily-moment` link | Daily moment from the first available step | Rewards |
| Rank, creator progress, freeze, badges, collection, activity, and links | More group below Earn and Spend | Existing order |

## Action receipts

Set and save do not pay a fixed reward. They can complete daily or weekly quests.
`recordWallpaperAction` accepts an optional `requestId` and returns that action's quest awards.
The new response adds `questAwards`, `questCoins`, `questReceiptId`, and `questReceiptComplete`.
Calls without a request ID keep the existing response.

Each quest receipt commits with its payout. Retrying the same request returns its receipt without another payout.
A request ID cannot be reused for a different wallpaper or action. Incomplete prior-day work does not rewind quests.
The client displays a positive amount only from a complete, matching receipt. It never calculates earnings from a balance difference.
Account changes stop action retries. Account deletion closes receipt writes before deleting the receipt tree.

Submission feedback uses the existing first-upload award result.
Approval feedback uses the separate Creator badge receipt from `checkBadges`.
With the flag on, the approval description shows the confirmed amount inline.
The receipt has no wallpaper ID, so the UI does not attribute it to a specific wallpaper.
Neither feedback path creates another reward.

The owner approved this additive backend response change. Reward amounts, odds, limits, and Firestore rules stay unchanged.
Deploy the callable update before enabling the feature in a release. Deployment requires separate owner approval.

## Limits and proof

The feature is not ready for release until both mobile platforms have current build proof.
The signed-in flow needs screenshots and a clip for the shared sheet, reward feedback, and flag-off fallback.
The reviewed debug build starts on `Prism_QA_API36` (`emulator-5580`). Rewards stops at sign-in.
The verification skill requires a human to complete Google or Apple sign-in.
This Linux host has no iOS Simulator tooling. The required signed-in screenshots and clip are still pending.

Keep `daily_moment_v1` off in release until the callable update is deployed and the mobile checks pass.
The flag's debug default does not enable it for release builds.

## Review

The independent `gpt-6-astra` review fixed six issues and added regression tests.
Receipt writes now stop during account deletion, and deletion removes their records.
Deep-link suppression ends when its target closes. Today refreshes claim eligibility and pending receipts.
Account changes clear the visible daily receipt and stop action retries. Late streak replies use the server claim day.

The full Functions suite passed with 2,199 tests passed, 16 skipped, and no failures.
The reviewed Android APK built with both skipped Firebase initialization and the existing dev configuration.

The full local gate passed with `make ci ANALYZE_FLAGS=--no-fatal-infos TEST_FLAGS=--concurrency=6`.
This uses the same informational-lint policy as CI. The main Flutter suite passed 7,891 tests and skipped six.
All six isolated callable tests also passed.
The final APK builds, but another verification run owns the Android emulator lock.
Signed-in Android proof, iOS proof, and the daily-moment clip remain incomplete.
