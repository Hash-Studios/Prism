# Prism Retention & Engagement Plan

## Current State: Almost Zero Retention Mechanics

### What Exists (and barely works)

| Feature | Status | Reality |
|---------|--------|---------|
| **Push notifications** | 40% | Topic subscriptions exist but no campaigns, no re-engagement, no scheduling |
| **Local notifications** | 10% | Only triggers on download complete. No reminders, no daily digest. |
| **Daily hooks** | 0% | Nothing. No wall of the day, no streaks, no daily content. |
| **Favorites** | 70% | Works but no "new content in your favorites" notifications |
| **Following feed** | 80% | Best retention feature — shows followed creators' posts |
| **Onboarding** | 50% | Theme picker + Google login. No interest selection, no guided tour. |
| **Deep links/sharing** | Broken | Firebase Dynamic Links dead since Aug 2025 |
| **Gamification** | 5% | Badge & coin models exist in code but are **completely unused** |
| **Profile completeness** | 0% | No prompts, no incentives, no progress bar |
| **In-app messaging** | 70% | Infrastructure is good (Firestore-backed, targeted) but no active campaigns |

### Actual Retention Data (Last 42 days ending Feb 17, 2026)

| Day | Retention | What It Means |
|-----|-----------|---------------|
| **Day 0** | 100% | — |
| **Day 1** | **18.8%** | 81% of users never come back. This is the #1 problem. |
| **Day 4** | ~5-8% | The cliff has happened. Survivors start to stabilize. |
| **Day 7** | ~4-6% | — |
| **Day 14** | ~3-5% | — |
| **Day 30** | ~2-4% | — |
| **Day 42** | ~2-3% | The long-term loyal core |

**Industry benchmarks for wallpaper apps**: Day 1 = 30-40%, Day 7 = 15-20%, Day 30 = 8-12%.
**Prism is roughly half the industry average at every stage.**

### Other Key Stats
- **DAU/MAU ratio**: 5-8% (should be 20-25% for a good utility app)
- **Peak DAU**: 11,358 (Nov 29, 2021) — 88% from India
- **Peak MAU**: 44,248 (Dec 24, 2021) — 74% from India
- **Lifetime users**: 222K new, 164K returning
- **The Nov 2021 spike**: 7,426 new users in one day (4,192% above expected). Almost all churned within weeks.

### The Result
Users install → browse → maybe download a wallpaper → leave → never come back. There is **no reason to open Prism on Day 2**.

---

## Retention Framework

We need mechanics at every stage of the user lifecycle:

```
Day 0 (Install)     → Great first experience + profile setup
Day 1-3 (Activation) → Daily hook + first value moment
Day 4-7 (Habit)      → Streak builds + social connection
Day 8-30 (Retention)  → Personalized content + coin economy engagement
Day 30+ (Loyalty)     → Creator identity + community + premium value
```

---

## Day 0: First Session Experience

### Problem
Current onboarding: 3-slide carousel → pick theme → Google sign-in → dumped into home feed. No personalization, no guidance, no hook for tomorrow.

### Plan

**Step 1: Interest Selection (New)**
After sign-in, show a grid of wallpaper categories with thumbnails:
- "Pick 5+ categories you love" (nature, abstract, anime, minimal, dark, cars, space, etc.)
- This feeds the "For You" recommendations and primes the following feed
- Also sets which collections to highlight

**Step 2: Follow Starter Pack (New)**
- "Follow 3+ creators to build your feed"
- Show top 10 creators with preview of their best wallpaper
- Pre-select top 3, let user customize
- This immediately populates the Following tab

**Step 3: Set Your First Wallpaper (New)**
- "Here's a wallpaper we think you'll love" (based on interests picked)
- One-tap to set as wallpaper → immediate value delivered
- User feels "this app did something for me" in < 60 seconds

**Step 4: Profile Setup Nudge (New)**
- Soft prompt (not blocking): "Complete your profile to earn 25 Prism Coins"
- Show profile completeness ring (0% → 100%)
- Fields: photo, username, bio, one social link
- Can skip — but the coin incentive pulls many users in

