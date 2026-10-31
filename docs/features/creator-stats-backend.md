# Creator stats backend

## Contract

`getCreatorStats` requires Firebase authentication. Send `{}`. The function rejects all other input, including UID, email, and wall identity overrides. It uses only `request.auth.uid`.

The response follows `creator-stats-plan.md`. It has schema version 1, UTC timestamps, creator totals, coverage, exactly eight ISO UTC weeks, and all approved wall rows. The current partial week is last. Each wall has the same eight boundaries. `wallId` is the canonical Firestore wall document ID. `title` and `thumbnailUrl` come from that wall.

Only `walls` with `creatorUid == callerUid` and `review == true` qualify. `creatorUid` is the existing server-owned, verified ownership field. Email is not ownership proof. The account must exist, must not have `deleted == true`, and must not have a closed `creatorDeletionState` barrier. Each callable transaction reads these gates, even for a cache hit. A concurrent gate change causes Firestore to retry the transaction.

Saves totals are current favourites. Weekly saves are additions. Remix totals use the existing live `remixCount`. Weekly remixes count first accepted credits after instrumentation. Folder additions count source item creations. They do not count current folder membership. Missing history stays `null`. A creator sum stays `null` if any approved wall has an unavailable value for that metric. Empty creators have zero totals and eight empty weeks.

Lifetime counters come from `wallpaper_stats/{normalizedId}`. One shared transaction query projects only `id`, `creatorUid`, and `review` from every current global wall, including drafts and withdrawn walls. It normalizes each ID with the existing trim-and-uppercase function. Exactly one current wall must have that identity, and its source path must match the caller's approved wall. Mixed-case and whitespace collisions make lifetime counters unavailable and block daily queue attribution. A stats document that predates the wall incarnation also returns unavailable counters. Legacy digit strings are parsed. Missing or invalid individual counters, including `remixCount`, return `null`; a recorded zero remains zero.

The identity census is limited to 20,000 global wall documents plus one overflow sentinel. Overflow returns `resource-exhausted`, even for a warm cache. The separate creator limit remains 500 approved walls. No normalized index or backfill is required. This census proves current identity uniqueness. It cannot reconstruct deleted historical aliases or repair contamination already present in legacy shared counters. Existing counters and trending remain untouched.

## History and event safety

`creatorStatsHistory/{sha256(wallPath + creationTime)}` holds one private document per wall incarnation. It stores the source path, creation incarnation, verified creator UID, first observation time, cumulative folder additions, and at most nine ISO week maps. The extra week keeps the previous complete week available at the Monday boundary. Responses return only eight weeks. A write prunes the map. Old inactive documents can retain nine old keys, but cannot grow without a write.

`onCreatorStatsDailyWritten` enqueues a durable work item. Its key is `sha256(sourcePath + ":" + incarnation)`, where the incarnation uses the source creation timestamp's seconds and nanoseconds. The trigger reads the current source and checkpoint before it reads the queue. It coalesces per-field maxima and preserves the first queue time. It does not write history or run the global identity census. A replay with no value above the checkpoint stops after two reads and zero writes. A positive delivery costs three reads and at most one write. A duplicate already represented by the queue costs three reads and zero writes.

Daily TTL deletion events do nothing. Delayed after-images remain projectable after source deletion. The processor uses the durable queue, not the daily source. A recreated source gets a separate key. History, queue and checkpoints have no TTL. Enqueueing creates no history or coverage. A first successful projection sets the history `from` time. It does not claim complete coverage of the old week.

The scheduler runs every minute in UTC. It takes a 600-second lease, processes sequential batches of at most 100 oldest-ready items, and starts no batch after its 240-second soft budget. Its timeout is 540 seconds. Each transaction checks the lease token, reads queue items and checkpoints before one shared identity census, then deduplicates creator gates and history reads. It folds contributions for the same wall into one history write. Batch transactions use one attempt. A transient failure leaves that batch for a later invocation. A poison item is blocked without advancing its checkpoint; other walls can commit. A capacity overflow keeps the queue and checkpoint unchanged and sets a 15-minute cooldown. Queue growth coalesces by source incarnation and does not move an item to the back when its counters rise.

Each queue item is capped at 4 KiB, each checkpoint at 2 KiB, each resulting history document at 16 KiB, and the application write plan at 4 MiB. A full batch has at most 300 writes. Queue items, checkpoints, and processor state have no TTL, so work survives processor downtime beyond the 14-day daily-source retention. History keeps its existing nine-week pruning behavior. The queue index sorts by state, first enqueue time, then document ID. Payload fields are exempt from single-field indexing. Only the existing creator-stats cache TTL remains configured.

