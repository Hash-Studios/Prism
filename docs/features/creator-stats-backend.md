# Creator stats backend

## Contract

`getCreatorStats` requires Firebase authentication. Send `{}`. The function rejects all other input, including UID, email, and wall identity overrides. It uses only `request.auth.uid`.

The response follows `creator-stats-plan.md`. It has schema version 1, UTC timestamps, creator totals, coverage, exactly eight ISO UTC weeks, and all approved wall rows. The current partial week is last. Each wall has the same eight boundaries. `wallId` is the canonical Firestore wall document ID. `title` and `thumbnailUrl` come from that wall.

Only `walls` with `creatorUid == callerUid` and `review == true` qualify. `creatorUid` is the existing server-owned, verified ownership field. Email is not ownership proof. The account must exist, must not have `deleted == true`, and must not have a closed `creatorDeletionState` barrier. Each callable transaction reads these gates, even for a cache hit. A concurrent gate change causes Firestore to retry the transaction.

Saves totals are current favourites. Weekly saves are additions. Remix totals use the existing live `remixCount`. Weekly remixes count first accepted credits after instrumentation. Folder additions count source item creations. They do not count current folder membership. Missing history stays `null`. A creator sum stays `null` if any approved wall has an unavailable value for that metric. Empty creators have zero totals and eight empty weeks.

Lifetime counters come from `wallpaper_stats/{normalizedId}`. One shared transaction query projects only `id`, `creatorUid`, and `review` from every current global wall, including drafts and withdrawn walls. It normalizes each ID with the existing trim-and-uppercase function. Exactly one current wall must have that identity, and its source path must match the caller's approved wall. Mixed-case and whitespace collisions make lifetime counters unavailable and block shared daily projection. A stats document that predates the wall incarnation also returns unavailable counters. Legacy digit strings are parsed. Missing or invalid individual counters, including `remixCount`, return `null`; a recorded zero remains zero.

The identity census is limited to 20,000 global wall documents plus one overflow sentinel. Overflow returns `resource-exhausted`, even for a warm cache. The separate creator limit remains 500 approved walls. No normalized index or backfill is required. This census proves current identity uniqueness. It cannot reconstruct deleted historical aliases or repair contamination already present in legacy shared counters. Existing counters and trending remain untouched.

## History and event safety

`creatorStatsHistory/{sha256(wallPath + creationTime)}` holds one private document per wall incarnation. It stores the source path, creation incarnation, verified creator UID, first observation time, cumulative folder additions, and at most nine ISO week maps. The extra week keeps the previous complete week available at the Monday boundary. Responses return only eight weeks. A write prunes the map. Old inactive documents can retain nine old keys, but cannot grow without a write.

`onCreatorStatsDailyWritten` uses the current daily source when its incarnation still matches. If TTL has removed it or the path now has a new incarnation, it uses the trusted event after-image. This preserves a real final counter update even if TTL ran before delivery. The transaction reads the source, resolves its unique wall, checks the creator account and deletion barrier, then reads history and a checkpoint. Each checkpoint key includes the daily source path and creation incarnation. The checkpoint stores the greatest accepted value for each daily counter. Only positive differences enter history. The same transaction writes the checkpoint and history. A failure writes neither. Retry, out-of-order event delivery, and repeated source values cannot add the same delta twice.

Daily TTL deletion events do nothing. Delayed update events can still project their recorded after-images. History and checkpoints have no TTL. A newly created daily document at the same path has a new checkpoint incarnation. A daily source older than a recreated wall cannot attach to the new wall. No job reconstructs expired daily data. A first projection can retain real values still present in a daily source. It does not claim complete coverage of that old week.

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

A normal shared daily projection needs `M + 5` reads and two writes. A no-delta replay has the same reads and zero writes. An ambiguous ID stops after `M + 1` reads. A TTL deletion event costs zero reads. A legacy folder creation without a wall document ID needs `M + 7` reads and two writes. A folder creation with an explicit document ID costs eight reads and two writes without a census. A repeated folder marker needs two reads and no writes. The remix extension adds four reads and two writes for a new first credit, three reads and no writes for a known marker, or three reads and one marker write for a legacy credit. Existing remix chain and notice costs remain separate.

The daily trigger must census once per transaction attempt because shared daily documents contain no canonical wall reference and the current schema has no normalized identity index. No process cache can safely substitute for this transactional proof. At 20,000 global walls, a daily update can cost 20,005 reads, plus retries. That background cost is a material rollout limitation. A future identity index or canonical event source is needed before high-volume use; this change does not pretend that the callable cache reduces trigger cost.

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

A first delivery for N approved walls costs `2N + 5` reads and two writes. At 500 walls it costs 1,005 reads. A duplicate delivery costs one marker read. The scan itself reads each approved wall once, plus the minimum empty final page if applicable. A creator can appear in several pages. Its committed marker makes later visits cheap. A failed creator does not stop other creators in the scan. The job reports failures after the scan so the scheduler can retry. A very large scan can require future partitioning to fit the scheduler timeout. There is no bulk creator refresh on the callable path.

## Delivery and proof

Deploy rules, indexes, and Functions, in that order, before the store build that calls `getCreatorStats`. New indexes and TTL configuration must be ready first. The rules deny direct reads and writes for all six private creator stats collections. The new composite index supports the approved creator wall query. No existing client write is tightened.

No deploy, production action, data migration, dependency change, or push was performed. Feature commits and review fixes are local. The parent owns final full Flutter CI and device proof.

See `creator-stats-review.md` for the independent review findings, current test results, and remaining proof limits.

## Capacity failures in triggers

Daily and legacy-folder triggers log and acknowledge identity-census overflow. They do not advance a checkpoint or marker. Transient errors still retry. A later source update can recover its cumulative daily count while that source exists. If daily TTL deletes it first, the skipped history cannot be recovered by these triggers. Recorded history can therefore contain a gap. The callable still returns an explicit capacity error.

Do not deploy projection without an agreed event-volume/read budget. At the 20,000-wall cap, 10,000 daily changes require 200,050,000 reads before retries. No production volume was inspected in this task.