**Step 5: Tomorrow Hook (New)**
- End of first session: "Your first Wall of the Day drops tomorrow at 9 AM"
- Ask for notification permission with clear value proposition
- Schedule local notification for next morning

---

## Day 1-7: Building the Habit

### Wall of the Day (Critical — New Feature)

**What**: One featured wallpaper every day at a consistent time (e.g., 9 AM local).

**Implementation**:
- Firestore document `wall_of_the_day` updated daily (can be automated or admin-curated)
- Push notification at 9 AM: "Today's Wall of the Day is here"
- Dedicated card at top of Home tab — large, beautiful, impossible to miss
- "Set as wallpaper" one-tap CTA right on the card
- Free for everyone (even premium walls) — this is a retention feature, not a revenue gate
- After 24 hours, wall moves to a "Past Picks" collection

**Why it works**: Backdrops proved this — "Wall of the Day" is the #1 retention feature in wallpaper apps. It gives users a reason to open the app every single day.

### Login Streak System (New)

Tied directly to Prism Coins economy:

| Day | Coins Earned | Bonus |
|-----|-------------|-------|
| Day 1 | +5 | — |
| Day 2 | +5 | — |
| Day 3 | +5 | — |
| Day 4 | +10 | — |
| Day 5 | +10 | — |
| Day 6 | +10 | — |
| Day 7 | +25 | "Week Warrior" badge + streak fire icon |

