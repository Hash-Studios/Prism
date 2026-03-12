# Prism 3.0 Improvement Plan

## Current State: What Prism Does Well

Prism is a **solid, well-architected app** with clean BLoC architecture, 3 wallpaper sources (WallHaven, Pexels, Prism community), social features (follow, favorites, profiles, badges), RevenueCat subscriptions, and a **unique Setups feature** (share your full home screen config) that most competitors don't have.

---

## Phase 1: Fixes (Broken / Deprecated)

- [ ] **Firebase Dynamic Links are dead** (sunset Aug 2025) — deep linking for sharing is broken. Migrate to App Links (Android) + Universal Links (iOS).
- [ ] **Referral system is a TODO** — `home_tab_page.dart:139` has a placeholder `// TODO: add referral handling`.
- [ ] **`WillPopScope` still used in places** — deprecated, needs migration to `PopScope`.
- [ ] **Code generation errors** — some `.g.dart` files are stale or missing.
- [ ] **No tests at all** — `bloc_test` and `mocktail` are in pubspec but zero test files exist.
- [ ] **Logger package sink is stubbed** — throws `UnimplementedError`.

---

## Phase 2: Improve Existing Features

| Area | Current State | Improvement | Status |
|------|--------------|-------------|--------|
| **Content Discovery** | Category tabs + chronological feed | Add a **"For You" personalized feed** based on favorites/download history/color preferences | [ ] |
| **Daily Engagement** | No daily hook | Add **"Wall of the Day"** with push notification — dead-simple, high retention | [ ] |
| **Search** | Basic keyword + user search | Add **color-based search**, resolution/aspect-ratio filtering, visual similarity search | [ ] |
| **Setups (differentiator)** | Browse/share screenshots | Make setups **one-tap installable** — bundle icon packs, widget configs, wallpaper. Add a "Setup of the Day" | [ ] |
| **Social** | Follow, like, share | Add **comments on wallpapers**, reactions, community challenges/contests | [ ] |
| **Creator Motivation** | Upload for free, get badges | Add **creator payouts/revenue sharing** (Walli model) — better content attracts more users | [ ] |
| **Wallpaper Preview** | Basic preview | Add **lock screen preview** with clock overlay, depth-effect preview for iOS 16+ | [ ] |
| **AMOLED** | Dark theme exists | Add dedicated **AMOLED wallpaper category** (pure black backgrounds, battery-saving, hugely popular) | [ ] |
| **Premium UX** | Standard paywall | Add a **credits/coins** economy — watch ads to earn credits, spend on premium walls. More engagement than hard paywall. | [ ] |

---

## Phase 3: New Features — High Priority (revenue & retention)

- [ ] **AI Wallpaper Generation** — THE feature of 2025-2026. Zedge, standalone apps, everyone has it.
  - Text-to-image via Stable Diffusion / DALL-E API
  - "Reimagine my photo" (style transfer)
  - Style presets: anime, minimal, cyberpunk, watercolor, mesh gradients
  - Credit system: free users get N/day, premium unlimited

- [ ] **Auto Wallpaper Rotation** — Schedule-based wallpaper changing (daily/hourly) from favorites or a collection. Low effort, high retention. Resplash and Muzei both have this.

- [ ] **Home Screen Widget** — A widget that shows "Wall of the Day", rotates wallpapers, or shows the next wallpaper in your queue. Keeps the app visible without opening it.

---

## Phase 4: New Features — Medium Priority (engagement & differentiation)

- [ ] **Live / Video Wallpapers** — Zedge has an entire category. Even basic video wallpaper support would be table-stakes in 2026.

- [ ] **Depth Effect Wallpapers** — iOS 16+ depth effect (clock behind subject). Tag compatible wallpapers or use AI depth-map generation. Big draw for iOS users.

- [ ] **Setup Marketplace** — Double down on the unique feature. Let creators sell premium setups. One-tap install: wallpaper + icon pack + widget theme.

- [ ] **Personalized "For You" Feed** — Collaborative filtering or content-based recommendations from user behavior.

---

## Phase 5: New Features — Lower Priority (polish & expansion)

- [ ] **Dynamic Wallpapers** — Time-of-day shifting, weather-reactive wallpapers
- [ ] **Resolution-Based Filtering** — Let users filter by their exact device resolution
- [ ] **Ringtones / Notification Sounds** — Expand into an all-in-one personalization hub (Zedge model)

---

## Quick Wins (Low Effort, Good Impact)

- [ ] Add AMOLED wallpaper category tag (just a filter on existing content)
- [ ] "Wall of the Day" feature with push notification
- [ ] Home screen widget showing featured wallpaper
- [ ] Migrate `WillPopScope` -> `PopScope`
- [ ] Fix deep linking (replace Firebase Dynamic Links)
- [ ] Add basic auto-rotate from favorites collection

---

## Strategy Summary

Prism's **architecture is strong** and the **Setups feature is genuinely unique**. The biggest gaps vs. 2026 competitors are:
1. **No AI generation** (every major app has this now)
2. **No auto-wallpaper rotation** (expected baseline feature)
3. **No personalized feed** (chronological isn't engaging enough)
4. **Broken deep linking** (Dynamic Links are dead)
5. **No creator monetization** (limits content quality)

**Recommended approach**: Fix the broken stuff first (Phase 1), then double down on Setups as the differentiator while adding AI generation as the primary growth feature. The combination of AI-generated wallpapers + shareable setups + creator marketplace would be genuinely unique in the space.
