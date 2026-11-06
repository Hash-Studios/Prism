# CLAUDE.md

This file gives guidance to Claude Code (claude.ai/code) when it works with code in this repository.

---

## Behavioral guidelines

These bias toward caution over speed. Use judgment for trivial tasks.

### 1. Think before coding
- State assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them. Do not pick silently.
- If a simpler approach exists, say so. Push back when warranted.

### 2. Simplicity first
- Minimum code that solves the problem. No speculative features, no abstractions for single-use code, no "configurability" that was not requested, no error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

### 3. Surgical changes
- Do not "improve" adjacent code, comments, or formatting.
- Do not refactor things that are not broken. Match existing style.
- Remove imports and variables that **your** changes orphaned. Leave pre-existing dead code unless asked.
- Every changed line must trace directly to the user's request.

### 4. Goal-driven execution
- "Add validation" means: write tests for invalid inputs, then make them pass.
- "Fix the bug" means: write a test that reproduces it, then make it pass.
- For multi-step tasks, state a brief plan with verification steps before starting.

---

## Done means done

Not half done. Not done except for the part you decided to skip. And not a report about how it will be done.

Five things asked means five things delivered, no matter how long they take. If the fifth is blocked, finish the other four and name the blocker in one sentence. The specific blocker. Not "this needs more investigation."

## Act. Don't ask.

Reversible and cheap? Do it, then tell me. Research, data pulls, analysis, drafts, refactors inside the scope I gave you, testing an API. A question costs me more than a re-run costs you.

Ask first only for: anything that reaches an audience, anything we cannot undo, anything expensive.

Something is broken? Fix it. Reporting an issue you could have fixed turns your work into my to-do list.

## A question is a question

When I ask a question, answer it. Do not implement it.

"Should we use X?" is not "migrate everything to X." "What would it take to add Y?" is not "add Y."

When in doubt, assume it is a question. Answer first. Act when I say go.

## Speed

Optimize for wall-clock speed.

- Parallelize. Independent tasks run at the same time: batch tool calls, spawn subagents concurrently.
- Delegate by complexity: `fast-worker` (Haiku) for mechanical work (bulk edits, boilerplate, verification), `everyday-worker` (Sonnet) for everyday tasks and writing, `deep-reasoner` (Opus, read-only) for hard reasoning.
- Keep working in the main thread while subagents run.
- Enough info to act means act. No long option surveys for decisions with an obvious default.
- Speed never trades away quality: same rigor, same verification, same "done means done".
- No conflicts from parallelism: one owner per file. Merge and reconcile in the main thread.

## Short responses

Small words, short sentences, short paragraphs. If you must use a big word, explain it right after. Only return what is necessary.

Tell me what you did, did it work, what I do now.

If I have to decide something: 2 options max, the context I need to pick fast, and which one you would pick.

Keep paths and commands exact. Use ASD-STE100 Simplified Technical English. Never use em dashes.

---

## What this repo is

**Prism**: a Flutter wallpaper app for Android and iOS (Hash Studios, `Hash-Studios/Prism`, default branch `master`). Users browse, favourite, download and set wallpapers, follow creators, earn and spend Prism Coins, buy Prism Premium, and generate AI wallpapers.

| Part | Path | Notes |
|---|---|---|
| App | `lib/`, `test/` | Flutter 3.47 pinned in `.fvmrc`, run through `fvm` |
| Cloud Functions | `functions/` | TypeScript, Firebase Functions v2, region `asia-south1` |
| Firestore | `firestore.rules`, `firestore.indexes.json`, `firebase.json` | project `prism-wallpapers` (`.firebaserc`) |
| Website | `web/` | Next.js on Cloudflare (`wrangler.toml`) |
| Native | `android/`, `ios/`, `pigeons/` | Pigeon host APIs for media and platform calls |
| Vendored plugin | `packages/cloud_functions/` | local fork of the FlutterFire plugin |

Design intent lives in `.impeccable.md` (users, brand, themes, principles). Read it before UI work.

---

## Commands

The Makefile is the source of truth. `make ci` runs the full local gate.

### Daily

```sh
make setup-dev          # fvm + pub get + Doppler check
make run                # flutter run with Doppler dart-defines (DOPPLER_CONFIG=dev by default)
make test               # fvm flutter test
make format-check       # dart format at 120 columns
make ci                 # full local gate: static checks, guards, and the complete Flutter suite
make file-gen           # build_runner (freezed, json, injectable, auto_route), then format
make pigeon-gen         # regenerate Pigeon host APIs
make find-unused        # dead-code report (allowlist: tool/find_unused_allowlist.json)
```

