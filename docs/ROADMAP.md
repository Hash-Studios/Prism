# Prism 3.0.0 — Comeback Roadmap

## The Situation

| Metric | Now | Peak (2021) | Target (12mo) |
|--------|-----|-------------|---------------|
| DAU | ~500-800 | 11,358 | 60,000+ |
| MAU | ~2-3K | 44,248 | 250,000+ |
| Install base | ~1-2K | 37,022 | 80,000+ |
| Revenue | ~$0/mo | ~$600/mo | $10,000/mo |
| Day 1 retention | 18.8% | — | 40% |
| Day 7 retention | ~5% | — | 20% |
| Western users | ~5% | ~12% | 30%+ |

**222K lifetime users. 164K returned at least once. Almost none stayed.**
The Nov 2021 spike (7,426 users in 1 day, 4,192% above baseline) proved Prism can attract users. It just can't keep them.

### The 3.0 Strategy
**Retention first, then growth, then monetize.**
Don't repeat the 2021 mistake — build the bucket before pouring water in.

---

## What Ships in 3.0.0 (The Launch Build)

Everything below must ship together as the v3.0.0 release. This is the minimum viable comeback.

### A. Fix What's Broken

| # | Item | Why | Effort |
|---|------|-----|--------|
| A1 | [x] **Replace Firebase Dynamic Links** with App Links (Android) + Universal Links (iOS) | Sharing is completely broken. No viral loop without this. | Medium |
| A2 | [x] **Migrate `WillPopScope` → `PopScope`** | Deprecated API, causes warnings, bad for store review | Low |
| A3 | [x] **Fix code generation outputs** | Missing or stale `.g.dart` files cause runtime issues | Low |
| A4 | [x] **Remove "download anyway" ad fallback** | Leaks revenue — if ad fails, show retry + Pro upsell instead | Low |
| A5 | [x] **Fix code generation pipeline** | Ensure `make file-gen` produces clean output with no errors | Low |

### B. Prism Coins (The Economy)

| # | Item | Why | Effort |
|---|------|-----|--------|
| B1 | [x] **Coin balance system** | Store coins in user model (already has `coins` field), sync to Firestore | Medium |
| B2 | [x] **Coin balance UI in app bar** | Always-visible coin count, animated earn/spend | Low |
| B3 | [x] **Earn coins: watch rewarded ad (+10)** | Primary earn method — replaces current ad-gate-per-download | Medium |
| B4 | [x] **Earn coins: daily login (+5)** | Opens the app daily | Low |
| B5 | [x] **Earn coins: 7-day streak (+25 bonus)** | Habit formation through Day 0-7 window | Medium |
| B6 | [x] **Earn coins: profile completion (+25)** | Drives profile setup | Low |
| B7 | [x] **Spend coins: download wallpaper (-5)** | Core spend action | Low |
| B8 | [x] **Spend coins: download premium wallpaper (-15)** | Premium content monetization | Low |
| B9 | [x] **Spend coins: AI generation (-20)** | High-value action, drives more ad watches | Low |
| B10 | [x] **"Watch & Download" shortcut** | One-tap: watch ad → earn coins → auto-download | Low |
| B11 | [x] **Low balance nudge** | When coins < 10, suggest watching ad or upgrading to Pro | Low |

### C. Subscriptions Revamp

| # | Item | Why | Effort |
|---|------|-----|--------|
| C1 | [x] **New tiers: Free / Pro (₹99/mo, $3.99/mo) / Lifetime (₹1,999, $29.99)** | Replace current confusing entitlements with simple 2-tier + lifetime | Medium |
| C2 | [x] **Annual Pro option** | ₹999/yr ($39.99/yr) — 2 months free | Low |
| C3 | [x] **Pro bypasses coins** | Downloads, AI (30/day), filters, premium collections — all free for Pro | Medium |
| C4 | [x] **Pro gets 50 coins/day** | Bonus coins for extras (AI beyond 30, future tipping) | Low |
| C5 | [x] **New paywall screen** | Show clear Free vs Pro comparison, contextual upsell after 3+ ad watches | Medium |
| C6 | [ ] **7-day free trial** | Lower barrier to Pro conversion | Low |
| C7 | [x] **Regional pricing via RevenueCat** | India ₹99, US $3.99, EU €3.99, etc. | Low |

