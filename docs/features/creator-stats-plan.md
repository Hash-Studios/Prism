# Creator stats implementation contract

This plan records the Day 21 implementation contract. It is not a claim of completed verification.

## Data contract

`getCreatorStats` accepts an empty object and derives the creator from authenticated UID. It returns no viewer identity.

```ts
type Metric = 'views' | 'saves' | 'sets' | 'downloads' | 'shares' | 'folderAdds' | 'remixes';
type Counts = Record<Metric, number | null>;
type Week = {week: string; start: string; endExclusive: string; metrics: Counts};
type Coverage = {weeklyFrom: string | null; totalBasis: 'recordedLifetime' | 'currentMembership' | 'since'; totalFrom: string | null};
type WallStats = {wallId: string; title: string; thumbnailUrl: string; totals: Counts; weeks: Week[]};
type CreatorStats = {
  schemaVersion: 1; generatedAt: string; asOf: string; timezone: 'UTC';
  approvedWallCount: number; totals: Counts; coverage: Record<Metric, Coverage>;
  weeks: Week[]; walls: WallStats[];
};
```

Each response contains exactly eight weeks, oldest first, including the current partial UTC ISO week. Each wall uses the same week boundaries. The app sorts walls by the selected current-week metric and uses the returned data for wall detail. Null means unavailable history. It must never become zero during parsing or aggregation.

Saves total means current favourites. Weekly saves count additions. Remixes total means current credited remixes. Weekly remixes count first accepted credits. Folder additions count source item creations since instrumentation began. Copy explains these differences. No expired history is invented.

## Storage and privacy

Use server-owned `creatorUid` and `review == true` for wall eligibility. Recheck eligibility when serving cached data. Do not use client-editable email as ownership proof. Cache keys include canonical wall identities and creation incarnations. Duplicate stats IDs must not leak another wall's data.

Preserve existing counters, 14-day daily expiry, and trending behavior. Add private durable weekly history through an idempotent daily projection. Use transactionally committed checkpoints and counter increments. Ignore TTL deletions. Add private folder creation markers and first-credit remix markers. Do not backfill folder additions.

Choose a five-minute callable cache over periodic full creator refreshes. Bound queries, concurrency, and cache document sizes. Use one projected global identity census per callable transaction, up to 20,000 walls plus an overflow sentinel. A nonempty creator fails explicitly on global census overflow. Keep the caller limit at 500. Shared daily projection uses the same proof once per event transaction; document its global read cost separately. Support a creator with 500 walls completely. A capacity limit must produce an explicit error, never partial totals. Document the final cold and warm read formulas, including eligibility checks, retries, and background costs separately.

Monday notifications summarize the preceding complete UTC ISO week. Include only creators with an approved wall that had activity. There is no account-recency filter. Use existing post-alert preferences and inbox audience conventions, with `pushHandled: true`. Commit the inbox item and its stable creator/week marker together. No push delivery.

## Throughput checkpoint

- Blocking first steps are complete. Rebase, read-only source tracing, dependency setup, and baseline Functions tests ran.
- Independent workstreams are backend, app, and local verification preparation. Their file ownership is disjoint.
- Backend owns `functions/`, rules, indexes, and backend tests. App owns the feature, entry points, routing, DI, ARBs, analytics, notification client integration, and Dart tests. Verification owns local emulator tooling and startup wiring only.
- Generate localization, analytics, router, and DI outputs under the app owner. Do not run broad builds while another owner generates code. Root reviews and runs final checks on the settled tree.

## Proof and delivery

Run targeted tests, Functions build and all Node tests, `make file-gen`, `make analytics-gen`, and `make ci` in documented CI mode. Run independent Sol review for creator isolation, 500-wall cost, ISO edges, and retry double counts. Root Astra reviews the final tree.

Use only demo Firebase emulators and seeded accounts. Capture Android and iOS dashboard, switch, wall detail, empty state, entries, owner isolation, inbox, themes, and large text. Record the requested clip. Linux has no iOS Simulator. This proof remains blocked unless a Mac becomes available.

Open a PR to master. Do not deploy or merge. State the deploy order as rules, indexes, functions, then the store build. Publish screenshots to `qa/screenshots` as explicitly requested.