- Streak resets if you miss a day
- Streak counter visible on profile and in coin balance area
- Day 7 bonus is significant — 25 coins = 5 wallpaper downloads free
- Creates FOMO: "I don't want to break my streak"
- After Day 7, cycle restarts (so it's always 7-day cycles)

### AI Generation as Engagement Hook (New)

For free users:
- First 3 AI generations are free (no coins needed) — during first 3 days
- After that, costs Prism Coins (earned via ads or streaks)
- "Try generating a wallpaper" prompt on Day 1 if user hasn't tried AI yet
- AI results are inherently engaging — users experiment with prompts

### Push Notification Strategy (Revamp Existing)

| Notification | When | Who |
|-------------|------|-----|
| **Wall of the Day** | 9 AM daily | All users with notifs enabled |
| **Streak reminder** | 8 PM if not opened today | Users with active streak |
| **"X new walls from creators you follow"** | When 5+ new walls from followed creators | Users who follow people |
| **"Your wallpaper got N likes"** | When creator's wall hits milestones (10, 50, 100) | Creators |
| **"New in [favorite collection]"** | When new walls added to user's favorited collections | Users with favorites |
| **Re-engagement** | After 3 days inactive | Lapsed users |
| **Weekly digest** | Sunday morning | All users |

**Rules:**
- Max 2 push notifications per day (don't spam)
- Quiet hours: 10 PM - 8 AM (respect sleep)
- Users can toggle each notification type in Settings
- Re-engagement stops after 3 attempts (don't annoy churned users)

---

## Day 7-30: Deepening Engagement

### Personalized "For You" Feed (New)

**What**: Algorithmic feed based on user behavior — replaces/supplements chronological feed.

**Signals used:**
- Categories selected during onboarding
- Wallpapers downloaded/favorited (color palette, style, category)
- Creators followed
- Search terms used
- Time spent viewing wallpapers (implicit interest signal)

**Implementation (Simple v1):**
- Tag-based matching: each wallpaper has tags/categories → score against user's interests
- Collaborative filtering: "users who liked X also liked Y" (Firestore aggregation)
- Freshness boost: newer content ranked higher
- "For You" becomes the default first tab (replacing or joining "Wallpapers" tab)

### Weekly Challenges (New)

| Week | Challenge | Reward |
|------|-----------|--------|
| Week 1 | "Download 5 wallpapers" | 50 coins + "Explorer" badge |
| Week 2 | "Follow 3 creators" | 30 coins + "Social" badge |
| Week 3 | "Generate an AI wallpaper" | 40 coins + "Creator" badge |
| Week 4 | "Upload your first wallpaper" | 100 coins + "Contributor" badge |

- Rotating challenges each week (can repeat with higher targets)
- Challenge card visible on home screen
- Progress bar shows completion
- Drives users to try features they haven't explored yet

### Badge & Achievement System (Activate Existing Infrastructure)

The badge model already exists in code (`Badge` class with name, description, imageUrl, color). Just needs activation.

**Badges to implement:**

| Badge | Criteria | Coins Reward |
|-------|----------|-------------|
| "First Steps" | Set first wallpaper | 10 |
| "Collector" | Favorite 10 wallpapers | 25 |
| "Art Curator" | Favorite 50 wallpapers | 50 |
| "Social Butterfly" | Follow 10 creators | 25 |
| "Creator" | Upload first wallpaper | 50 |
| "Popular" | Get 100 likes on a wallpaper | 100 |
| "AI Artist" | Generate 10 AI wallpapers | 30 |
| "Streak Master" | Complete 4 weekly streaks | 100 |
| "Setup Pro" | Create first setup | 50 |
| "Prism Veteran" | Use app for 30 days | 75 |
| "Profile Complete" | Fill all profile fields | 25 |
| "Week Warrior" | Complete 7-day login streak | 25 |

- Badges display on user profile (already have display infrastructure)
- Badge unlock animation (celebration moment)
- Badge unlock notification
- Total badge count shown on profile

### Collection Notifications (Enhance Existing)

Currently: Collections exist but users don't know when new content is added.

**Add:**
- "Subscribe" button on collections → get notified when new walls added
- "New in [Collection Name]" push notification (batched daily, not per-wall)
- "Trending Collections" section on home screen that rotates

---

## Day 30+: Long-Term Loyalty

### Auto Wallpaper Rotation (Pro Feature — New)

**What**: Automatically change wallpaper on a schedule from a user's favorites or a collection.

**Options:**
- Frequency: Every hour / Every 6 hours / Daily / Weekly
- Source: My favorites / Specific collection / "For You" picks / AI-generated
- Screens: Home screen / Lock screen / Both

**Why this is THE loyalty feature:**
- Once set up, the app is actively useful even when not opened
- Users keep it installed because it's doing something for them in the background
- This is a Pro-only feature — strong subscription driver
- Resplash and Muzei prove this is the #1 retention feature for power users

### Creator Identity (New)

For users who upload wallpapers:
- Creator dashboard: views, downloads, likes over time
- "Your wallpaper was set by X people today" notification
- Monthly creator highlights (top creators get featured)
- Creator tier badges: Rising (10 uploads) → Established (50) → Featured (100+)
- Creator-specific analytics in profile

### Community Features (New)

| Feature | Description | Engagement Impact |
|---------|------------|-------------------|
| **Comments on wallpapers** | Simple text comments below wallpaper detail | Social proof, discussion |
| **"Remix" chain** | AI-regenerate someone's wallpaper with modifications | Creative engagement |
| **Setup challenges** | Monthly themed setup competition (e.g., "Minimal March") | Community events |
| **Trending feed** | Real-time popular content (last 24h, 7d) | Discovery + FOMO |

---

## Re-engagement Flows (Win Back Lapsed Users)

### Push Notification Sequence for Inactive Users

| Days Inactive | Message | CTA |
|--------------|---------|-----|
| 3 days | "Your streak is about to break! Open Prism to keep it going" | Open app |
| 7 days | "You have 5 new walls from creators you follow" | View feed |
| 14 days | "This week's Wall of the Day was loved by 10K people. See it?" | View WOTD |
| 30 days | "We've added AI wallpaper generation! Create your dream wallpaper" | Try AI |
| 60 days | Final attempt: "We miss you — here's 50 free Prism Coins" | Claim coins |

After 60 days: Stop notifications. Don't annoy churned users.

### Email Re-engagement (Future)
- Collect email during signup (Google auth provides this)
- Weekly digest email: "Top wallpapers this week" + "Your coins balance"
- Only for users who've been inactive 7+ days

---

## Notification Permission Strategy

Currently: Permission requested on first launch with no context.

**Improved flow:**
1. Don't ask on first launch — let user experience value first
2. After user downloads first wallpaper or favorites something: "Want to know when new wallpapers like this drop?" → permission request
3. Show clear value: "Get Wall of the Day, new content from creators you follow, and streak reminders"
4. If denied, don't re-ask for 7 days. Then try once more with different messaging.

---

## Implementation Priority

### Phase 1: With 3.0 Launch (Highest Impact, Lowest Effort)
- [ ] Wall of the Day (Firestore doc + home screen card + push notification)
- [ ] Login streak system (7-day cycle + coins rewards)
- [ ] Prism Coins display in app bar
- [ ] Daily login coin bonus (+5 coins)
- [ ] Profile completeness nudge (post-signup soft prompt + 25 coin reward)
- [ ] Fix sharing/deep links (replace Firebase Dynamic Links)
- [ ] "Streak reminder" push notification at 8 PM

### Phase 2: First Month Post-Launch
- [ ] Interest selection in onboarding ("pick 5 categories")
- [ ] Follow starter pack in onboarding ("follow 3 creators")
- [ ] Badge system activation (implement 12 badges with triggers)
- [ ] Push notification strategy (wall of the day, follower activity, re-engagement)
- [ ] Collection subscribe + notification

### Phase 3: Month 2-3
- [ ] Auto wallpaper rotation (Pro feature)
- [ ] "For You" personalized feed (v1: tag-based matching)
- [ ] Weekly challenges
- [ ] Creator dashboard (views, likes analytics)
- [ ] Re-engagement push sequence for lapsed users

### Phase 4: Month 3+
- [ ] Comments on wallpapers
- [ ] Trending feed (24h, 7d)
- [ ] Setup challenges / community events
- [ ] Email digest for lapsed users
- [ ] AI "remix" chain feature

---

## Retention Metrics to Track

| Metric | Actual (Feb 2026) | Month 1 Target | Month 3 Target | Month 6 Target |
|--------|-------------------|----------------|----------------|----------------|
| **Day 1 retention** | **18.8%** | 30% | 35% | 40% |
| **Day 7 retention** | **~5%** | 12% | 18% | 20% |
| **Day 30 retention** | **~3%** | 8% | 12% | 15% |
| **DAU/MAU ratio** | **5-8%** | 15% | 20% | 25% |
| **Avg sessions/user/week** | ~1-2 | 3-4 | 4-5 | 5-6 |
| **7-day streak completion** | 0% (doesn't exist) | 10% | 15% | 20% |
| **Push notif opt-in** | unknown | 50% | 60% | 65% |
| **WOTD engagement** | N/A | 15% of DAU | 20% | 25% |

---

## How This Connects to Revenue

Retention is the **multiplier** on growth. Here's the math with real numbers:

**Current state** (18.8% Day 1):
- 100 installs → 19 Day 1 users → 5 Day 7 → 3 Day 30 → ~$0.03 LTV per install

**With retention improvements** (35% Day 1):
- 100 installs → 35 Day 1 users → 18 Day 7 → 12 Day 30 → ~$0.50 LTV per install

That's **~17x more revenue per install**. Combined with growth and better monetization, this is how the three pillars compound to $10K/mo:

```
Growth (25-40x installs) × Retention (17x LTV) × Monetization (3-5x ARPU) = $10K/mo
```

Each pillar multiplies the others. You can't hit $10K with just one.

**The lesson from the Nov 2021 spike**: 7,426 new users arrived in one day. With 18.8% Day 1 retention, ~1,400 came back. With 35% Day 1 retention, that would have been ~2,600. With a streak system driving Day 7 to 18%, ~1,340 would have survived the week vs ~370 actual. That's 3.6x more retained users from the same spike. Build retention before the next growth push.
