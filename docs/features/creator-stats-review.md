# Day 21 independent review

The review covers the Day 21 tracked diff and untracked source. Existing upstream changes outside this feature remain untouched. The worktree started at `617cd09d396212beeb05419dede972eb96b833ea`. During review, `origin/master` advanced to `5dee629d0cb666093b1e4fd0e54cf290c466825e`; those incoming AI result changes are outside this task. Parent integration must update the branch and verify its final commits.

## Confirmed findings and fixes

| Finding | Resolution and regression proof |
| --- | --- |
| Missing fields in an existing lifetime stats document, and missing `remixCount`, became zero. | Fixed. Missing and invalid individual fields return null; literal numeric and legacy string zero stay zero. The regression failed before the fix. |
| Exact ID queries missed foreign lowercase, mixed-case, and whitespace aliases of shared counters. | Fixed with one projected global identity census per callable transaction, including warm cache hits. Shared daily projection uses the same normalized identity proof. Tests cover foreign withdrawn aliases, 500 caller walls, warm invalidation, normalized legacy walls, and global overflow. Disabling census normalization makes the alias test fail. |
| An open dashboard could retain the previous account's results or pending response. | Fixed. The page keys its BLoC by active session UID, discards the previous owner on account change, and replaces private stats with sign-in UI on logout. The late-response regression fails without session scoping. |
| Exact values for all eight weeks were available only through semantics. | Fixed. Each chart now shows a localized week date and its exact value or unavailable label. The 320px, 2x text test visits every visible row. Restoring endpoint-only labels makes it fail. |
| Profile and entry tests fed booleans directly into a button. | Replaced with actual own-UID, own-username, foreign-profile and guest integration tests. Real uploads and Rewards widgets verify their entries without data. Production route configuration tests cover root and nested taps plus the signed-in guard. Existing AutoRoute push already reaches the root route; no navigation behavior change was needed. |
| Hindi placeholder metadata did not match English; base Portuguese differed from pt-BR. | Fixed the ARB contracts and regenerated localization. Existing Hindi and Portuguese contract tests now pass. All seven catalogues explain partial rollout weeks. |
| `/creator-stats` was absent from external deep-link contracts. | Fixed worker path and association allowlists, both Cloudflare host route bindings, and all five Android activity/icon aliases. The complete worker/deep-link gate passes. |
| The documented 2,502 cold / 1,502 warm budget omitted foreign walls under the new identity proof. | Corrected. Cold reads are bounded by `2 + M + 4N`; warm reads by `2 + M + 2N`. M is all global wall documents, N is the caller's approved walls. Creator and global capacities are separate. |

## Verified concerns without another finding

Authentication supplies the creator UID. Identity overrides are rejected. Responses contain aggregate counts and the creator's approved wall metadata, with no viewer identity. Current ownership, approval, account deletion barriers, wall incarnation, and normalized identity eligibility are transaction reads even on warm hits. Duplicate IDs do not read shared lifetime counters or receive shared daily history. Explicit folder wall references retain source identity checks.

UTC ISO-year boundaries, Sunday/Monday edges, eight contiguous windows, null aggregation, genuine zeroes, five-minute cache expiry and week rollover have focused coverage. Recorded partial rollout values remain real lower bounds; missing pre-coverage values stay null. Coverage dates describe first observation rather than publication. UI copy now states that recorded weeks can be partial.

Daily checkpoints, folder creation markers, first-credit remix markers and inbox creator/week markers commit with their increments or inbox writes. Tests cover replay, TTL-delayed after-images, daily source recreation, aborted writes, withdrawal/reapproval, legacy remix credit suppression and concurrent inbox delivery. The existing explicit modular Firestore imports and streak-reminder route fix remain intact.

QA bootstrap was checked against generated DI. Registrations are lazy, so replacing `FirestoreClient` immediately after DI does not leave an eagerly captured client in repositories. The opt-in demo bootstrap connects Auth, Firestore and Functions before DI and suppresses Remote Config, FCM, purchases and monitoring. Real authenticated callable and private-rule checks pass against `demo-prism` only.

## Proof

