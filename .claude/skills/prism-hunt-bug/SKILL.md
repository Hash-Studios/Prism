---
name: prism-hunt-bug
description: Diagnose and fix one reported Prism bug with a failing reproduction, a focused change, and current verification. Use for a specific crash, wrong wallpaper/feed behavior, failing Cloud Function call, broken screen, or web bug; not a release, backlog sweep, or broad benchmark campaign.
---

# Prism bug fix

Take the reported symptom to a root-cause fix and the delivery boundary the user requested. A
request to fix a bug does not itself request a merge, release, notification to a reporter, or
cleanup of other worktrees. Honor authorization already given; do not ask again.

Prism (`Hash-Studios/Prism`, default branch `master`) has three surfaces that can each own a
bug: the Flutter app (root `lib/`, tests in `test/`), Cloud Functions (`functions/`, TypeScript,
deployed separately from the app), and the marketing site (`web/`, Next.js). Pin the surface
before you touch code; a fix in the wrong one won't ship with the app that reported it.

## Select the owning checkout

Read this checkout's `AGENTS.md`, then inspect Git status and the actual failing layer. Use an
isolated worktree when the current checkout is busy with unrelated work; fetch `origin/master`
before branching from it.

Before running any Flutter command (`analyze`, `test`, `build`), check that
`lib/firebase_options.dart` exists. It is gitignored (`.gitignore` line 61) and normally comes
from `flutterfire configure`. A fresh worktree does not have it. Stub it the same way CI and
`make size-android` do:

```sh
printf "import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;\n\nclass DefaultFirebaseOptions {\n  static FirebaseOptions get currentPlatform => throw UnsupportedError('Local stub');\n}\n" > lib/firebase_options.dart
```

Never commit this file.

## Reproduce and repair

- Extract expected versus actual behavior from the report, logs, screenshot, and current
  contracts. Use [the intake checklist](references/intake-template.md) only for missing
  information that affects diagnosis.
- Trace all callers of the shared function before changing it, not just the path the report
  names. Fix at the shared owning layer (see [Prism gotchas](references/prism-gotchas.md) for
  where that layer usually is: `lib/core/firestore/firestore_tracked_client.dart` for Firestore
  access, `functions/src/*` for callables, `lib/core/router/` for navigation).
- Add the smallest meaningful regression test and observe the original failure before you fix
  it. Reuse the fakes in `test/support/` (`fake_app_analytics.dart`, `fake_error_reporter.dart`,
  `fake_user_block_repository.dart`, `in_memory_local_store.dart`) instead of writing new ones.
- A Firestore `permission-denied` is not automatically a client bug. The tracked client logs
  `sourceTag` and the collection on every denial (see `firestore_tracked_client.dart`); grep the
  log line's `sourceTag` back to its call site before deciding whether `firestore.rules` or the
  calling code is wrong.
- A Cloud Function bug fixed in `functions/src/*.ts` is not fixed for real users until it is
  deployed. `functions/lib` is compiled output, but it is tracked in Git (not gitignored): run
  `npm run build` inside `functions/` after editing `.ts` sources and include the regenerated
  `functions/lib/**` files in your diff. Deployment itself (`npm run deploy` /
  `firebase deploy --only functions`) is a separate, authorization-gated step; say plainly if the
  fix is code-complete but not yet deployed, since prod can lag the repo.
- A router bug may need generated code refreshed: after touching `lib/core/router/app_router.dart`
  or a route guard, run `make file-gen` (build_runner) so `app_router.gr.dart` matches, then
  format.
- For UI behavior, exercise the real path and capture its result on a device or simulator. Use
  the `verify-prism` skill for that (owned separately in this repo); do not invent your own
  screenshot flow. PR screenshots belong on the `qa/screenshots` orphan branch, not in the
  product diff.

## Verify and deliver

Read [verification and CI](references/ci-and-merge.md) before publishing. Use the gate for the
surface you changed:

- Flutter: `fvm flutter analyze --no-pub --no-fatal-infos` (or `CI=true make analyze`), plus
  `make test` for the affected area, plus `make format-check`.
- Cloud Functions: from `functions/`, `npm run build && node --test lib/__tests__/*.test.js`.
- Web: from `web/`, `npx tsc --noEmit`. There is no test runner for `web/` in CI; say so rather
  than implying coverage that does not exist.

Do not weaken lint, the analytics schema guard, the env-define guard, the Doppler guard, or a
security rule invariant to pass a gate.

When a PR is requested, verify locally, inspect the entire diff (including any regenerated
`functions/lib` or `app_router.gr.dart`), stage only intended files, commit, push, and open the
PR against `master`. Keep `lib/firebase_options.dart` and any local stub out of the diff.

Merge only when authorized, using current repository policy and fresh checks for the PR's
current head; the required check is `ci` (see the workflow's job list in
[verification and CI](references/ci-and-merge.md)). Do not infer success from missing checks,
draft skips, or a green run on an earlier SHA.

Report the cause, fix, reproduction and gate results, PR status when applicable, and any
remaining device/deploy/CI gap. Keep local proof, merge, deployment, and live behavior separate.
Leave the worktree available unless cleanup was requested. Replying on the originating GitHub
issue, or closing it, reaches a real user: only do that with explicit authorization.
