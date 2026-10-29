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

- `npm run build` and the full Node suite passed: 2,226 passed, 16 existing skips, zero failures. The final focused creator-stats suite has 35 tests.
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

The parent rebased the reviewed commits onto `5dee629d0` without conflicts. Final full `make ci` and Android and iOS screenshot/clip proof remain separate gates. Linux cannot provide the required iOS Simulator proof. No deployment, push, merge, production data access, dependency change or toolchain change was performed. Deploy order remains rules, indexes, functions, then the store build.

## Astra final pass

Astra found that the independently pushed wall detail retained its snapshot after account change or logout. The root added two failing regressions that open detail first, then change the session. Detail now checks the UID that owned its original snapshot and hides private content on mismatch. The earlier dashboard-only session claim did not cover this route.

Astra also found that deterministic identity-census overflow retried every background event. The trigger boundary now distinguishes this capacity failure, acknowledges it without a checkpoint, and retains retries for transient failures. The new wrapper-level regression failed before the fix. All 37 backend tests and all 16 creator-stats Dart tests passed after the fixes. Both account-change regressions failed before the fix, and the capacity wrapper regression failed before its fix.

Production rollout needs an event-volume budget before Functions deployment. At 20,000 walls, 10,000 changed daily documents cost 200,050,000 projection reads before retries. No production volume or affordability claim has been verified. The five-minute callable cache does not reduce projection cost.
