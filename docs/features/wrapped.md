# Prism Wrapped

Prism Wrapped 2026 is a short set of full-screen story cards about a user's year in Prism. It shows walls saved, top colours, the top creator, the longest daily run, AI walls, the top category, folders, and other stats. The user can share each card as a 9:16 image.

Only users with real activity get Wrapped. The app never shows an empty card or a card with a zero.

## How a Wrapped is built

A server job builds one private document for each eligible user: `wrapped/{uid}/years/2026`. The client never writes it.

| Part | Rule |
|---|---|
| Code | `functions/src/wrapped.ts` (reads and stats), `functions/src/scripts/buildWrapped.ts` (the job). |
| Window | From 1 January 2026 00:00 UTC to the time the build starts. A resumed run keeps the end time of the first run. |
| Actions | Saves + AI walls + folders made + challenges entered + tips sent, all inside the window. |
| Eligibility | 10 actions or more, and 4 stat cards or more. Ten is the smallest count that fills the colour and category cards with 3 or more walls each. |
| Cards | Intro, then 4 to 7 stat cards in a fixed order, then the summary. That gives 6 to 9 cards. |
| Weak stats | A stat below its minimum gets no card. The minimums are in `SIGNALS` in `wrapped.ts`. |
| Late signals | A stat whose data starts after 1 January carries `since` (a date). The copy then says "Since Oct 27", not "this year". |
| Heroes | Each card shows one of the user's own walls: a save, an AI wall, or a folder cover. Cards in a row do not repeat a wall when the user has enough walls. |
| Accents | The user's top 3 colours (palette ids). The story uses the first one for its labels. |

### Stats and their sources

| Card | Value | Source | Starts |
|---|---|---|---|
| Saves | Walls saved | `usersv2/{uid}/images`, on `favouritedAt`, else `createdAt` | 1 Jan (count can be low, see below) |
| Colours | Top 3 colours of saved Prism walls | `walls.colors` | 1 Jan |
| Creator | Most saved creator, not the user; only the public username is stored | `walls.creatorUid`, then `profiles/{uid}` | 1 Jan |
| Streak | Longest run of days with a daily claim, using the user's currently stored fixed UTC offset | `coinTransactions`, `action: dailyLogin` | 2 Mar 2026 |
| AI | AI walls made | `aiGenerations`, `userId` | 19 Feb 2026 |
| Category | Most saved category, not General | `walls.category`, else the save's `category` | 1 Jan |
| Folders | Folders made | `folders`, `ownerId` | 27 Oct 2026 |
| On your screen | Sets and downloads of one saved wall | `usersv2/{uid}/wallActionReceipts`, `counted: true` | 30 Oct 2026 |
| Challenges | Weekly challenges with an approved entry | `entries` collection group, `creatorUid` | 30 Oct 2026 |
| Tips | Tips sent | `coinTransactions`, `action: tipSent` | 1 Nov 2026 |

Before 8 October 2026, a Prism save stored the wall's upload date in `createdAt`, not the save date. At a build time in 2026, that fallback cannot count a save made in a later year, so it is a lower-bound count. If the job is restarted after 2026, a post-year save may be attributed to 2026 because its actual save date is unavailable. Do not treat a post-year rebuild as exact.

Ties use the higher count, then the most recent save, then the id. Colours score 3, 2 and 1 by dominance, and ties use the palette order.

## The job

```sh
cd functions
npm run job:wrapped                     # dry run: reads, writes nothing, prints eligible users
npm run job:wrapped -- --apply          # builds docs; resumes from wrappedRuns/2026
npm run job:wrapped -- --apply --restart  # new build with a new window end; removes docs of users no longer eligible
npm run job:wrapped -- --notify --apply # after a finished build: one push and inbox item for each user
```

The job pages `usersv2` by document id. It moves its checkpoint (`wrappedRuns/2026`) only after every user on the page is written. If it stops, run it again and it continues. It skips deleted accounts. A yearly notification marker on `wrapped/{uid}` survives deletion of the year doc, so a user cannot get the launch push twice after losing and regaining eligibility.

`--notify` atomically claims the yearly marker and creates the inbox item with fixed id (`wrapped_2026_{uid}`) before it sends. A crash can drop one push, but it cannot send two. The push obeys the marketing push setting (`marketingPushes`).

### Read cost

All wall metadata is read once per run, in pages of 500 documents. A full page causes one final empty query to detect the end. The full index remains in memory for lookups. Each user then costs these reads (empty queries still cost one read):

