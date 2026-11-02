# Rewards and coins

Rewards is one scroll page for the streak, the daily quests, the coin balance, and ways to earn and spend coins. The page is `lib/features/rewards/views/pages/rewards_page.dart`, titled `Rewards`. It is the `Rewards` bottom-nav tab (`/dashboard/rewards`, `RewardsTabRoute`) and a pushed page (`/rewards`, `RewardsRoute`). The coin logic lives in `lib/core/coins`.

## Sub-features

- `rewards-page`: sections in order (`rewards_page.dart`): streak hero (`STREAK`, `N days streak`, `Best N days`), Drop card, rank card, `Daily quests` (`lib/features/quests/views/widgets/today_card.dart`), daily chest banner, `Spin the wheel` card, `Streak freeze` card (button `Get one · <cost>`, or `Full`), balance card (`<n> Prism coins`).
- `earn`: `Earn coins` list (`rewards_earn_section.dart`) with `Daily streak`, `Day 7 chest`, `Watch a video`, `Invite a friend` (opens `SharePrismRoute`, title `Invite friends`), `First upload`, `Complete your profile`.
- `spend`: `Use your coins` tiles (`rewards_spend_section.dart`), labelled with their price: `AI wallpaper, from 10 coins`, `Drops, 30 coins a wall`, `Shop, from 100 coins`, `Premium collection` (10 coins for 24 h), `Boost, 100 coins`, `Gift a pass, 50 coins`, `Streak freeze, 50 coins`, `Downloads, 10 coins`.
- `links`: `Leaderboard` and `Weekly draw` (the draw row depends on a flag), then badges (`rewards_links_section.dart`).
- `activity`: `Activity` list with `See all`. It opens `Coin history` (`/coin-history`, `coin_history_page.dart`) with chips `Earned`, `Spent`, `Refunds`, or `No coin activity yet.`.
- `sub-pages`: `/daily-chest`, `/spin-wheel` (`SPIN`, `Free spin`), `/leaderboard` (tabs `Following`, `Global`), `/draw` (`Prism Draw`, `Official rules`). All need sign-in.
- `coin-chip`: `CoinBalanceChip` (`lib/core/widgets/coins/coin_balance_chip.dart`) has the label `<n> Prism coins`. It pushes `RewardsRoute`. The streak pill is never shown today: the only caller passes `showStreak: false`.
- `daily-claim`: the daily claim sheet is hosted from the dashboard (`daily_claim_host.dart`, `daily_claim_sheet.dart`).

## How to get to it (user POV)

- Tap `Rewards` in the bottom nav.
- Tap the coin balance chip, for example on the AI wallpaper page.
- Old paths `/dashboard/streak`, `/streak`, and `/coin-transactions` redirect to Rewards (`lib/core/router/app_router.dart`).

## Driving it with the helper

Preconditions: a signed-in human for everything past the first check. Signed out, the page shows `Sign in to use Rewards` and a `Sign in` button (`SignInPrompt`).

- **Landing.** Tap `Rewards`. Snapshot `--tag rewards`. Assert `Rewards`, `<n> Prism coins` and `<n> days streak` (the `STREAK` eyebrow is not in the tree). A daily strip such as `Today is done. Come back tomorrow for +3 coins.` can show at the top. Scroll to see `Daily quests`, `Earn coins`, `Use your coins`, `Activity`.
- **Streak freeze.** Assert the card shows `Get one` or `Full`. Do not tap `Get one`; it spends coins.
- **Earn list.** Assert `Watch a video` and `Invite a friend` render. Tap `Invite a friend` only to see `Invite friends`, then go back.
- **Spend tiles.** Tap `AI wallpaper, from 10 coins` and assert the AI page opens. Go back.
- **Coin history.** Scroll to `Activity`, tap `See all`. Snapshot `--tag coin-history`. Assert `Coin history`, the three chips, or the empty text. `See all` shows only after the list loads; until then the section can show `No coin activity yet.` for a moment, so wait before you call it empty.
- **Leaderboard.** Tap `Leaderboard`. Assert the `Following` and `Global` tabs.
- **Coin chip.** From another page, tap `<n> Prism coins`. Assert Rewards opens.

## Gotchas

- Never tap `Watch a video` (real rewarded ad), `Get one`, `SPIN`, `Open` on a paid chest, or buy a draw ticket. These spend or earn real coins. Ask the human first.
- `SKIP_FIREBASE_INIT=true` builds show no real balance or streak. Use Doppler dev secrets for real data.
- `/daily-chest`, `/spin-wheel`, `/leaderboard`, `/draw`, `/coin-history` have a signed-in guard. A signed-out link goes to onboarding.
- Coin rules are in `lib/core/coins/coin_policy.dart`. Read it to explain why a balance changed.