The first history observation sets `from`. An existing recorded week value is returned even if that week has partial coverage. An absent metric is zero only for a week that starts at or after `from`. Earlier absent values remain `null`. `coverage.weeklyFrom` is the latest observation start across all approved walls, or `null` if any wall has no history. Folder `totalFrom` is the earliest observation start across those walls. This describes recorded coverage, not the original wall publication date.

`onCreatorStatsFolderCreated` runs only on `folders/{folderId}/items/{itemId}` creation. It checks the source owner against the folder owner, the owner account and deletion barrier, the Prism provider, the source ID, the canonical wall document, approval, the creator account and barrier, and creation order. A supplied wall document ID never falls back to another wall. A legacy item without a document ID needs a unique normalized wall ID match. A marker key includes source path and source creation incarnation. The marker and history update commit together. Updates and deletions do not decrement the count. There is no folder backfill.

The existing remix accepted-credit transaction also reads a durable first-credit marker. The marker uses the remix source path and creation incarnation. The first new acceptance adds one weekly credit to the original and writes the marker in that transaction. Withdrawal and reapproval still change live `remixCount`, but do not add another weekly credit. An existing live ledger or notice from before instrumentation gets a marker with no history increment. This avoids inventing history on replay. A reused legacy remix path with an old notice also stays conservative. It does not fabricate a new weekly credit. No challenge-entry path exists or was added.

The existing daily counters, fourteen-day retention, favourite aggregation, trending calculation, and live remix counter behavior remain in place.

## Cache and capacity

Each wall cache key includes caller UID, canonical source path, wall creation incarnation, logical ID, wall display fields, live remix count, and unique-ID eligibility. A hit is valid for less than five minutes and within the same ISO week. The function rechecks approved ownership and normalized identity uniqueness through the shared census in the same transaction. Cache data is never read directly by a client.

There is one cache document per wall fingerprint. Each document is limited to 12,000 JSON bytes before Firestore metadata. TTL on `expireAt` removes stale cache documents. Each response is limited to 3 MiB of JSON. The callable reads at most 501 approved creator walls and 20,001 global identity rows. It serves all 500 supported walls, or returns `resource-exhausted`. It never returns partial totals. Excess wall count, excess cache row size, excess response size, or unsafe aggregate integer size produces that explicit error.

The callable processes at most ten wall tasks at once. All reads precede cache writes. A cold 500-wall call writes at most 500 cache documents. Firestore transaction conflicts can retry the full operation. There is no shared process cache or promise that can cross creator identities.

