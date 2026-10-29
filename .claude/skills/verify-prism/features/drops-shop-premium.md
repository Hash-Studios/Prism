# Drops, Shop and Premium

Drops are weekly sets of walls that cost coins to unlock (`/drops`, `lib/features/drops/`). The Shop sells themes, icons, frames and glows for coins (`/shop`, `lib/features/shop/`). Premium is a paid plan sold through RevenueCat (`/premium`, `lib/features/premium/`, `lib/core/purchases/paywall_orchestrator.dart`).

## Sub-features

- `drops-list`: page title `Weekly Drop` (`drops_page.dart`) shows the live week: `Week of <date>`, `Ends in <time>`, a button `Unlock all <n> for <price>`, and tiles `Locked wall <i> of <n> by <creator>` with a price. A locked tile opens a full-screen preview (`openDropPreview`, `drop_preview_page.dart`) with `Close preview`, `Lock screen`, `Home screen` and `Unlock for <price>`. Empty state `No Drop right now` and `The next Drop lands Monday.`.
- `drop-detail`: `/drops/:weekKey`, title `Drop` (`drop_detail_page.dart`). Locked wall tiles open the unlock sheet (`unlock_sheet.dart`). It shows `Unlock this wall for {price}`, `Unlock all {count} for {price}` and `Earn coins`.
- `drop-preview`: `/drops/:weekKey/preview/:wallId`, no guard. The same preview page also opens from a locked tile on `/drops`.
- `shop`: title `Shop`, segmented tabs `Themes`, `Icons`, `Frames`, `Glows`, coin balance pill (`shop_page.dart`). A tile opens an item sheet with `Buy for {price}`, `Earn coins`, `Get Pro` (`shop_item_sheet.dart`).
- `premium`: page title `Prism Premium`, button `View plans`. If plans fail: `Plans are not available right now...` and `Try again` (`premium_page.dart`).

## How to get to it (user POV)

- Home carousel slide with tag `Weekly Drop` (or `Last call`) opens `/drops` (`drop_carousel_slide.dart`, `drop_card.dart`).
- Rewards tab (bottom nav `Rewards`), `Use your coins` tiles `Drops` and `Shop` (`rewards_spend_section.dart`).
- Settings row `Shop` (`settings_screen.dart`).
- Settings row `Buy premium` (hidden when already premium). It calls `PaywallOrchestrator.presentOrRequireSignIn`. That shows the RevenueCat paywall, not `/premium`.
- `/premium` and `/paywall` open `PremiumRoute` by deep link only (`deep_link_catalog_resolver.dart`).
- Guards: `/shop` has `_signedInGuard`. `/drops`, `/drops/:weekKey`, the preview and `/premium` have none (`app_router.dart`).

## Driving it with the helper

Preconditions: signed in for `/shop` and for any unlock. Data needs Doppler dev secrets, not `SKIP_FIREBASE_INIT`.

- **Drops.** Tap `Rewards`, tap `Drops, 30 coins a wall`. Assert `Weekly Drop`. Snapshot `--tag drops`. Tap a locked tile. Assert `Unlock for <price>` and `Close preview`. Snapshot, then tap `Close preview`. `prism://drops` opens the page directly.
- **Shop.** Tap `Shop, from 100 coins` on Rewards (or open `prism://shop`). Tap each of `Themes`, `Icons`, `Frames`, `Glows` and snapshot. Tap one tile to see its sheet. Stop there.
- **Premium page.** Open `prism://premium`. Assert `Prism Premium` and `View plans`. Do not tap `View plans`.
- **Paywall.** Settings, tap `Buy premium`. Snapshot the paywall. Close it with the system close or back.

## Gotchas

- NEVER tap `Unlock this wall`, `Unlock for`, `Unlock all`, `Buy for`, or any plan or purchase button. These spend coins or real money.
- The RevenueCat paywall may not show without real offerings. A toast `Plans are not available right now...` is then expected.
- Drops depend on a live week. Off-season you see `No Drop right now`.
- Signed out: `/shop` redirects to onboarding. Report that as the guard working.
- Confirm every label with `describe` first.
