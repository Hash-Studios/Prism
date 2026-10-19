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
| `pushes.{kind}` | `sendDropPushes` | Time a push kind was sent. The claim makes each push send once. |

Client phase (`DropPhase`): `live`, then `lastCall` in the final 24 hours, then `ended`.

## Pushes

`sendDropPushes` runs every hour. A table holds each push kind and the time it is due:

| Kind | Due | Copy intent |
|---|---|---|
| `live` | `startsAt` + 4 h (10:00 IST on Monday) | A new Drop is live, how many walls, ends Sunday. |
| `lastCall` | `endsAt` - 12 h | Last call, the Drop ends tonight. |

Each push goes to the FCM topic `drops`, with an inbox doc (`modifier: all`, fixed doc id) and the route `drops`. The client subscribes to `drops` by default and has a "Weekly Drops" switch in notification settings. Android channel: `drops`.

## Preview

Tap a locked wall to open a full-screen pager over the Drop. It shows the wall in a phone frame with a lock-screen clock, a foil watermark and the unlock buttons. No save, set, share or download action exists on this page.