### D. AI Wallpaper Generation (The Growth Engine)

| # | Item | Why | Effort |
|---|------|-----|--------|
| D1 | [x] **Text-to-image generation** | "Describe your wallpaper" → AI generates it. THE feature of 2025-2026. | High |
| D2 | [x] **Style presets** | Anime, minimal, cyberpunk, watercolor, mesh gradient, abstract, nature | Medium |
| D3 | [ ] **Device-resolution output** | Auto-detect device resolution, generate at correct aspect ratio | Low |
| D4 | [x] **"Made with Prism" watermark (free tier)** | Every shared AI wallpaper = free marketing. Pro removes watermark. | Low |
| D5 | [x] **Save to gallery + share** | One-tap save, one-tap share to Instagram/Twitter with Prism branding | Low |
| D6 | [x] **Generation history** | View past generations, regenerate with tweaks | Medium |
| D7 | [x] **3 free generations for new users** | First 3 are free (no coins), then coins required. Hook for Day 0. | Low |
| D8 | [x] **AI tab in navigation** | Dedicated tab or prominent entry point — not buried in settings | Low |

### E. Retention Features

| # | Item | Why | Effort |
|---|------|-----|--------|
| E1 | [x] **Wall of the Day** | Firestore doc updated daily, card at top of Home tab, push notification at 9 AM. Backdrops proved this is #1 retention feature. | Medium |
| E2 | [x] **Login streak system** | 7-day cycle with escalating coin rewards. Visible streak counter on profile. Fire icon. FOMO. | Medium |
| E3 | [x] **Streak reminder push** | 8 PM notification if user hasn't opened today + has active streak | Low |
| E4 | [x] **"Tomorrow hook"** | End of first session: "Your first Wall of the Day drops tomorrow at 9 AM" + notification permission ask | Low |
| E5 | [x] **Profile completeness nudge** | Post-signup: "Complete your profile to earn 25 Prism Coins" with progress ring | Low |
| E6 | [ ] **Smart notification permission** | Don't ask on first launch. Ask after first download/favorite with clear value prop. | Low |

### F. Onboarding Revamp

| # | Item | Why | Effort |
|---|------|-----|--------|
| F1 | [x] **Interest selection** | "Pick 5+ categories you love" grid after sign-in. Feeds recommendations. | Medium |
| F2 | [x] **Follow starter pack** | "Follow 3+ creators" — show top 10 with best wallpaper preview | Medium |
| F3 | [x] **Set first wallpaper** | Suggest a wallpaper based on interests, one-tap set. Deliver value in < 60 sec. | Low |

---

## What Ships Post-Launch (Month 1-3)

These are important but not blocking the 3.0.0 release.

### G. Engagement Deepening

| # | Item | Why | Effort | When |
|---|------|-----|--------|------|
| G1 | [ ] **Badge system activation** | 12 badges with triggers — infrastructure already exists in code. Unlock animations. | Medium | Month 1 |
| G2 | [ ] **Auto wallpaper rotation (Pro)** | Schedule-based wallpaper changing from favorites/collections. THE loyalty feature. | High | Month 1-2 |
| G3 | [x] **"For You" personalized feed** | Tag-based matching from interests + favorites + download history | High | Month 2 |
| G4 | [ ] **Weekly challenges** | Rotating challenges with coin + badge rewards. Drives feature exploration. | Medium | Month 2 |
| G5 | [ ] **Collection subscribe + notifications** | "New in [collection]" push when content is added | Low | Month 1 |
| G6 | [ ] **Re-engagement push sequence** | Day 3/7/14/30/60 lapsed user notifications, then stop | Medium | Month 1 |
| G7 | [ ] **Trending feed** | Popular wallpapers last 24h / 7d. Social proof + FOMO. | Medium | Month 2 |

### H. Setup Features (The Differentiator)

| # | Item | Why | Effort | When |
|---|------|-----|--------|------|
| H1 | [ ] **Setup of the Day** | Daily featured setup, same mechanic as Wall of the Day | Low | Month 1 |
| H2 | [ ] **Setup sharing with deep links** | Share setups that open directly in Prism | Medium | Month 1 |
| H3 | [ ] **Setup creation for all users** | Currently Pro-only browse. Let free users create (with coin cost or limit). | Low | Month 2 |

