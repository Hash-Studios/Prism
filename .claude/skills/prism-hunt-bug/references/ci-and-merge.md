# Verification, hosted CI, and merge

## Before pushing

Read this checkout's `AGENTS.md` and `.github/workflows/ci.yml`. Run the gate for the surface
you changed; do not assume the Flutter gate covers a Cloud Functions or web change, and vice
versa.

**Flutter app** (`lib/`, `test/`):

- `make format-check`
- `make env-guard` (`String.fromEnvironment` only allowed in `lib/env/env.dart`, plus a system-UI
  guard)
- `make version-guard` (app version stays in sync)
- `CI=true make analyze` or `fvm flutter analyze --no-pub --no-fatal-infos`: plain
  `make analyze` exits non-zero on pre-existing info-level findings, so use one of these forms
  for a clean exit.
- `make analytics-check` if you touched anything under `lib/core/analytics/`: it regenerates
  `lib/core/analytics/events/generated/analytics_events.g.dart` and fails on an uncommitted diff.
- `make no-dynamic-guard` if the change is anywhere near a shape/serialization boundary.
- `make test` (or `fvm flutter test <path>` for just the affected files while iterating).
- `make find-unused-ci` only if you added or removed a public symbol/file the allowlist might
  need updating for.

Before any of the above, stub `lib/firebase_options.dart` if it is missing (see the main
SKILL.md). Never commit the stub.

**Cloud Functions** (`functions/`):

```sh
cd functions
npm ci        # first run only
npm run build
node --test lib/__tests__/*.test.js
```

Tests are written in `functions/src/__tests__/*.test.ts` and run from the compiled
`functions/lib/__tests__/*.test.js`: always rebuild before testing, and after editing any
`.ts` source rebuild again so the tracked `functions/lib/**` output matches before you diff.

**Web** (`web/`):

```sh
cd web
npm ci        # first run only
npx tsc --noEmit
```

There is no test runner configured for `web/` in CI, only a typecheck. Do not claim test
coverage that doesn't exist there.

Do not weaken lint, the analytics schema guard, the env-define guard, the Doppler guard
(`make secrets-guard`), or a `firestore.rules` invariant to make a gate pass.

## Hosted proof

The workflow is `.github/workflows/ci.yml` with jobs `ci`, `app_size`, `functions-ci`, and
`web-ci`. **`ci`** is the required check for merge. `app_size` only runs on PRs that touch
app-size-relevant paths (`lib/**`, `android/**`, `pubspec.*`, `ios/**`, `assets/**`, `tool/**`,
`.fvmrc`, the workflow file itself); a skip there for an unrelated change is expected, not a
gap. `functions-ci` and `web-ci` run unconditionally on every push/PR.

After pushing, read the PR's current `headRefOid`, base, draft state, and checks:

```sh
gh pr checks PR_URL
gh run view RUN_ID --log-failed   # for a specific failing run
```

- An empty checks list, API error, pending run, draft skip, or cancelled run is not green.
- A workflow failing before checkout proves an infrastructure failure, not a source-code
  failure.
- Every new push invalidates earlier hosted proof until checks for the new revision complete.

Resolve the failure, rerun the relevant local gate, then push a new commit (prefer a new commit
to amending a shared branch). Stop blind retries when the same external blocker persists;
report the actual gate and what is needed.

## Merge boundary

Merge only if the user requested it. Never bypass the required `ci` check or branch protection.
Recheck the current head and review state at the merge boundary. If merged, read back the merge
commit and report it separately from deployment (a merged Flutter PR still needs a store release
to reach users; a merged Cloud Functions PR still needs `firebase deploy --only functions` to
reach prod: see `prism-gotchas.md`). Otherwise report the PR as open with the precise pending
or failed gate. Cleanup and reporter outreach are separate actions and require their own
authorization.