- At the review commit, `cd functions && npm run build && node --test 'lib/__tests__/*.test.js'` passed: 2,226 passed, 16 existing skips, zero failures. The focused creator-stats suite had 35 tests. Later results name their own commits in `creator-stats-proof.md`.
- ESLint passes with `--max-warnings 0` for every changed Functions source and test.
- The affected Flutter run passed 118 tests, including stats, profile ownership, uploads, Rewards, Hindi/Portuguese contracts, emulator validation and routing. No full Flutter suite was rerun.
- Feature analysis reported no issues. Full analysis with `--no-fatal-infos` completed with existing repository information-level findings; new feature findings were fixed.
- `make l10n-check` and `make analytics-check` ran against committed generated files.
- `make file-gen`, `make analytics-gen`, and `make l10n-gen` completed. Generation produced whitespace-only changes in two unrelated generated files; those changes were restored.
- Format, environment, secrets, version, dynamic, Firestore, shape parsing, system UI, unused-code and repository asset checks passed. The worker gate passed all 125 tests and both deep-link contract checks.
- Real Auth/Functions/Firestore assertions passed authenticated isolation, eight windows, empty accounts, unauthenticated rejection, concurrent daily and folder projection, and exactly-once inbox delivery.
- Official [Firestore transaction limits](https://firebase.google.com/docs/firestore/manage-data/transactions) were checked against the cache and response caps. Production lock timing is not proven by an emulator run.
- Real Firestore accepted 500 cache writes in one cold transaction. Cold and warm attempts each completed once. Four concurrent cold refreshes completed in seven total transaction attempts. Measured reads with two additional demo walls were 2,504 cold and 1,504 warm. Response size was 939,786 bytes.
- Real Firestore also served the maximum 20,000 global wall census with 499 currently approved caller walls, then rejected global wall 20,001. A foreign whitespace/mixed-case alias and withdrawal invalidated warm eligibility.
- Authenticated and unauthenticated REST reads, plus authenticated writes, were denied for all six private creator-stats collections in the real rules emulator.

Local evidence is under `/tmp/prism-review-*.log`. Reusable emulator capacity assertions are in `tool/creator_stats_qa/capacity.cjs`.

## Remaining limits and parent gates

A shared daily projection requires one global census per transaction attempt. At 20,000 walls, a changed daily update costs 20,005 reads before retries. Legacy folder sources without canonical document IDs also need a census. This is a material background cost; the callable cache does not reduce it. Avoiding it requires a future canonical event source or complete normalized identity index. Neither existing counters nor trending were changed.

The current-wall census cannot reconstruct deleted historical aliases or repair any contamination already stored in legacy counters. Source creation ordering prevents old stats and daily source incarnations from attaching to recreated walls; it cannot prove historical uniqueness for deleted documents.

The Model the Domain principle led to a BLoC owned by one session UID. The Test Behavior, Not Implementation principle led to actual profile and router integration tests in place of button visibility booleans.

The parent rebased the reviewed commits onto `5dee629d0` without conflicts. Final full `make ci` and Android and iOS screenshot and clip proof are recorded in `creator-stats-proof.md`. No deployment, push, merge, production data access, dependency change or toolchain change was performed. Deploy order remains rules, indexes, functions, then the store build.

## Astra final pass

Astra found that the independently pushed wall detail retained its snapshot after account change or logout. The root added two failing regressions that open detail first, then change the session. Detail now checks the UID that owned its original snapshot and hides private content on mismatch. The earlier dashboard-only session claim did not cover this route.

Astra also found that deterministic identity-census overflow retried every background event. The trigger boundary now distinguishes this capacity failure, acknowledges it without a checkpoint, and retains retries for transient failures. The new wrapper-level regression failed before the fix. All 37 backend tests and all 16 creator-stats Dart tests passed after the fixes. Both account-change regressions failed before the fix, and the capacity wrapper regression failed before its fix.

Production rollout needs an event-volume budget before Functions deployment. At 20,000 walls, 10,000 changed daily documents cost 200,050,000 projection reads before retries. No production volume or affordability claim has been verified. The five-minute callable cache does not reduce projection cost.

## Durable daily projection review, 2026-10-31

This pass reviews `c13aab249..8e9d87667` against `/tmp/cs761/astra-spec.md`. The review worktree is `/Users/codenameakshay/.t3/worktrees/Prism/t3-d8cf7ae1`, on `akshay/creator-stats-daily-review`. Earlier per-event census cost and six-collection statements above describe historical implementations. The current backend document describes batched projection and eight private collections.

### Findings

- Fixed a poison-isolation failure in `creatorStatsDaily.ts`. After identifying an invalid queue item, batch telemetry still invoked its unvalidated `firstEnqueuedAt.toMillis`. A stored map with a non-callable `toMillis` rolled back the entire batch, including healthy peer history and the blocked-state update. The new regression failed with `TypeError: _b.call is not a function` before the fix and passed afterward. Telemetry now accepts only a Firestore Timestamp. The test checks retained poison counters, no checkpoint advance, successful peer history, and persistence of the blocked item on another invocation.
- Corrected the backend read-cost formulas. Account checks include inactive owners. Malformed queues can skip checkpoint reads. Invalid histories incur reads without history writes. Empty census queries incur one read. Four measured unit cases cover these differences. The full-batch example now states its upper-bound assumption of one checked creator and one history per item.
- Open product decision. Monday delivery reads projected history only. If all activity remains queued at the check, it skips the notice successfully. Later projection does not trigger delivery, and next Monday selects a different week. The new test proves that a rerun for the original week can deliver after projection. Option 1 is to keep this best-effort behavior. Option 2, recommended if weekly delivery is promised, is to design a bounded catch-up window with the existing UID/week deduplication. No catch-up policy was added in this review.

### Audit conclusions

The normalized wall census is inside the same transaction that writes history. It includes foreign, draft, withdrawn, mixed-case and whitespace aliases. Current approval, creator gates and nanosecond source ordering are checked before attribution. No-delta work stops before the census. Blocked items are excluded from the ready query, and enqueue preserves their blocked state while merging valid counter maxima.

The trigger reads the source, checkpoint and queue in one transaction. The processor reads the queue before deleting it in its history/checkpoint transaction. A concurrent deletion therefore participates in Firestore conflict detection. In the processor-first serialization, a higher delayed after-image exceeds the newly accepted checkpoint and recreates ready work. In the enqueue-first serialization, the processor consumes the raised maximum. A new test proves both serializations, including a deleted source and a lower favourite count that must not erase the previous maximum. It also checks that processing performs no database operations outside transactions. The fake database serializes transactions, so these tests do not measure Firestore contention. The emulator QA script now also races higher delayed counters against multiple processors and checks the final history, checkpoint and empty queue. Only aborted operations may be retried in that scenario.

Existing passing tests cover lease exclusion, expired takeover, stale-token rejection, token-safe release, capacity retention and cooldown recovery, oldest-first ordering, stable queue position under increments, the 240-second budget, reordered events, source recreation, TTL-delayed events, arithmetic poison, rollback, shared histories, null coverage and nine-week pruning. The 100-item query bounds writes to at most 300, with the separate byte ceiling retained. Rules explicitly deny both new collections. The composite index matches `state == ready`, `firstEnqueuedAt ASC`, then document ID ASC. Index exemptions and no-TTL contracts remain intact.

The Test Behavior, Not Implementation principle shaped the new regression assertions. They check persisted counters, blocked work and healthy peer history, rather than only successful completion.

### Local proof and limits

- `cd functions && npm run build && node --test 'lib/__tests__/*.test.js'` passed with 2,363 passes, 23 skips and no failures.
- `npx eslint --max-warnings 0` passed for all eight changed TypeScript files across the reviewed commits and this review.
- `node tool/creator_stats_qa/validate.cjs` passed. It validates script syntax, bundle allowlists, API wiring and local-only guards without starting an emulator.
- `git diff --check` passed.

The worktree had no Functions dependencies, so the authorized `npm ci` ran once. The installed runtime is Node 26.12.1, while Functions declares Node 24. No dependency manifest or toolchain was changed. This pass did not run devices or emulators, perform production actions, push, merge or deploy. Real contention, emulator rules behavior and production latency remain separate proof gates. The added emulator race assertion has syntax validation only in this pass.
