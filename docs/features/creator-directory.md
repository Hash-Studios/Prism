# Creator directory

The creator directory lists public creators. The app shows them in a "Creators to follow" row on Home and Search, and on a See all page. A server job builds the list once a day. The app also shows a "Followed by" line on profiles and a "More like" offer after a follow.

## Where to find it

| Surface | What the user sees |
|---|---|
| Home (For you) | The "Creators to follow" row. It sits four wallpaper rows into the feed. |
| Search, Discover view | The same row. Its source is `search`. |
| Row header | The title and a **See all** action. |
| See all page | The title **Creators**, category chips and infinite scroll. The first chip is **All**. |
| Creator card | Four top walls, the avatar, the name, the follower count and a **Follow** button. |
| Wall tap | Opens the wall. The wall view swipes through the card's walls. |
| Creator profile | A "Followed by" line under the header. It names up to 3 people the viewer follows. |
| Follow toast | After a follow, **More like <name>** appears on the toast. |
| More like sheet | Lists up to 6 similar creators, each with a **Follow** button. Following does not close the sheet. |
| Settings | The switch **Show me in Creators to follow**. Off removes the creator from the directory. |

Guests do not see the row. Guests do not see the "Followed by" line.

## Platforms and plans

Android and iOS. Every plan sees the same directory. No coin, premium or Pro gate applies.

## How it works

### Data

| Path | Writer | Readers | Contents |
|---|---|---|---|
| `creatorDirectory/{uid}` | Server only (`buildCreatorDirectory`, `projectUserProfile`) | Signed-in users | The fields below. |
| `followedByCache/{sha256 of viewer and creator}` | Server only | Nobody | `matches` (uids), `expireAt`. |
| `followedByRateDaily/{viewerUid}` | Server only | Nobody | `day`, `count`, `expireAt`. |

A `creatorDirectory` doc has these fields:

- `uid`, `name`, `followerCount`, `rank`, `updatedAt`.
- `username` and `profilePhoto`, when the profile has them.
- `walls`: up to 4 entries, each with `id` and `thumb`.
- `categories`: up to 3 category names.
- `similar`: up to 12 creator `uid` values.

`rank` is the position in the list. Rank 1 is the top. `updatedAt` is the time of the run that wrote the doc.

The doc holds only public profile fields. Only the Admin SDK writes it. The rules refuse every client write.

### Daily job

`buildCreatorDirectory` runs at 02:30 UTC each day. The code is in `functions/src/creatorDirectory.ts`.

#### Eligibility

A creator is listed when all of these are true:

- The creator has 3 or more public walls.
- One public wall is from the last 60 days.
- The profile exists. The user is not deleted and is not in account deletion.
- The Firebase Auth user is not disabled.
- The creator did not opt out.

A public wall passes `isWotdEligible`. Its original is protected. It is not a drop, not streak-exclusive and not in a premium collection.

#### Ranking

A creator's score is the sum of two parts.

- Wall activity. Each wall adds favourites times 2 and sets times 3, from the last 7 days of `wallpaper_stats_daily`.
- Follow activity. Each new follow edge adds 4, from the newest follow edges.

Each day back counts 0.8 of the day after it. A creator whose first wall is under 30 days old gets its score times 1.25, plus 3.

The job sorts by score. Ties go to the creator with more followers, then to the lower `uid`.

- The top 4 walls are the walls with the most favourites and sets in the last 7 days. Newer walls win ties.
- The top 3 categories are the most common categories across the creator's walls.

#### Similar creators

Each creator gets up to 12 other listed creators. A shared follower adds 2 points. A shared main category adds 1 point. A creator with no points gets no similar creators.

#### Removal

A run deletes the docs of creators that no longer qualify. A profile delete or an opt-out deletes the doc at once.

#### Cost per run

| Read | Cap |
|---|---|
| Approved walls | 50,000 |
| `wallpaper_stats_daily` docs, last 7 days | 50,000 |
| Newest follow edges | 20,000 |
| 3 reads per candidate creator | None |
| 3 more reads per listed creator, in its publish transaction | None |
| 1 read per existing directory doc | None |

Each run writes one doc per listed creator. It deletes one doc per removed creator.

Worked example at today's scale. Today the database has about 2,500 walls, up to about 5,000 daily stat docs, the follow edges and about 100 candidates. That is roughly 8,000 to 12,000 reads and about 100 writes a day. At $0.06 per 100,000 reads and $0.18 per 100,000 writes, the cost is under $0.01 a day.

At 50,000 walls and 20,000 edges, the job reads about 125,000 docs a day. That costs about $0.08 a day.

### Followed by

`getFollowedBy` takes `{creatorUid}`. It returns `{count, people}`. `people` holds up to 3 entries, each with `name` and `photo`. It never returns a uid. It lists only people the viewer follows.

