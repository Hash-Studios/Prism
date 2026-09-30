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
- Delegate by complexity: `fast-worker` (Sonnet) for routine work (search, bulk edits, boilerplate, verification), `deep-reasoner` (Opus, read-only) for hard reasoning.
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
make ci                 # get, format-check, env/secrets/version guards, analytics-check, analyze, no-dynamic-guard, find-unused-ci
make file-gen           # build_runner (freezed, json, injectable, auto_route), then format
make pigeon-gen         # regenerate Pigeon host APIs
make find-unused        # dead-code report (allowlist: tool/find_unused_allowlist.json)
```

`make analyze` fails on info-level findings. Use `fvm flutter analyze --no-pub --no-fatal-infos` for a clean read.

### Functions and web

```sh
cd functions && npm ci && npm run build && node --test lib/__tests__/
cd web && npm ci && npm run build
```

`functions/lib/` is compiled output and is ignored. Deploy rebuilds from `src/` (`firebase.json` predeploy).

### Secrets: Doppler

Doppler project `prism`, configs `dev`, `dev_personal`, `prd`. `tool/dart_defines_from_doppler.sh` turns secrets into `--dart-define` flags (it drops `GH_TOKEN`). `String.fromEnvironment` is allowed only in `lib/env/env.dart` (`make env-guard`). Never print secret values; check names with `doppler secrets --project prism --config <cfg> --only-names`.

Without Doppler, stub `lib/firebase_options.dart` (gitignored, never commit it) and pass `--dart-define=SKIP_FIREBASE_INIT=true`. A fresh worktree has no `lib/firebase_options.dart`: copy it from the main checkout.

### Git hooks

`make hooks` sets `core.hooksPath` to `.githooks`. The pre-push hook runs the cheap CI gates for what changed (Dart, functions, web, rules). `SKIP_PRE_PUSH=1 git push` skips it once.

### Device verification

UI changes need proof on a real app run: iOS Simulator and Android emulator screenshots, before and after. Use the `verify-prism` skill. PR screenshots go on the orphan branch `qa/screenshots` and are embedded with `raw.githubusercontent.com` URLs.

### CI gate (`.github/workflows/ci.yml`)

PRs only; drafts skip, and a new push cancels the old run. `changes` path-filters the jobs: `flutter` (`make ci`: format, guards, analyze, tests), `functions`, `web`, `rules` (Firestore rules smoke test on the emulator), `app_size`. `ci` aggregates `flutter`, `functions`, `web` and `rules` and is the only required check on `master`; a skipped job counts as a pass. `app_size` is not required. It compares the head APK with the base APK that `app_size_base` builds and caches after each merge to `master`, which is the only job that runs on push. Codacy "action required" is not a gate.

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
- **Analytics:** typed events in `lib/core/analytics/events/`. Regenerate the schema with `make analytics-gen`; CI runs `make analytics-check`.
- **Monitoring:** Sentry (`sentry_flutter`), Mixpanel.
- **Purchases:** RevenueCat (`purchases_flutter`, `lib/core/purchases/`).

### UI

Follow `.impeccable.md`. Use `Theme.of(context)` and `ColorScheme`; no hard-coded colours. Respect the active light/dark variant and the user accent. Content (the wallpaper) is the hero. Icon-only buttons need a tooltip or a `Semantics` label.

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
