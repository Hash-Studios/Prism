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

A Drop has 4 to 10 walls. The walls must be from different series, so that one series cannot fill the Drop.

`planWeeklyDrop` runs on Monday at 00:30 UTC. It reads all ready reserves: `dropReserved: true`, `review: false`, `origin: studio`, `releaseAt` reached, and a verified proof for a live wall. Then it uses this rule:

- The planner takes the walls round-robin by `seriesId`. Each series gives its oldest wall. Then each series gives its second-oldest wall, and so on, until the Drop has 10 walls.
- If only one series has ready walls, the Drop still gets them. A week with 4 or more ready walls always gets a Drop.
- A reserve that the Drop does not use keeps `dropReserved: true`. It waits for the next Drop. In that Drop, it is the first wall of its series, so it cannot wait forever.

Studio limits the reserves at the source. Studio reserves a wall only when its series has fewer than 3 walls that wait for a Drop (`STUDIO_DROP_SERIES_CAP`). See the Studio doc.

Before the fix, Studio reserved the first wall that it published each day. After Dark always publishes first, so all Drops were dark.

## Pushes

`sendDropPushes` runs every hour at minute 30 UTC. A table holds each push kind and the time it is due:

| Kind | Due | Copy intent |
|---|---|---|
| `live` | `startsAt` + 4 h (04:30 UTC, 10:00 IST on Monday) | A new Drop is live, how many walls, ends Sunday. |
| `lastCall` | `endsAt` - 12 h | Last call, the Drop ends in the real hours left (at least 1). |

Each push goes to the FCM topic `drops`, with an inbox doc (`modifier: all`, fixed doc id) and the route `drops`. The client subscribes to `drops` by default and has a "Weekly Drops" switch in notification settings. Android channel: `drops`.

## Preview

Tap a locked wall to open a full-screen pager over the Drop. It shows the wall in a phone frame with a lock-screen clock, a foil watermark and the unlock buttons. No save, set, share or download action exists on this page.