[Firestore transaction limits](https://firebase.google.com/docs/firestore/manage-data/transactions) include a 10 MiB request limit, a 20-second lock deadline, a 270-second total limit and a 60-second idle limit. Document and modified index entry sizes contribute to the transaction request. The cache and response byte caps bound application JSON; they are not a measurement of protobuf or index bytes. Excluding the cached row from indexes limits index growth. The real emulator accepts the supported 500 writes and maximum census, but cannot prove production latency under contention.

## Read costs

These counts are document reads for one successful transaction attempt. They include missing document reads and the minimum one read for an empty query. They exclude network transfer, index entry billing, Firestore internal retries, and rule reads. Admin SDK operations do not run client rules.

Let M be all current global wall documents and N be the caller's approved walls. M includes drafts, foreign creators, invalid IDs, and aliases. For a nonempty caller, one shared projected census reads M rows. Each caller wall reads its eligibility row and cache document. A cold unique wall also reads history and lifetime stats.

- Cold upper bound is `2 + M + 4N`. With M=N=500, this is **2,502 reads** and at most **500 cache writes**.
- Warm bound is `2 + M + 2N`. With M=N=500, this is **1,502 reads** and zero writes.
- Mixed upper bound is `2 + M + 2N + 2C`, where C is cold caller walls. Ambiguous or invalid IDs skip the lifetime stats read.
- With M=20,000 and N=500, cold and warm bounds are **22,002** and **21,002** reads respectively. The old numbers 2,502 and 1,502 apply only when the global census contains exactly those 500 caller walls.
- An empty creator costs three reads and skips the census. Creator overflow costs 503 reads and stops before the census. Global overflow costs `2 + N + 20,001` reads and stops before wall caches.
- Each retry repeats that attempt's reads. With R complete attempts, the cold upper bound is `R * (2 + M + 4N)`. The SDK normally permits five attempts. Contention or a cache expiry can make a warm retry cold.

The fake database observer measures both the M=N=500 case and 500 caller walls plus a foreign alias. Real emulator capacity checks execute a 500-wall cold transaction, a warm transaction, four concurrent cold refreshes, and warm withdrawal and alias invalidation. These are local test observations, not production billing measurements.

A daily trigger attempt with no new counter delta costs two reads and zero writes. A new positive candidate costs three reads and at most one write. Raising a counter maximum in an existing queue item also costs three reads and one write. A duplicate already represented by the queue costs three reads and zero writes. The processor's batch cost for K queue items, U distinct eligible creators, H distinct histories, P accepted items, and M census rows is `1 + 2K + M + 2U + H` reads and `K + P + H` writes. Reads are at most `M + 5K + 1`; writes are at most `3K`. A batch with no positive deltas skips the census and costs `1 + 2K` reads and K deletes. Lease acquire and release add two reads and two writes per invocation. An empty terminal batch adds two reads. For M=20,000 and 10,000 positive events, 100 full batches cost about 2,050,100 processor reads plus 30,000 trigger reads, for about 2,080,100 reads total before invocation overhead. The prior per-event census estimate of 200,050,000 reads no longer applies.

A positive batch uses one census for up to 100 queue items. It still has a capacity and lock-contention cost, so production volume and latency remain unmeasured. Capacity overflow retains the batch and cools down the scheduler for 15 minutes. No claim is made about production billing or latency.

## Monday inbox

`creatorStatsWeekly` runs at 09:00 UTC each Monday. It uses the schedule time to select the previous complete ISO week. It scans all approved walls in pages of 100, then checks each creator. It has no account-recency filter. A creator needs at least one approved wall with recorded activity in that week. The creator account, deletion barrier, current approved walls, and `usersv2/{uid}/private/session.postAlerts` are checked in the delivery transaction. As in the existing remix inbox path, an explicit `false` opts out. The current account email is the inbox `modifier`.

The inbox item and `creatorStatsWeeklyMarkers/{sha256(uid + week)}` are created in one transaction. Concurrent runs and retries cannot create a second inbox item. There is no push send. `pushHandled` is `true`.

The client copy contract is exactly:

```json
{
  "notification": {
    "title": "Your walls this week",
    "body": "See how your walls did in 2026-W43."
  },
  "message": {"kind": "creatorStatsWeekly", "args": {"week": "2026-W43"}},
  "data": {
    "route": "creator_stats",
    "url": "prism://creator-stats",
    "pageName": "",
    "arguments": [],
    "imageUrl": "",
    "notification_kind": "creator_stats_weekly"
  },
  "modifier": "creator@example.com",
  "pushHandled": true
}
```

`week` is an ISO UTC week string. The backend native push localization helper returns `null` for this inbox-only kind. The app owns localization and deep-link handling.

A first delivery for N approved walls costs `2N + 5` reads and two writes. At 500 walls it costs 1,005 reads. A duplicate delivery costs one marker read. The scan itself reads each approved wall once, plus the minimum empty final page if applicable. A creator can appear in several pages. Its committed marker makes later visits cheap. A failed creator does not stop other creators in the scan. A creator over the 500-wall capacity is logged and skipped, because a retry would fail the same way. The job reports other failures after the scan so the scheduler can retry. A very large scan can require future partitioning to fit the scheduler timeout. There is no bulk creator refresh on the callable path.

## Delivery and proof

Deploy rules, then indexes and TTL configuration, and wait until the queue index is ready. Deploy Functions next, then configure the Cloudflare deep-link bindings, before the store build that calls `getCreatorStats`. The rules deny direct reads and writes for all eight private creator stats collections. The queue composite index supports oldest-ready processing. There is no TTL on queue, checkpoints, processor state, or history. No existing client write is tightened.

No deploy, production action, data migration, or dependency change was performed. Full gates and device proof are recorded in `creator-stats-proof.md`.

See `creator-stats-review.md` for the independent review findings, current test results, and remaining proof limits.

## Capacity failures in triggers

The processor acknowledges identity-capacity overflow after preserving the current batch and setting its cooldown. Transient errors leave the batch for a later run. Malformed items and items with identity or arithmetic failures are blocked without checkpoint advancement. Missing, ambiguous, unapproved, older-than-wall, and inactive-owner candidates are deleted without advancing checkpoints. Approval alone does not restore deleted work; a later daily source delivery can enqueue it again. Queue and checkpoint documents have no TTL, so queue data survives daily-source expiry and long processor downtime. Legacy folder triggers still acknowledge identity-capacity overflow without advancing their marker; transient failures retry. They do not have a durable queue, so later folder recovery depends on a later source event.

The callable still has the 20,000 global wall limit and 500 creator-wall limit. The processor uses the same bounded global census once per positive batch. Each census can hold locks on up to 20,001 wall documents until commit. Production event volume and latency have not been measured. The batch design reduces repeated census reads; it does not prove production cost or contention safety.
