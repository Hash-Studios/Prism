# Creator stats verification

## Final gates

The final code commit is `58f61ed41b47edee14fc42dd57665d119201db5a`. Its starting and ending SHA matched, and the worktree had no tracked changes at either check. Later commits change documentation only.

- `CI=true make ci TEST_FLAGS=--concurrency=4` passed. The full Flutter suite passed 8,287 tests and skipped six. The release checks passed six tests. All preceding Makefile gates passed.
- `cd functions && npm run build && node --test 'lib/__tests__/*.test.js'` passed: 2,308 passed, 23 skipped, 0 failed. ESLint with `--max-warnings 0` passed for every changed Functions source and test.
- `node tool/creator_stats_qa/validate.cjs` and `node --test tool/creator_stats_qa/native.test.cjs tool/creator_stats_qa/seed_test.cjs` passed.
- `seed.cjs` and `assert.cjs` passed against real Auth, Firestore and Functions emulators after the merge and after the daily projection fix.

Earlier results: frozen commit `e109d854d` passed `make ci` with 7,789 Flutter tests and 2,228 Node tests. The review record's 2,226 Node tests ran at its own earlier commit.

## Device proof

Evidence is on `qa/screenshots` under [`creator-stats-761-2026-10-31`](https://github.com/Hash-Studios/Prism/tree/qa/screenshots/creator-stats-761-2026-10-31). Every screenshot has a view tree. Both platforms ran on a Mac against the real app, the real `getCreatorStats` callable and demo emulators.

**Android.** AVD `Prism_QA_API36`, Android 16. Real taps covered own profile to Stats, metric switch, the eight-week chart, top wall to that wall's own numbers, the Uploads and Rewards entries, the weekly inbox item to the dashboard, another creator's profile without Stats, dark theme, the largest text size with the chart's screen-reader summary, and the empty creator with its upload link. A clip records profile, Stats, metric switch and top wall.

**iOS.** Simulator `Prism QA iPhone 17 Pro`, iOS 27.0. The same flows and the same clip passed.

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

## Read cost

M is all global wall documents, capped at 20,000. N is the caller's approved walls, capped at 500. Counts are per transaction attempt, before retries.

- Callable: cold `2 + M + 4N`, cached `2 + M + 2N`. Unchanged.
- Daily projection: a delivery with no new counter delta now costs 2 reads, previously `M + 5`. A positive delta still costs `M + 5`.
- Legacy folder creation without a wall document ID: `M + 7`.
- At M=20,000, 10,000 positive daily deltas cost 200,050,000 reads before retries.
- Each census can hold pessimistic read locks on up to 20,001 walls until commit.

A safe identity index must stay complete atomically on every wall-writing path, so it is out of scope here. See `creator-stats-backend.md`.

## Remaining blockers

- Functions deployment needs an agreed event-volume and read budget, or a follow-up that removes the census from positive-delta projection.
- Nothing was deployed. Deploy order: rules, then indexes and TTL configuration (wait until ready), then Functions, then Cloudflare deep-link bindings, all before the store build.
