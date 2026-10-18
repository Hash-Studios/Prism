# XP and creator milestones

XP measures lifetime progress and weekly leaderboard activity. Coins remain a spendable balance. Changing a coin payout, buying Pro, or receiving a larger random payout does not increase the XP for the same activity.

## Fixed activity awards

These are code defaults. The economy configuration can change activity XP independently of coin payouts.

| Activity | XP |
| --- | ---: |
| Daily streak claim | 5 |
| Complete day seven of a streak | 25 extra |
| Daily quest | 25 |
| Weekly quest | 150 |
| Daily quest chest | 10 |
| First valid wallpaper submission | 50 |
| Profile completion | 25 |
| Week Warrior badge | 25 |
| Streak Master badge | 100 |
| AI Artist badge | 30 |
| Prism Veteran badge | 75 |

Ads, paid or free wheel spins, the legacy Pro spin and daily bonus, referrals, refunds and purchases award no XP. The bonus quest can still double chest coins. It does not double chest XP. The Creator badge keeps its coin reward; creator milestones now award its future XP.

The wheel's former XP slots pay 1 and 2 coins. Other prizes and odds stay the same. A configured wheel containing XP slots falls back to the coin-only default table. Historical spin receipts retain their original results; replaying one cannot award XP again.

Historical XP and owned rewards remain intact. Rank thresholds remain unchanged. The legacy `perCoinEarned` configuration field remains readable for installed clients, but the new server and client do not use it to award XP.

## Creator awards

Creator milestones count eligible approved wallpapers and eligible member accounts that first favourite a creator's work. A member counts once across all of that creator's wallpapers and all weeks. These are historical contribution counts, not current favourites or wallpaper usage.

| Approved wallpapers recorded | XP at this milestone |
| --- | ---: |
| 1 | 50 |
| 5 | 100 |
| 10 | 150 |
| 25 | 250 |
| 50 | 500 |

| Unique members recorded | XP at this milestone |
| --- | ---: |
| 1 | 25 |
| 10 | 50 |
| 25 | 100 |
| 100 | 250 |
| 250 | 500 |

Each milestone pays once. An unfavourite, reapproval or repeated event cannot repeat an award. The first observed approval after rollout can count once even if the wallpaper was approved before tracking began. No historical totals are imported.

The canonical wallpaper must be approved community work with trusted upload ownership evidence. Its assets must match protected upload records and the completed upload's saved URL, path and SHA. Older wallpapers without that evidence do not qualify automatically. A current email address alone cannot prove who uploaded old work.

An audience member must be another active, verified account with a permanent sign-in provider. The account must be at least seven days old when the favourite was created. Self-actions, blocked relationships and ambiguous wallpaper identities do not qualify. At most 20 new creator relationships qualify per member per UTC day. These limits do not restrict saving favourites.

## Consistency and privacy

Dedicated retry-enabled observers process approvals and favourite creations. A single Firestore transaction writes the permanent receipt, contribution totals, milestone XP and rank rewards. Creator/member receipts prove a union across wallpapers. Logical wallpaper receipts prevent a recreated document from earning a second approval award.

Weekly feedback uses the week in which the server records the contribution. Eligibility uses the source favourite's server creation time. Delayed events cannot reset the leaderboard to an earlier week. The private summary keeps the current and previous week. Missing or outdated buckets do not become invented activity.

Account deletion first writes a server-only deletion barrier. Contribution transactions read that barrier so cleanup cannot race with a new award. Cleanup removes identifying contribution receipts and closes wallpaper attribution. Other creators retain their historical counts and XP. A minimal server-only UID deletion barrier remains to reject delayed events.

## Client and release order

Updated award replies include absolute XP, the current weekly XP, a policy version and an awarded amount. The client uses the absolute snapshot after account and freshness checks. It does not add the awarded amount locally. A reply from an older backend triggers reconciliation instead of a coin-based estimate.

Creator feedback uses the private economy refresh path. It is not a live subscription. The client renders the server's milestone catalog and distinguishes missing data from recorded activity.

Deploy the `creatorMembers.memberUid` collection-group index and the daily rate expiry policy first. Wait for the index to become ready before deploying the functions, because account deletion depends on it. Then deploy the functions before releasing the client that describes these earning rules. Deployment and store release are separate actions. This change performs neither. Installed older clients can temporarily show their old optimistic XP estimate until a server refresh corrects it. No production backfill or remote configuration change is included.
