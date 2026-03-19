# Prism Growth Analysis

## Actual Stats (from Play Console & Firebase Analytics)

### Lifetime Totals
- **222K new users** (all-time)
- **164K returning users** (all-time)
- **Returning/New ratio**: 74% — most people who tried the app came back at least once

### Daily Active Users (DAU)
| Period | All Countries | India | India % |
|--------|--------------|-------|---------|
| **Peak** (Nov 29, 2021) | 11,358 | 9,955 | 88% |
| **Pre-spike baseline** (2020-2021) | 800-2,500 | 300-800 | ~40-50% |
| **Post-spike decay** (mid 2022) | 1,000-2,000 | 500-1,000 | ~50% |
| **Current** (early 2026) | ~500-800 (est.) | ~250-400 (est.) | ~50% |

### Monthly Active Users (MAU)
| Period | All Countries | India | India % |
|--------|--------------|-------|---------|
| **Peak** (Dec 24, 2021) | 44,248 | 32,583 | 74% |
| **Pre-spike** (early 2021) | 8,000-15,000 | 2,000-5,000 | ~30-40% |
| **Current** (early 2026) | ~2,000-3,000 (est.) | ~1,000-1,500 (est.) | ~50% |

### DAU/MAU Ratio (Stickiness)
| Period | All Countries | India |
|--------|--------------|-------|
| **Spike peak** (Nov 29, 2021) | 60.27% | 77.85% |
| **Pre-spike baseline** | 8-12% | 10-20% |
| **Post-spike** (2022) | 5-8% | 5-10% |
| **Current** (2025-2026) | 3-7% | sporadic |

**Note**: The spike DAU/MAU of 60-78% is artificially high (flood of new users all active on same day). The steady-state 5-8% is the real stickiness — and it's low. Good apps target 20-30%+.

### User Retention (Last 42 days ending Feb 17, 2026)
| Day | Retention |
|-----|-----------|
| **Day 0** | 100% |
| **Day 1** | **18.8%** |
| **Day 4** | ~5-8% |
| **Day 7** | ~4-6% |
| **Day 14** | ~3-5% |
| **Day 30** | ~2-4% |
| **Day 42** | ~2-3% |

**The cliff**: 81% of users never come back after Day 0. The drop from Day 0 → Day 1 is catastrophic. After Day 4, the curve flattens — meaning the ~5% who survive the first week tend to stick around.

### The Nov 2021 Spike
- **Date**: Nov 30, 2021
- **New users that day**: 7,426
- **Expected (baseline)**: 173
- **Spike magnitude**: **4,192.5%** above normal
- **Likely cause**: Reddit feature, social media viral moment, or app store feature
- **What happened after**: Rapid decay back to baseline within 2-3 months. Almost none of the 7,426 new users retained.

---

## Install Base (Unique Devices)

| Period | All Countries | India | US | Egypt | UK |
|--------|--------------|-------|----|-------|-----|
| **Peak** (Dec 19, 2021) | 37,022 | 21,332 | 1,848 | 1,209 | 544 |
| **Current** (2026) | ~1,000-2,000 | ~600-1,000 | ~50-100 | ~30-50 | ~20-30 |
| **Decline** | ~95-97% | ~95-97% | ~95-97% | ~95-97% | ~95-97% |

---

## What the Data Tells Us

### 1. The Day 1 Cliff is the #1 Problem
18.8% Day 1 retention means **4 out of 5 users never come back**. This is the single biggest lever. Industry average for utility apps is 25-35%. Good wallpaper apps hit 30-40%. We're at 19%.

**Root cause**: No hook to return. User downloads one wallpaper, job is done, no reason to come back tomorrow.

**Fix**: Wall of the Day (reason to return), login streak (incentive to return), interest-based onboarding (personalized content from Day 1), first-session AI generation (novelty hook).

### 2. The Spike Was Wasted
7,426 users in one day, but no retention mechanics captured them. If Day 1 retention had been 35% instead of ~19% during the spike, that's ~2,600 retained users vs ~1,400 — almost 2x. With a streak system and daily hooks, the spike could have permanently elevated the baseline.

**Lesson for 3.0 launch**: Build retention BEFORE the growth push. Don't spike installs until the bucket stops leaking.