`make analyze` fails on info-level findings. Use `fvm flutter analyze --no-pub --no-fatal-infos` for a clean read.

### Functions and web

```sh
cd functions && npm ci && npm run build && node --test 'lib/__tests__/*.test.js'
cd web && npm ci && npm run build
```

`functions/lib/` is compiled output and is ignored. Deploy rebuilds from `src/` (`firebase.json` predeploy).

### Secrets: Doppler

Doppler project `prism`, configs `dev`, `dev_personal`, `prd`. `tool/flutter_with_doppler.py` passes only allowlisted shipping `Env` keys as Flutter argv, without shell interpolation. `String.fromEnvironment` is allowed only in `lib/env/env.dart` (`make env-guard`). Never print secret values; check names with `doppler secrets --project prism --config <cfg> --only-names`. Release native configuration and the new iOS prerequisite are documented in `docs/development/doppler.md`.

For explicit local debug/CI checks without Doppler, use a gitignored `lib/firebase_options.dart` stub and `--dart-define=SKIP_FIREBASE_INIT=true`. Never use either as a release fallback. Release Make targets derive Dart options from validated real native config. TestFlight requires the owner-supplied `IOS_GOOGLE_SERVICE_INFO_PLIST` GitHub secret, which was confirmed absent.

### Git hooks

`make hooks` sets `core.hooksPath` to `.githooks`. The pre-push hook runs the cheap CI gates for what changed (Dart, functions, web, rules). `SKIP_PRE_PUSH=1 git push` skips it once.

### Device verification

UI changes need proof on a real app run: iOS Simulator and Android emulator screenshots, before and after. Use the `verify-prism` skill. PR screenshots go on the orphan branch `qa/screenshots` and are embedded with `raw.githubusercontent.com` URLs.

### CI gate (`.github/workflows/ci.yml`)

Drafts skip, and a new push cancels the old PR run. `changes` path-filters Flutter, native Android/iOS, functions, web, and Firestore-rules jobs. Docs, metadata, web-only, and backend-only PRs skip the full Flutter suite. App and shared-code PRs retain the full suite in two file-level shards (`make test-shard TEST_TOTAL_SHARDS=2`, with `TEST_SHARD_INDEX=0` and `TEST_SHARD_INDEX=1`), alongside one `make ci-static` job for format, guards, generated-output checks, and analysis. Files are sorted and distributed round-robin before compilation, avoiding the duplicated compilation of Flutter's within-file sharding flags. Product-mode probe tests run once, in shard 0. `make ci` still runs the complete local gate.

Top-level `functions/src/*.ts` changes require the notification-channel contract. Backend-only PRs run the small `notification_contract` job; mixed app/backend PRs cover the real contract in the Flutter suite and run the missing-channel regression fixture in the static job. Repository-assets and store-listing guards have one dedicated hosted job. Web tests use the Ubuntu runner's preinstalled Chrome through Playwright's supported `chrome` channel. CI also runs `npx tsc --noEmit`, because the Next.js build filters test-file diagnostics and Playwright does not typecheck.

`ci` is the only required status on `master`. It aggregates the static job, both test shards, applicable native/backend/web/rules jobs, and repository guards. Failed or cancelled jobs block it; intentionally skipped jobs pass. Master pushes warm native dependency caches only when their keys change, rather than rebuilding an app-size baseline for every app-code merge.

App-size comparisons are optional in `.github/workflows/app_size.yml`. Add the `ci:app-size` PR label to run on the current and subsequent pushes. Once the workflow is on the default branch, `gh workflow run app_size.yml -f pr_number=<number>` supports same-repository PRs only. Manual builds require trusted PR code because they use branch-scoped cache credentials. Fork PRs must use the label, so their code runs in a PR cache scope. Labels also keep same-repository builds PR-scoped. Removing the label clears the old report. A missing base APK is built on demand, so an opted-in run can build two APKs. This compares profile APKs, not the shipping AAB size, and never changes the required `ci` result. Codacy "action required" is not a gate.

---

## Architecture

### Feature layout (`lib/features/<name>/`)

Modern features (for example `wall_of_the_day`, `streak`, `user_blocks`, `onboarding_v2`) use:

```text
<name>.dart                  barrel
biz/bloc/                    *_bloc.j.dart, *_event.j.dart, *_state.j.dart (freezed, generated *.j.freezed.dart)
data/                        repositories/*_repository_impl.dart, mappers, Firestore pointers
domain/                      entities/, repositories/ (interfaces), usecases/
views/                       pages/, widgets/
```