### I. Growth Infrastructure

| # | Item | Why | Effort | When |
|---|------|-----|--------|------|
| I1 | [ ] **Referral system** | Share referral link → friend signs up → both get 100 coins. Code placeholder already exists. | Medium | Month 2 |
| I2 | [ ] **ASO update** | New store listing: "Prism — AI Wallpapers & Setups", screenshots showing AI, setup sharing | Low | Launch day |
| I3 | [ ] **AI share optimization** | One-tap share to Instagram Stories with Prism template/branding | Medium | Month 1 |

---

## What Ships Later (Month 3-6+)

### J. Scale & Monetize

| # | Item | Why | Effort | When |
|---|------|-----|--------|------|
| J1 | [ ] **Creator fund** | Top creators earn coins from engagement on their wallpapers | High | Month 3 |
| J2 | [ ] **Coin purchase packs (IAP)** | ₹29-199 / $0.99-6.99 — additional revenue stream | Medium | Month 3 |
| J3 | [ ] **Tip jar** | Users tip creators with Prism Coins | Medium | Month 4 |
| J4 | [ ] **Comments on wallpapers** | Social proof, community, engagement depth | Medium | Month 3 |
| J5 | [ ] **Home screen widget** | Shows Wall of the Day or rotates wallpapers. Keeps app visible. | High | Month 3 |
| J6 | [ ] **Ad mediation** | Add Unity Ads + Meta Audience Network alongside AdMob for better fill rate + eCPM | Medium | Month 3 |
| J7 | [ ] **AI style transfer** | "Reimagine my photo" — upload photo, get artistic wallpaper version | High | Month 4 |
| J8 | [ ] **Live/video wallpapers** | Basic video wallpaper support — table stakes by 2026 | High | Month 5+ |
| J9 | [ ] **Coin doubler events** | Weekend 2x ad rewards. Drives engagement spikes. | Low | Month 4 |
| J10 | [ ] **Setup marketplace** | Creators sell premium setups. One-tap install. | High | Month 6 |

---

## Development Order (What to Build When)

### Sprint 1: Foundation (Week 1-2)
**Goal**: Fix broken things, set up coin infrastructure

```
A1  Fix deep links (App Links + Universal Links)
A2  Migrate WillPopScope → PopScope
A3  Fix code generation outputs
A4  Remove "download anyway" fallback
A5  Clean code generation pipeline
B1  Coin balance system (model + Firestore sync)
B2  Coin balance UI in app bar
```

### Sprint 2: Economy (Week 3-4)
**Goal**: Coins earning and spending works end-to-end

```
B3  Earn: rewarded ad → +10 coins
B4  Earn: daily login → +5 coins
B5  Earn: 7-day streak → +25 bonus
B6  Earn: profile completion → +25
B7  Spend: download wallpaper → -5 coins
B8  Spend: premium download → -15 coins
B10 "Watch & Download" shortcut
B11 Low balance nudge
```

### Sprint 3: Subscriptions (Week 5)
**Goal**: New Pro/Lifetime tiers live on RevenueCat

```
C1  New tier structure (Free / Pro / Lifetime)
C2  Annual Pro option
C3  Pro bypasses coins
C4  Pro daily coin bonus
C5  New paywall screen
C6  7-day free trial
C7  Regional pricing
```

### Sprint 4: Retention (Week 5-6)
**Goal**: Daily hooks are in place

```
E1  Wall of the Day (Firestore + UI + push)
E2  Login streak system (UI + coin integration)
E3  Streak reminder push notification
E4  "Tomorrow hook" in first session
E5  Profile completeness nudge
E6  Smart notification permission flow
```

### Sprint 5: Onboarding (Week 6-7)
**Goal**: New users get a personalized first experience

```
F1  Interest selection screen
F2  Follow starter pack screen
F3  "Set your first wallpaper" flow
```

### Sprint 6: AI Generation (Week 7-10)
**Goal**: Text-to-image AI generation works end-to-end

