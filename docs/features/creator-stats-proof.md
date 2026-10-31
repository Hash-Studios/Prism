# Creator stats verification

## Earlier implementation evidence

The records below describe the earlier per-event daily projection implementation at the named commits. The durable queue has separate local evidence below.

The final code commit is `be8d33268eb294ace3cd17c48bb1d882e5f25b2a`, a merge of master `2388489f7`. Its starting and ending SHA matched, and the worktree had no tracked changes at either check. Later commits change documentation only.

- `CI=true make ci TEST_FLAGS=--concurrency=4` passed. The full Flutter suite passed 8,374 tests and skipped six. The release checks passed six tests. All preceding Makefile gates passed.
- `cd functions && npm run build && node --test 'lib/__tests__/*.test.js'` passed: 2,316 passed, 23 skipped, 0 failed. ESLint with `--max-warnings 0` passed for every changed Functions source and test.
- `node tool/creator_stats_qa/validate.cjs` and `node --test tool/creator_stats_qa/native.test.cjs tool/creator_stats_qa/seed_test.cjs` passed.
- `seed.cjs` and `assert.cjs` passed against real Auth, Firestore and Functions emulators after the merge and after the daily projection fix.

Earlier results: `58f61ed41`, before the last master merge, passed the same gates with 8,287 Flutter and 2,308 Node tests. Frozen commit `e109d854d` passed `make ci` with 7,789 Flutter tests and 2,228 Node tests. The review record's 2,226 Node tests ran at its own earlier commit.

## Device proof