### 3. Post-Day-4 Users Are Loyal
The curve flattens after Day 4 at ~5%. Those users tend to stick around through Day 42+. This means the real battle is Day 0 → Day 4. If you can get users past the first week, they stay.

**Implication**: Focus the 7-day streak cycle on this exact window. Days 1-7 need to be the best experience with escalating rewards.

### 4. DAU/MAU of 5-8% = Low Stickiness
The app is not part of users' daily routine. For context:
- Social media apps: 40-60% DAU/MAU
- Good utility apps: 20-30%
- Wallpaper apps (with daily hooks): 15-25%
- **Prism currently**: 5-8%

**Target**: 20-25% DAU/MAU with Wall of the Day + streaks + auto-rotation.

### 5. India Dominance Hasn't Changed
India was 88% of DAU at spike, and ~50% at baseline. The non-India user base was always tiny and hasn't grown. Western users never found the app organically.

### 6. Classic Viral Spike + No Retention = Wasted Growth
The Nov 2021 spike was 4,192% above baseline. But without retention mechanics, it decayed back to baseline in ~3 months. Every future growth effort will suffer the same fate unless retention is fixed first.

---

## Growth Strategy (Updated with Real Data)

### Phase 0: Fix Retention First (Before Growth Push)
**This is non-negotiable.** The data proves that growth without retention is wasted. Build these before any marketing:

- Wall of the Day → push notification → daily open reason
- Login streak (7-day cycle) → coin rewards → habit formation
- Interest-based onboarding → personalized feed → better Day 1 experience
- AI generation → novelty + experimentation → multiple sessions
- Fix sharing/deep links → viral loop must work when growth comes

**Target before growth push**: Day 1 retention 30%+, Day 7 retention 12%+

### Phase 1: Controlled Launch (Month 1-2)
- 3.0 launch with AI + coins + retention features
- Soft launch: existing user base + small Reddit posts
- Measure retention improvements before scaling
- **Target: 2-5K DAU, 30% Day 1 retention**

### Phase 2: Growth Push (Month 2-4)
Only after retention targets are hit:
- Product Hunt launch
- Reddit: r/androidthemes (500K), r/iOSsetups, r/wallpapers, r/Android
- YouTuber outreach (Android customization channels)
- TikTok/Reels: AI wallpaper generation demos
- ASO: "AI wallpaper generator" keywords
- **Target: 10-20K DAU**

### Phase 3: Western Expansion (Month 4-6)
- English-language content marketing
- Instagram/TikTok ads targeting US/UK customization interests (if ROI-positive)
- Partner with Western setup/customization influencers
- **Target: 30-50K DAU, 25%+ Western users**

### Phase 4: Scale (Month 6-12)
- Creator economy flywheel
- Referral system with coin rewards
- Cross-promotion partnerships
- **Target: 60-80K DAU, $10K/mo revenue**

---

## Key Metrics & Targets

| Metric | Current | Month 1 | Month 3 | Month 6 | Month 12 |
|--------|---------|---------|---------|---------|----------|
| **DAU** | ~500-800 | 2,000 | 10,000 | 30,000 | 60,000+ |
| **MAU** | ~2-3K | 8,000 | 40,000 | 120,000 | 250,000+ |
| **Day 1 retention** | 18.8% | 30% | 35% | 40% | 40%+ |
| **Day 7 retention** | ~5% | 12% | 18% | 20% | 22%+ |
| **Day 30 retention** | ~3% | 8% | 12% | 15% | 15%+ |
| **DAU/MAU** | 5-8% | 15% | 20% | 25% | 25%+ |
| **Western users %** | ~5% | 10% | 20% | 30% | 30%+ |
| **Monthly revenue** | ~$0 | $200 | $2,000 | $5,000 | **$10,000+** |

---

## Bottom Line

**The data is clear**: Prism can attract users (222K lifetime, 7.4K in a single day during the spike) but can't keep them (18.8% Day 1, ~3% Day 30). The 3.0 strategy must be **retention-first, then growth**. Build the daily hooks (Wall of the Day, streaks, AI, coins), prove retention improves to 30%+ Day 1, then pour fuel on the fire with growth campaigns. Without this order, any marketing spend is wasted — just like the Nov 2021 spike was.