| Read | Cost |
|---|---|
| User page | 1 |
| Saves | `max(1, F) + max(1, C)`, where `F` and `C` are the matching documents in the `favouritedAt` and `createdAt` queries. A document matching both queries is read twice before it is deduplicated. |
| Coin ledger in 2026 | One read per matching row, with a one-read minimum; add one read when the row count is a positive multiple of 500 because the final empty page detects the end. Only one page is held while daily claims and tips are aggregated. Claim days are deduplicated, so at most 367 day keys are retained. |
| AI walls | Count query: `max(1, ceil(index entries / 1,000))`; plus `max(1, latest documents)`. The latest query is limited to one document, so it costs exactly one read whether empty or not. |
| Folders | `max(1, all folders owned by the user)`; the query is not date-bounded, then `createdAt` is filtered in memory. |
| Challenge entries | `max(1, all matching entries for the creator)`; the query is not date-bounded, then state and source-wall `createTime` are filtered in memory. |
| Receipts in 2026 | `max(1, matching receipts)` |
| Top creator | 2, only when there is a top creator: the public profile and account deletion check. |

A user with no activity costs 9 reads, excluding the shared wall index. The 300-save/300-claim case depends on which save timestamps are present: if all saves match both save queries, that is 600 save reads, not 300. Folder and challenge reads also include all-time matching documents.

For 200,000 quiet users, the user pages and per-user signal queries cost about 1.8 million reads, before the shared wall index, apply guards and page checkpoints. A 200,000-wall index adds 200,001 reads because 400 full pages need an empty query to detect the end; its 200,000 metadata entries also remain in memory. The default 200-user page size needs 1,001 checkpoint transactions to finish those users, each with one read and one write, plus one run-state read at start. Every completed build queries one final empty user page, even when its last non-empty page was partial. Apply adds 4 transaction reads and one Wrapped write for each eligible user. On a restart, every ineligible user also incurs 3 transaction reads (the existing Wrapped year doc, parent marker and run state), even if there is no year doc to remove. If a stale year doc exists, it is deleted; if it has a legacy `notifiedAt` value not yet copied to the parent marker, that marker is written too.

`--notify` reads the run state once. Its `years` collection-group scan costs one read per returned document, including paths later skipped, plus one terminal empty query for every completed scan. For each valid unnotified Wrapped doc it reads the user once, reads 5 docs in the atomic claim transaction, and reads the private session once for push settings. When push is enabled and the user is logged in, `sendToUser` additionally reads `usersv2/{uid}` to confirm the account can receive a personal push and reads the private session again for its token. The claim writes the year doc, parent marker, and fixed-id inbox item. Each notify-page checkpoint adds one read and one write. These counts exclude helper push-accounting writes and external FCM delivery.

## Access and deletion

| Rule | Where |
|---|---|
| Only the owner reads `wrapped/{uid}/years/{year}`. Nobody writes it from a client. | `firestore.rules` |
| `wrappedRuns` has no client access (default deny). | `firestore.rules` |
| `deleteAccount` removes `wrapped/{uid}` and all its years. | `functions/src/deleteAccount.ts` |

## In the app

| Part | Rule |
|---|---|
| Code | `lib/features/wrapped/` |
| Gate | Remote Config `wrapped_2026_enabled` (`true` or `false`), `wrapped_2026_start` and `wrapped_2026_end` (ISO dates, local days, end included). Defaults: off in release builds, 1 December 2026 to 15 January 2027. |
| Home card | A page in the Home carousel, after the Wall of the Day. It shows only inside the window and only when the user has a Wrapped. |
| Deep links | `prism://wrapped` and `https://prismwalls.com/wrapped`. A user with no Wrapped sees a short message and goes back. |
| Story | Tap the right two thirds for the next card, the left third for the previous card. Hold to pause. Swipe down to close. A card moves on after 6 seconds. |
| Reduced motion | With reduced motion or a screen reader on, the story does not move by itself and has no transitions. Previous and next buttons show. |
| Screen readers | Each card reads "Card N of M" and its full text. |
| Share | Each card and the summary share as a 1080 x 1920 image through the share sheet (Instagram Stories, save, more). The image holds the card text, the user's walls, the Prism logo and `prismwalls.com`. It holds no name, email or uid. The copied link is `https://prismwalls.com/wrapped`. |
| Analytics | `wrapped_opened` (source), `wrapped_card_viewed` (card id), `wrapped_card_shared` (card id, target), `wrapped_finished`, `wrapped_not_eligible` (source). |
| QA | Debug builds with `--dart-define=WRAPPED_QA_OPEN=true` show the Home card outside the window. `tool/wrapped_qa/seed.cjs` seeds three demo accounts on the emulators. |

## Launch order

1. Deploy `firestore.rules` and `firestore.indexes.json` (the new `entries.creatorUid` collection group index).
2. Deploy functions (`deleteAccount` must remove Wrapped before any doc exists).
3. Deploy the Cloudflare Worker, so `prismwalls.com/wrapped` opens the app.
4. Run the job with `--apply`, after the owner's OK.
5. On 1 December, set `wrapped_2026_enabled` to `true` in Remote Config.
6. Run the job with `--notify --apply`.