Evidence is on `qa/screenshots` under [`creator-stats-761-2026-10-31`](https://github.com/Hash-Studios/Prism/tree/qa/screenshots/creator-stats-761-2026-10-31). Every screenshot has a view tree. Both platforms ran on a Mac against the real app, the real `getCreatorStats` callable and demo emulators.

**Android.** AVD `Prism_QA_API36`, Android 16. Real taps covered own profile to Stats, metric switch, the eight-week chart, top wall to that wall's own numbers, the Uploads and Rewards entries, the weekly inbox item to the dashboard, another creator's profile without Stats, dark theme, the largest text size with the chart's screen-reader summary, and the empty creator with its upload link. A clip records profile, Stats, metric switch and top wall.

**iOS.** Simulator `Prism QA iPhone 17 Pro`, iOS 27.0. The same flows and the same clip passed.

Device proof ran on builds of `0ab0d548e` (creator flows) and `387b17adc` (empty state). Later commits change the Monday scan, three locale labels, tests, docs, and two master merges. The last merge adds master's earned-coins line beside the Uploads Stats entry; that screen was not rerun on a device.

The other creator's profile was opened with a `prism://user/qa-stats-other` link, because creator search reads public profiles and the seed creates only two accounts.

## Defects found by device proof

Each fix has a test that fails without it.

- The emulator bootstrap passed Firebase options that differed from the demo native config. Android stopped on a black screen with a duplicate default app error.
- FlutterFire maps `127.0.0.1` to `10.0.2.2` on Android, and the debug network policy refuses cleartext to `10.0.2.2`. The bootstrap now uses the configured host, and Android QA uses `adb reverse`.
- The 41-character demo API key failed native Functions validation, so the callable never reached the emulator.
- Glint stretched to the list width and covered the empty-state copy.
- The seed had no public `profiles` documents, so another creator's profile could not render.

## Review

Astra made the read-cost decision. Sol reviewed the merge, the backend change and the device fixes. Sol added a native config preflight fix and regression tests. CodeRabbit findings were triaged. The Monday scan no longer retries a permanent capacity error. Spanish, Portuguese and Indonesian stat labels are clearer. The census locking finding stays a rollout blocker.

## Current read-cost model

M is all global wall documents, capped at 20,000. N is the caller's approved walls, capped at 500. Counts are per transaction attempt, before retries.

- Callable: cold `2 + M + 4N`, cached `2 + M + 2N`. Unchanged.
- Daily enqueue: a replay with no new value costs 2 reads and zero writes. A new positive candidate costs 3 reads and at most 1 write. Raising an existing queue maximum costs 3 reads and 1 write. A duplicate already represented in the queue costs 3 reads and zero writes.
- Processor: for K items, U distinct eligible creators, H distinct histories, P accepted items and M census rows, a successful batch costs `1 + 2K + M + 2U + H` reads and `K + P + H` writes. Reads are at most `M + 5K + 1`; writes are at most `3K`. All-no-delta batches skip the census and cost `1 + 2K` reads and K deletes.
- At M=20,000 and 10,000 positive events coalesced into 100 full batches, trigger and processor reads total about 2,080,100 before invocation overhead. The earlier 200,050,000 estimate assumed one census per positive event and is superseded.
- Legacy folder creation without a wall document ID: `M + 7`.
- Each census can hold pessimistic read locks on up to 20,001 walls until commit.

The lease adds two reads and two writes per invocation for acquire and release. Capacity overflow keeps the batch unchanged and sets a 15-minute cooldown. The 20,000-wall census and production event volume still need production cost and contention review. These are design estimates, not production billing measurements.
An empty terminal processor batch adds two reads. Legacy folder projection has no durable queue and retains its separate census and capacity behavior.

A safe identity index must stay complete atomically on every wall-writing path, so it is out of scope here. See `creator-stats-backend.md`.

## Durable queue local evidence

The queue change starts at `c13aab249f0a4a8085551cb4387c2ed0ded45557`. All commands ran in `/Users/codenameakshay/.t3/worktrees/Prism/t3-587be36f` on 2026-10-31. The existing local branch is `akshay/creator-stats-daily-queue`, not the requested `akshay/creator-stats-dashboard`. No branch switch or remote write occurred.

- `cd functions && npm run build && node --test 'lib/__tests__/*.test.js'` passed. There were 2,376 tests, with 2,353 passed, 23 skipped, zero failed, and zero cancelled.
- `npx eslint --max-warnings 0` passed for all eight changed or new TypeScript files.
- `node tool/creator_stats_qa/validate.cjs` passed. The native and seed test command passed all three tests, with zero failures or skips. The launcher syntax check passed.
- `JAVA_HOME=$(/usr/libexec/java_home) make rules-test` passed all 526 smoke cases. The real QA assertions also denied client access to all eight private collections.
- Real Firebase emulator `seed.cjs` and `assert.cjs` passed. Assertions covered enqueue-only delivery, concurrent enqueues and processors, exactly-once checkpoints, deleted and recreated sources, approval and alias changes, folders, and inbox deduplication.
- `capacity.cjs` passed in a fresh dedicated emulator session. The cold 500-wall callable used 2,502 transaction reads in one attempt. The warm callable used 1,502 reads in one attempt. Four concurrent cold calls used seven attempts.
- At M=20,000, K=100, U=1, H=100, and P=100, the daily processor used 20,307 transaction reads and 302 writes. These counts include lease acquire and release, one full batch, and the terminal empty batch. The harness counted actual transaction operations and checked all committed histories and checkpoints. They are not production billing or latency measurements.
- At 20,001 walls, the processor retained all 100 queue items byte-for-byte and advanced no checkpoints. After capacity returned, all 100 recovered with the daily sources deleted. QA advanced `notBefore` with an Admin write instead of waiting 15 minutes. The session ended with 20,001 walls as required.

Every emulator launch required all six requested ports to be free. Only this task's emulator sessions were stopped. All six ports were free after the final run. No device or simulator was used.

The worktree lacked `functions/node_modules`, so `npm ci` ran once. No dependency file or toolchain changed. Local commands used the installed Node v26.12.1, not the package's declared Node 24. npm reported 18 moderate audit findings, which remain outside this change.

## Parent rerun

On the merged branch, the parent reran the queue change independently: the full Functions suite passed with 2,363 tests and 23 skips; `make rules-test` passed 526 checks with 0 failures, including the new private collections; fresh-emulator `seed.cjs` and `assert.cjs` passed, including the higher-counter race; and `capacity.cjs` measured 20,307 reads and 302 writes for one 100-item batch at 20,000 walls, with all 100 items kept at 20,001 walls.

## Tests and TDD limits

The new daily suite has 25 top-level tests and three nested boundary cases. The new lease suite has 12 tests. Together with the migrated creator-stats tests, the focused suites pass 74 tests.

The tests cover queue maxima, replay costs, TTL after-images, source incarnations, calendar validation, nanosecond ordering, shared history accumulation, account gates, aliases, approval, poison isolation, atomic failure, capacity recovery, leases, ordering, budget, coverage, pruning, and exact operation counts. Fake database tests cover projections, outside-transaction operations, and commit failure injection. Index and rules contract tests cover private collections, query order, payload exemptions, and absent TTL.

The requested test-first process was not complete. Many core, migrated, lease, and QA tests first ran after their behavior existed and passed immediately. Three index and rules contract tests did not run red first. The first QA validation failure was a missing-module integration failure, not a behavioral regression.

Observed failing-first tests include the initial enqueue and projection slice, fake database projections, malformed-history isolation, expired lease clock checks, and acquisition budget and clock timing. Further failing-first regressions covered UTC-day observation timing, malformed queue maxima, and outside-transaction observer accounting. Nine initially green lease tests later passed 11 narrow in-memory mutation checks. Mutation sensitivity is not test-first proof. The final capacity fixture also failed before its terminal over-capacity state was restored. No claim is made that every section 6 test failed before implementation.

Lease acquire and release use normal transaction retries. Only batch transactions use `maxAttempts: 1`, as specified. A real emulator race exposed lock timeouts when that restriction also covered lease transactions. Explicit modular Firestore imports fixed an emulator worker's missing namespace `Timestamp`.

## Remaining blockers

- Nothing was deployed. Deploy order: rules, then indexes and TTL configuration (wait until ready), then Functions, then Cloudflare deep-link bindings, all before the store build.
- No hosted CI, Node 24 runtime, production load, deployment, or new device proof is claimed for the queue change. Production cost and census contention remain rollout checks. The UI and Flutter code did not change after `be8d33268`.
- Open product decision: the Monday inbox reads recorded history at 09:00 UTC. Activity still queued at that time (backlog or a capacity cooldown) can miss that week's notice. The default is best-effort delivery. The alternative is a bounded catch-up run that reuses the existing week markers.
