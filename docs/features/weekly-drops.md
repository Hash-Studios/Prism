# Weekly Drops

A Drop is a small set of Studio walls that the user can buy with coins for one week only. After 30 days the walls go to the public feed.

## Goals of the 2026-10 redesign

1. A Drop must look like a limited, collectible object, not a list row.
2. Users must know that a Drop exists: push, inbox, the home carousel and the top of Rewards.
3. A user can see a locked wall full size before they pay. They cannot save or set it.

## Data

| Field (`drops/{weekKey}`) | Owner | Meaning |
|---|---|---|
| `walls[]`, prices, `startsAt`, `endsAt` | `planWeeklyDrop` | As before. |
| `collectors` | `unlockDrop` | Users who own at least one wall of this Drop. Plus one on a user's first unlock of the Drop only. |
| `pushes.{kind}` | `sendDropPushes` | Time a push kind was sent. A sent kind is never sent again. |
| `pushClaims.{kind}` | `sendDropPushes` | Time a run took the send. A claim older than 15 minutes with no sent time is taken again, so a run that died is retried. |

Client phase (`DropPhase`): `live`, then `lastCall` in the final 24 hours, then `ended`.

## Which walls a Drop gets

A Drop has 4 to 10 walls. The planner selects ready walls round-robin by series, up to 10 walls. If only one series has ready walls, that series can fill the Drop.

`planWeeklyDrop` runs on Monday at 00:30 UTC. It reads all ready reserves: `dropReserved: true`, `review: false`, `origin: studio`, `releaseAt` reached, and a verified proof for a live wall. Then it uses this rule:

- The planner takes the walls round-robin by `seriesId`. Each series gives its oldest wall. Then each series gives its second-oldest wall, and so on, until the Drop has 10 walls.
- If only one series has ready walls, the Drop still gets them. A week with 4 or more ready walls always gets a Drop.
- A reserve that the Drop does not use keeps `dropReserved: true`. It waits for the next Drop. In that Drop, it is the first wall of its series, so it cannot wait forever.

### Theme week

An admin can give one Drop a theme series: `studioConfig/current.dropSeries[weekKey] = seriesId`, for example `{"2026-W50": "winter-light"}`.

- When the week has a theme, the planner takes only ready walls of that series, oldest first, up to 10. Other reserves keep `dropReserved: true` and wait for the next Drop.
- When the theme series has fewer than 4 ready walls, the planner logs `drops: the theme series has too few ready walls; using the mixed pick` with the count. Then it uses the normal round-robin pick over all series.
- A theme that names an unknown series is ignored. The week gets the normal pick.
- The plan transaction reads the theme again. If the theme changed after the first read, the run fails and writes nothing. The scheduler retries once and picks again with the new theme. Studio's upcoming-Drop week-key boundary is Monday 00:30 UTC, the time this planner runs.
- The reserves for the themed Drop come from the theme series only. See "Weekly Drop reserve" in the Studio doc.
- The theme does not change the prices or the pushes. To name the Drop, call `setDropTitle` with the week key, for example `"Winter Drop"`. The planner then writes that title. The last call push shows the title. The live push title stays "A new Drop is live", because installed apps localize it from a fixed key. Its body shows the 3 tags that most walls share (moods, Vision labels and collections). For a Winter Drop these are likely snow labels, but no test proves it.

Studio limits the reserves at the source. Studio reserves a wall only when its series has fewer than 3 walls that wait for a Drop (`STUDIO_DROP_SERIES_CAP`). See the Studio doc.

Before the fix, Studio reserved the first wall that it published each day. After Dark always publishes first, so all Drops were dark.

## Pushes

`sendDropPushes` runs every hour at minute 30 UTC. A table holds each push kind and the time it is due:

| Kind | Due | Copy intent |
|---|---|---|
| `live` | `startsAt` + 4 h (04:30 UTC, 10:00 IST on Monday) | A new Drop is live, how many walls, ends Sunday. |
| `lastCall` | `endsAt` - 12 h | Last call, the Drop ends in the real hours left (at least 1). |

Each push goes to the FCM topic `drops`, with an inbox doc (`modifier: all`, fixed doc id) and the route `drops`. The client subscribes to `drops` by default and has a "Weekly Drops" switch in notification settings. Android channel: `drops`.

## Device proof

Android emulator (2026-11-13, signed in): `prism://drops` opened the live Drop with its name, dates, and walls in full with a lock and price. One wall was unlocked for 30 coins and set on the home screen.

## Preview

Tap a locked wall to open a full-screen pager over the Drop. It shows the wall in a phone frame with a lock-screen clock, a foil watermark and the unlock buttons. No save, set, share or download action exists on this page.