- The caller must be signed in.
- The `creatorUid` must be a string of 128 characters or fewer. It must not contain `/`.
- The viewer's own profile returns `{count: 0, people: []}`.
- The callable scans the viewer's newest 500 follows. It checks the creator's followers in batches of 30.
- It returns nothing when the viewer or the creator is deleted, closed, disabled in Auth, or blocked in either direction.
- It caches the matching uids for each viewer and creator pair for 24 hours. A cache hit re-reads only those follow edges, so an unfollow shows at once.
- It checks each named person live (deleted, closed, disabled, blocked either way) and skips them until 3 pass.
- Every call counts toward 300 lookups per viewer per day. Later calls fail with `resource-exhausted`.

A cache miss costs at most about 500 + 17 reads for the scan, plus about 10 reads for the viewer and creator checks and about 8 reads per named person. A cache hit costs 1 read per cached match, plus the same checks.

### App

The code is in `lib/features/creator_directory/`. The cubit `biz/creator_directory_cubit.dart` holds the row and See all state. The repository `data/creator_directory_repository_impl.dart` reads the directory, the follows and the callable. The views are in `views/`. The See all route is `/creators`.

- The row loads 10 creators from the first page. It removes the creators the viewer already follows, so it can show fewer than 10.
- The row hides while the directory is empty. A guest gets an empty row.
- A failed load shows a message and a **Try again** action.
- The Follow button changes at once. It goes back if the server refuses.
- The See all page loads more creators when less than 600 pixels remain below the list.
- The offer appears only after a successful follow. An unfollow never shows it.
- The app waits up to 2 seconds for the similar creators. If there are none, the toast shows without the offer.
- The offer shows once per app session. It does not come back after an app restart.

### Analytics

| Event | Fields |
|---|---|
| `creators_section_viewed` | `source` |
| `creator_card_followed` | `source`, `creator_id` |
| `creators_see_all_opened` | `source` |
| `creators_category_filtered` | `category` |
| `followed_by_shown` | `count` |
| `similar_creators_shown` | `creator_id`, `count` |
| `similar_creator_followed` | `creator_id` |

## Deploy order

Do these steps in this order, before the store build. Do not deploy from this doc.

1. Rules: `firebase deploy --only firestore:rules --project prism-wallpapers`.
2. Indexes: `firebase deploy --only firestore:indexes --project prism-wallpapers`. This adds the `creatorDirectory` index (`categories` CONTAINS, `rank` ASC). It adds TTL on `expireAt` for `followedByCache` and `followedByRateDaily`. It also adds the `following` `createdAt` field overrides. Wait until the index is built.
3. Cloud Functions: `firebase deploy --only functions:buildCreatorDirectory,functions:getFollowedBy,functions:projectUserProfile --project prism-wallpapers`.
4. One manual run of the job: `gcloud scheduler jobs run firebase-schedule-buildCreatorDirectory-asia-south1 --location asia-south1 --project prism-wallpapers`.

The app hides the row while the directory is empty. So the app can ship before the first run without a broken row.

## Limits

- The directory updates once a day. A new wall or follow shows after the next run.
- The job reads at most 50,000 walls, 50,000 daily docs and 20,000 follow edges. It logs a warning at each cap. Data past a cap does not count.
- The directory does not filter blocks for each viewer. The app hides blocked creators.
- A wall removed after the run leaves the card. The app drops it when it reads the card.
- The "Followed by" line reads only the viewer's newest 500 follows. It shows nothing on error or for a guest.
- The More like offer is not saved. It can show again after a restart.

## How to test

1. Run `cd functions && npm run build && node --test lib/__tests__/creatorDirectory.test.js`.
2. Run `make rules-test`. The creator directory cases check reads, writes and deletes for each role.
3. Run `fvm flutter test test/features/creator_directory`.
4. For a device run against local emulators, follow `tool/creator_directory_qa/README.md`. It seeds creators, follows and a block, runs the real job and checks `getFollowedBy`.
5. After the manual run, open `creatorDirectory` in the console. Check that the docs exist and that rank 1 has the most activity.
6. Sign in and open Home. The row shows creators you do not follow. Tap **Follow**. Check that the toast shows **More like <name>**. Open it and check the sheet.
7. Open a profile you follow others from. Check the "Followed by" line.
8. Sign out. Check that the row is gone.
9. In Settings, turn off **Show me in Creators to follow**. Check that the creator's doc is deleted.

| Area | Files |
|---|---|
| Job, ranking, similar creators, `getFollowedBy` | `functions/src/__tests__/creatorDirectory.test.ts` |
| Rules | `tool/firestore_rules_smoke.mjs` (`creatorDirectory`, `followedByCache`, and opt-out cases) |
| App | `test/features/creator_directory/` (cubit, row, See all, Followed by, More like, repository) |
| Local emulator run | `tool/creator_directory_qa.cjs` |