```
D1  Text-to-image generation (API integration)
D2  Style presets UI
D3  Device-resolution output
D4  "Made with Prism" watermark
D5  Save to gallery + share flow
D6  Generation history
D7  3 free generations for new users
D8  AI tab in navigation
B9  Spend: AI generation → -20 coins
```

### Sprint 7: Polish & Ship (Week 10-11)
**Goal**: Bug fixes, performance, store preparation

```
I2  ASO update (new listing, screenshots)
    Performance testing
    Bug fixes
    Store review submission
```

**Total estimated timeline: ~11 weeks (2.5-3 months) to 3.0.0 launch**

---

## Launch Plan

### Week of Launch
1. Submit to App Store + Play Store
2. Update store listing (AI-focused screenshots, new description, keywords)
3. Notify existing user base via in-app messaging + push notification
4. Soft launch posts on Reddit r/androidthemes, r/FlutterDev

### Week 1-2 Post-Launch (Measure)
- Track Day 1, Day 7 retention vs. 18.8% / 5% baseline
- Track coin earn/spend velocity
- Track AI generation usage
- Track Pro conversion rate
- **Do NOT do big marketing push yet** — wait for retention data

### Week 2-4 (Validate & Iterate)
- If Day 1 retention > 30%: proceed to growth push
- If Day 1 retention < 25%: iterate on onboarding + daily hooks first
- A/B test paywall timing and messaging
- Fix any critical bugs from initial users

### Month 2 (Growth Push — Only If Retention Targets Met)
- Product Hunt launch
- Reddit campaign (r/androidthemes, r/iOSsetups, r/wallpapers, r/Android)
- YouTube outreach (10-20 customization channels)
- TikTok/Reels content: "Generate wallpapers with AI"
- Begin post-launch features (G1-G7, H1-H3, I1-I3)

### Month 3-6 (Scale)
- Western market push (localized store listings, influencer partnerships)
- Scale features (J1-J10)
- Optimize conversion, ad eCPM, coin economy
- Creator economy launch

---

## Success Criteria for 3.0.0

### Launch is a success if (within 30 days):
- [ ] Day 1 retention ≥ 30% (up from 18.8%)
- [ ] Day 7 retention ≥ 12% (up from ~5%)
- [ ] DAU/MAU ≥ 15% (up from 5-8%)
- [ ] Pro conversion ≥ 2%
- [ ] Average 3+ ad watches per free user per day (up from ~0.5)
- [ ] 1,000+ AI generations per day
- [ ] No critical bugs or crashes

### 6-month targets:
- [ ] 30K+ DAU
- [ ] 30%+ Western users
- [ ] $5,000+/mo revenue
- [ ] Day 1 retention ≥ 35%

### 12-month target:
- [ ] **$10,000+/mo revenue**
- [ ] 60K+ DAU

---

## Risk Register

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| AI API costs eat margin | Medium | High | Use efficient models (SDXL Turbo), cache popular prompts, set daily limits per user |
| AI output quality is mediocre | Medium | High | Test multiple providers, fine-tune prompts, offer style presets that work well |
| Retention doesn't improve enough | Medium | High | A/B test onboarding variants, iterate on daily hooks, add more coin spend sinks |
| Pro conversion < 2% | Medium | Medium | Free trial, contextual upsells, paywall A/B testing |
| App store rejection (AI content) | Low | High | Content moderation, safe prompts only, NSFW filter on outputs |
| Existing users dislike changes | Low | Medium | In-app changelog, "What's New" screen, gradual rollout via Remote Config |
| Ad fill rate low in India | Medium | Medium | Ad mediation (multiple networks), optimize placements |
| Deep link migration breaks existing links | Medium | Medium | Redirect old Dynamic Links domain to new Universal Links |

---

## Reference Documents

- **[PLAN.md](./PLAN.md)** — Original feature plan & improvements list
- **[COMPETITORS.md](./COMPETITORS.md)** — Competitive landscape & feature comparison matrix
- **[GROWTH.md](./GROWTH.md)** — User data analysis, DAU/MAU/retention stats, growth strategy
- **[REVENUE.md](./REVENUE.md)** — Monetization model, Prism Coins economy, path to $10K/mo
- **[RETENTION.md](./RETENTION.md)** — Retention mechanics, push strategy, engagement plan