Use the `prism-create-feature` skill to scaffold one. Older code in `lib/data/`, `lib/global/` and some `lib/features/*` does not follow this shape. Do not copy it into new code.

### Core stack

- **State:** `bloc` / `flutter_bloc` 8.x with `freezed` 3.x events and states.
- **DI:** `get_it` + `injectable` (`lib/core/di/`, generated `injection.config.dart`). Regenerate with `make file-gen`.
- **Routing:** `auto_route` 11 (`lib/core/router/app_router.dart`, generated `app_router.gr.dart`). Deep links: `deep_link_parser.dart` then `deep_link_navigation.dart`.
- **Firestore:** go through `FirestoreClient` (`lib/core/firestore/`) with a `sourceTag` on every call. Permission-denied logs name the `sourceTag`. `make firestore-guard` blocks raw `FirebaseFirestore` use.
- **Coins, premium, uploads, account deletion:** server-owned. The client calls callables (`awardCoins`, `spendCoins`, `processReferral`, `syncSubscription`, `githubPutFile`, `githubDeleteFile`, `deleteAccount`). Firestore rules refuse direct client writes to `coins`, `premium`, `subscriptionTier`, `coinTransactions`, and coinState award flags.
- **Analytics:** typed events in `lib/core/analytics/events/`. Regenerate the schema with `make analytics-gen`. Hosted CI runs `make analytics-schema-check`, and the test shards cover the schema contract. `make analytics-check` runs both checks locally.
- **Monitoring:** Sentry (`sentry_flutter`), Mixpanel.
- **Purchases:** RevenueCat (`purchases_flutter`, `lib/core/purchases/`).

### UI

Follow `.impeccable.md` and build on the design system in `docs/agents/design-system.md` (one import: `lib/core/widgets/prism/prism_ui.dart`). Use `Theme.of(context)` and `ColorScheme`; no hard-coded colours. Respect the active light/dark variant and the user accent. Content (the wallpaper) is the hero. Icon-only buttons need a tooltip or a `Semantics` label.

---

## Backend changes

A client change that calls a new or changed callable needs a functions deploy before a release that ships it. Tightened Firestore rules can break store builds that are already installed, so plan rule deploys against client adoption. See the `prism-release` skill for the order.

Validate inputs at every callable. Never trust the client for money-like values (coins, premium, refunds).

---

## Gotchas

- The shell is zsh. Quote globs (`--include='*.dart'`) and write `"${ref}:path"` (zsh treats `$ref:t` as a modifier). GNU `timeout` is not on macOS.
- Run `fvm flutter`, not bare `flutter`.
- Dart style: 120 columns, single quotes, package imports.
- Generated files (`*.g.dart`, `*.freezed.dart`, `*.gr.dart`, `injection.config.dart`) are committed with their source change.

---

## When to ask vs proceed

Ask before:
- Adding a dependency to `pubspec.yaml`, `functions/package.json` or `web/package.json`.
- Major version bumps of `bloc`, `freezed`, `auto_route`, `get_it`, `injectable`, Firebase packages.
- Deploying functions, rules or indexes, running a data migration with `--apply`, or any store upload.
- Changing Firestore rules in a way that refuses writes shipped clients make.
- Removing a Firestore field the app or functions already read.

Proceed without asking for:
- Work inside an existing `lib/features/<name>/`.
- New repository methods, callables or widgets that follow existing patterns.
- New tests.
- Local gates, builds and simulator runs.

---

## Agent skills

Project skills live in `.claude/skills/` (mirrored for other agents in `.agents/skills/`):

| Skill | Use it for |
|---|---|
| `prism-release` | Play Store and App Store releases, backend deploy order |
| `verify-prism` | Drive the app on the iOS Simulator and Android emulator for proof |
| `prism-hunt-bug` | Fix one reported bug with a failing reproduction |
| `prism-bug-triage` | Sweep GitHub issues and Sentry, rank, fan out fixes |
| `prism-create-feature` | Scaffold a feature in the canonical layout |
| `prism-widget-test-harness` | Write or debug widget and bloc tests |
| `prism-remove-unused-code` | Delete dead code and refresh the allowlist |
| `prism-coverage-fleet` | Raise test coverage with parallel agents |
| `prism-sweep-worktree-caches` | Reclaim disk from worktree build caches |
| `akshay-mode` | Orchestrator working style (only when asked) |

### Issue tracker

GitHub issues on `Hash-Studios/Prism`, through the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

The five canonical triage roles. See `docs/agents/triage-labels.md`.

### Domain docs

Single context: `.impeccable.md` for product and design, `README.md` for features. See `docs/agents/domain.md`.
