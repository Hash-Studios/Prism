---
name: prism-release
description: Ship a Prism release. Covers deploying Cloud Functions and Firestore indexes/rules, running one-off data migrations, bumping the pubspec version and build number, building a signed Android app bundle and uploading it to Google Play, building and uploading a signed iOS build to TestFlight and App Store Connect, uploading Sentry symbols, and smoke-testing the build before it goes to a store. Use when the user asks to release Prism, ship a build, cut a build, push to Play, push to TestFlight, deploy Prism functions, run a Prism migration, or bump the Prism version.
---

# Prism Release

Prism (Flutter, `com.hash.prism`) ships in this order: **backend first, then client, then store rollout**. Old
client builds still write coins/premium/subscription state directly to Firestore, so tightening
Firestore rules or removing an old code path always waits for the human's go-ahead on timing.

This skill is a checklist and a set of verified commands, not a single automated script. Almost
every consequential step (a deploy, a store upload, a secret, a migration `--apply`, a rollout
percentage, pushing the version bump) needs the human to say go at that exact step. See
"Human-only steps" below. Never batch several of them into one silent approval.

## Preconditions (check before starting)

Run these from the repo root.

1. **Firebase CLI sees the right project.**
   ```sh
   firebase projects:list
   ```
   Look for `prism-wallpapers`. If it is not in the list, the logged-in account cannot deploy
   functions or rules. Fix with `firebase login:add` (add another Google account) and
   `firebase login:use <email>` to switch, then re-run `firebase projects:list`. Do not guess a
   project id and deploy blind. `.firebaserc` already pins `"default": "prism-wallpapers"`, so a
   plain `firebase deploy` targets it correctly once the account can see it.

2. **Doppler config has every key the app needs.** The app reads env vars only through
   `lib/env/env.dart` (`String.fromEnvironment`). Before building with a given
   `DOPPLER_CONFIG`, list names only, never values:
   ```sh
   doppler secrets --project prism --config <dev|dev_personal|prd> --only-names
   ```
   Compare against the keys in `lib/env/env.dart` (`GH_USERNAME`, `GH_REPO_WALLS`,
   `GH_REPO_SETUPS`, `RC_API_KEY`, `RC_ANDROID_API_KEY`, `RC_IOS_API_KEY`, `PEXELS_API_KEY`,
   `SENTRY_DSN`, `SENTRY_ENV`, `SENTRY_RELEASE`, `SENTRY_DIST`, `SENTRY_ENABLED`,
   `MIXPANEL_TOKEN`, `MIXPANEL_ENABLED`). **Known gap, verified today:** `prd` does not have
   `RC_API_KEY` / `RC_ANDROID_API_KEY` / `RC_IOS_API_KEY`. It only has
   `REVENUECAT_ENTITLEMENT_ID`, `REVENUECAT_IOS_API_KEY`, `REVENUECAT_USE_IN_MEMORY`. A release
   build with `DOPPLER_CONFIG=prd` will fail `make doppler-check` (which `build`, `build-aab`,
   `build-ios`, and `build-ipa` all depend on) until this is fixed in Doppler. Stop and tell the
   human; do not silently fall back to `dev` for a release build, and do not add the missing keys
   to Doppler yourself (see "Secrets" below).
   `make doppler-check` runs this same comparison for the config in `DOPPLER_CONFIG` (default
   `dev`); `make secrets-print DOPPLER_CONFIG=<config>` prints the config with every value masked.

3. **Android signing key.** `android/key.properties` and the keystore it points to are
   `.gitignore`d and normally absent in a fresh checkout, confirmed absent in this worktree. The
   encrypted source is `android/android_keys.zip.gpg`. Only the **human** decrypts it (gpg asks
   for the passphrase in `ANDROID_KEYS_SECRET_PASSPHRASE`):
   ```sh
   ANDROID_KEYS_SECRET_PASSPHRASE=<passphrase> ./.github/scripts/decrypt_android_secrets.sh
   ```
   This unpacks `android_keys.zip` into `android/`, which should produce `android/key.properties`
   and the `.jks` keystore it references. Never ask the human for the passphrase in chat and never
   type it yourself. Have them run the decrypt, or export the env var themselves, before you run
   the build.

4. **Play Console access.** Preferred: the `gplay` CLI. Check it with
   `gplay status --package com.hash.prism` (the `tracks` source must be `ok: true`; the
   `vitals` source can fail without harm). Fallback: fastlane, whose `android/fastlane/Appfile`
   points at `android/google-play-console.json` (gitignored). If neither works, the human uploads
   the `.aab` by hand in Play Console.

5. **`asc` CLI can see Prism.** `asc doctor` only proves the profile works, not that it belongs
   to the right team. The key must belong to the team that owns Prism (`X2955Z4CKQ`). Check that
   `asc apps list` shows bundle id `com.hash.prism`. If it does not, stop: the human adds an App
   Store Connect API key for that team (`asc auth login`), or the build goes through the
   `.github/workflows/testflight.yml` workflow, which has its own secrets. TestFlight app id is
   `6670200846` (from that workflow), group `Prism Alpha`.

6. **Version guard.** `python3 tool/verify_version_sync.py`, checks `pubspec.yaml`'s
   `version:` line against `lib/core/constants/app_constants.dart`'s
   `currentAppVersion`/`currentAppVersionCode`. Run `python3 tool/sync_app_version.py`
   (= `make version-sync`) to fix a mismatch; `make version-guard` is the same check wired into
   `make ci`.

Print a one-line preflight verdict before moving on (which checks passed, which need the human).
Stop on any failure above except the signing/Play-key ones, which the human resolves inline as you
reach that step.

## Hardcoded identifiers

| Thing | Value |
|---|---|
| Firebase/GCP project | `prism-wallpapers` (`.firebaserc`) |
| Android application id | `com.hash.prism` |
| iOS bundle id | `com.hash.prism` |
| iOS team id | `X2955Z4CKQ` (automatic signing, `CODE_SIGN_STYLE = Automatic`) |
| App Store Connect app id | `6670200846` |
| TestFlight group | `Prism Alpha` |
| Doppler project | `prism` |
| Doppler configs | `dev`, `dev_personal`, `prd` |
| Android key.properties path | `android/key.properties` (gitignored, human-decrypted) |
| Android keystore source | `android/android_keys.zip.gpg` (gpg, passphrase is human-only) |
| Play service account JSON | `android/google-play-console.json` (gitignored) |
| Fastlane Play track (current lane) | `beta` (`android/fastlane/Fastfile` lane `beta`), **not** `internal` |
| Android aab output | `build/app/outputs/bundle/release/app-release.aab` |
| iOS ipa output | `build/ios/ipa/Prism.ipa` |
| Functions region | `asia-south1` (all callables) |
| Functions secrets (human sets, never echoed) | `GH_TOKEN`, `REVENUECAT_SECRET_KEY` |
| Functions plain env vars | `GH_USERNAME`, `GH_REPO_WALLS`, `GH_REPO_SETUPS` |

## Flags

- *(no flags)*: full release. Preflight, then backend deploy, then migrations (dry run only unless
  the human says apply), then version bump, then Android build plus Play upload, then iOS build
  plus TestFlight upload, then Sentry symbol upload, then smoke test, then summary. Store
  submission (App Store review, Play track promotion, rules tightening) is never automatic. See
  "Human-only steps".
- `--backend-only`: deploy functions plus Firestore indexes/rules only. Skips version bump and
  both client builds.
- `--android-only`: bump (unless `--skip-bump`), build the aab, upload via fastlane or hand off
  to the human for Play Console. Skips backend and iOS.
- `--ios-only`: bump (unless `--skip-bump`), build the ipa, upload to TestFlight. Skips backend
  and Android.
- `--skip-bump`: reuse the current `pubspec.yaml` build number (for a rebuild/retry).
- `--dry-run-migrations`: run migration scripts without `--apply` and stop after printing counts
  (this is also the default for any full release; `--apply` is a separate, explicit ask).

## Canonical flow

### 0. Preflight verdict

Run the six preconditions above. Report pass/fail for each. On any hard failure, stop.

### 1. Read and record the current version

```sh
grep -E '^version: ' pubspec.yaml
```

Format is `X.Y.Z+N` (currently `3.0.8+332`). `N` is `versionCode` on Android and `CFBundleVersion`
on iOS, both stores need `N` to increase on every upload.

**Cross-check against both stores before picking the next number.** This repo has no automated
build-number-desync guard (unlike `verify_version_sync.py`, which only checks pubspec against
`app_constants.dart`, not against ASC/Play):

```sh
asc builds next-build-number --app 6670200846 --version <VERSION> --platform IOS
# or: asc builds list --app 6670200846 --platform IOS --limit 3
gplay tracks list --package com.hash.prism   # or: gplay status --package com.hash.prism
```

If ASC's next number and Play's latest `versionCode` disagree with `pubspec.yaml`, **stop and ask
the human** which number to bump to. Do not silently pick one. This mirrors a real incident class
(see the `asc-release-flow` / `asc-submission-health` skills' own guidance on build-number
desync).

### 2. Bump `pubspec.yaml` and sync

Edit the `version:` line to `X.Y.Z+N+1` (or the human-confirmed number from step 1), then:

```sh
make version-sync    # python3 tool/sync_app_version.py, updates app_constants.dart to match
make version-guard    # python3 tool/verify_version_sync.py, must exit 0
```

Never hand-edit `lib/core/constants/app_constants.dart`. `version-sync` derives it from
`pubspec.yaml`.

### 3. Backend first: Cloud Functions and Firestore indexes

Deploy backend changes **before** any client build that calls a new or changed callable. The
callables today: `awardCoins`, `spendCoins`, `processReferral` (`functions/src/coinsCallables.ts`),
`githubPutFile`, `githubDeleteFile` (`functions/src/githubContent.ts`), `syncSubscription`
(`functions/src/syncSubscription.ts`), `deleteAccount` (`functions/src/deleteAccount.ts`).

```sh
cd functions && npm run build && cd ..
firebase deploy --only functions,firestore:indexes
```

`firebase.json`'s `predeploy` also runs `npm run build` automatically, but running it yourself
first surfaces TypeScript errors before the deploy attempt. Deploying `firestore:indexes` here
(not `firestore:rules`) is deliberate. See step 6.

This is a **human-approval step**: state exactly what changed in `functions/src` and Firestore
indexes, then get an explicit go before running `firebase deploy`.

### 4. Functions secrets (human-only, never echoed)

If a callable needs a new or rotated secret, the human runs this themselves. You never see or
type the value:

```sh
firebase functions:secrets:set GH_TOKEN
firebase functions:secrets:set REVENUECAT_SECRET_KEY
```

Plain (non-secret) env vars the functions read from `process.env`: `GH_USERNAME`,
`GH_REPO_WALLS`, `GH_REPO_SETUPS` (see `functions/src/githubContent.ts`). These are configured
through Firebase's runtime environment, not Doppler. Doppler only feeds the Flutter client's
dart-defines.

### 5. Data migrations (dry run, then human-approved apply)

Current migration scripts, both in `functions/package.json`:

```sh
cd functions
npm run migrate:username-lower       # dry run: prints "scanned=N changed=M applied=false"
npm run migrate:view-stats           # dry run
```

Read the dry-run output. Only re-run with `-- --apply` (e.g.
`npm run migrate:username-lower -- --apply`) after the human explicitly approves applying that
migration. Never chain dry-run and apply in the same unattended step.

### 6. Firestore rules: tighten only when the human says the timing is right

`firestore.rules` currently keeps `coins`, `premium`, and `coinState` server-owned on document
*creation* (`canCreateUserDoc`), but older store builds may still write these fields directly on
*update*. Deploying a rules change that blocks direct client writes to coins/premium is safe only
once most users are on a client build that goes through `awardCoins`/`spendCoins`/
`syncSubscription` instead. **Do not deploy `firestore:rules` as part of a routine release.**
Raise it as a separate, explicitly-timed step and let the human decide when enough of the install
base has updated:

```sh
firebase deploy --only firestore:rules
```

### 7. Android: build the aab

```sh
make build-aab DOPPLER_CONFIG=prd
```

This runs `flutter build appbundle --release --obfuscate --split-debug-info=build/app/outputs/symbols`
with dart-defines pulled from Doppler `prd`, then (because `SENTRY_UPLOAD` defaults to `true`)
uploads debug symbols via `tool/sentry_upload.sh` using Doppler `prd` Sentry credentials
(`SENTRY_DOPPLER_CONFIG` defaults to `prd` already, no need to pass it). **Blocked today**: see the
`prd`-missing-`RC_*`-keys gap in Preconditions step 2. Fix that in Doppler before this succeeds.

If it fails with `Keystore file not found` or `Failed to read key`, stop and ask the human. Do
not regenerate the keystore (that breaks Play updates for every existing install).

Output: `build/app/outputs/bundle/release/app-release.aab`. Record its size:
```sh
ls -lh build/app/outputs/bundle/release/app-release.aab
```

### 8. Android: upload (human decides the mechanism and the track)

Two options, both human-gated:

- **Fastlane** (`android/fastlane/Fastfile`, lane `beta`) uploads straight to the **`beta`** track
  with `release_status: completed`, not `internal`. Needs `android/google-play-console.json`:
  ```sh
  cd android && bundle exec fastlane beta
  ```
- **Manual**: the human uploads `app-release.aab` themselves in Play Console, choosing the track
  (internal / closed / production) and any staged-rollout percentage.

Either way, the **track and rollout percentage are the human's decision.** Never assume
`internal` is safe or pick a rollout percentage yourself.

### 9. iOS: build the ipa

```sh
make build-ipa BUILD_NUMBER=<N> DOPPLER_CONFIG=prd
```

Note: unlike `build-aab`, `build-ipa` does **not** pass `--obfuscate --split-debug-info` or the
Sentry dart-defines (`SENTRY_DART_DEFINES` is only wired into `build`/`build-aab`/`size-android` in
the Makefile). If Sentry symbolication for iOS crashes matters for this release, flag this gap to
the human rather than assuming it is handled. The Makefile as written does not obfuscate or
upload iOS debug symbols the way it does for Android.

Output: `build/ios/ipa/Prism.ipa` (confirmed name from `.github/workflows/testflight.yml`, not
`Runner.ipa`).

### 10. iOS: upload to TestFlight and App Store Connect

Prefer the installed `asc-*` skills over hand-rolling this:
- **`asc-release-flow`** for staging a version, uploading the ipa, and submitting for review.
- **`asc-testflight-orchestration`** for the TestFlight group/tester/what-to-test workflow.
- **`asc-whats-new-writer`** for App Store "what's new" copy.
- **`asc-xcode-build`** if the archive/export step itself needs help (not usually needed here:
  automatic signing, team `X2955Z4CKQ`, no `ExportOptions.plist` in this repo).
- **`asc-submission-health`** if a submission gets stuck or review status is unclear.

Direct command for a plain upload, matching what `.github/workflows/testflight.yml` does in CI:
```sh
asc publish testflight --app 6670200846 --ipa build/ios/ipa/Prism.ipa --group "Prism Alpha" --wait
```
Add `--test-notes "<text>" --locale en-US` for What to Test.

App Store submission (as opposed to TestFlight-only) is a separate, human-approved step. Use
`asc-release-flow`'s staging flow and get explicit confirmation before `--submit`. App Review
needs: in-app account deletion (present, `lib/core/account/delete_account_service.dart`) and Sign
in with Apple (present, `lib/auth/apple_auth.dart`, entitlement in
`ios/Runner/Runner.entitlements`).

### 11. Proof before either store upload

Install the release build on a device or emulator/simulator and smoke-test the core loops before
step 8 or step 10 ships anything: sign in, download a wallpaper (coin spend + refund path), watch
a rewarded ad, upload a wallpaper, restore purchases, receive a notification, delete a throwaway
account. Use the **`verify-prism`** skill (owned by another agent in this project) to drive the
simulator/emulator for this if it is available; otherwise do it manually and say so in the summary.

### 12. Summary

Report only what actually ran:
```
Prism release: version <VERSION>, build <N>.
  Backend:            deployed functions <list> + firestore indexes   (or "skipped")
  Migrations:         <name> dry run (scanned=X changed=Y)            (or "applied" if approved)
  Firestore rules:    not touched this release (human decides timing)
  Android aab:        build/app/outputs/bundle/release/app-release.aab (<size>)   (or "skipped")
  Android upload:     <track/mechanism, or "left to human">
  iOS ipa:            build/ios/ipa/Prism.ipa                          (or "skipped")
  TestFlight:         uploaded to group Prism Alpha                    (or "skipped")
  App Store:          not submitted this run (human decides)
  Sentry symbols:     uploaded (Android) / not uploaded (iOS build-ipa doesn't wire this)
  Smoke test:         <what was verified, or "not run, do this before shipping">
  Version bump commit: <sha, or "not committed, human pushes">
```

## Human-only steps (stop and get an explicit yes at the concrete step, not once up front)

- `firebase deploy` (functions, indexes, or rules)
- Any `firebase functions:secrets:set`
- Running a migration with `-- --apply`
- `bundle exec fastlane beta` / any Play Console upload, and the track + rollout percentage
- `asc publish testflight` / App Store submission
- Decrypting `android/android_keys.zip.gpg` (passphrase stays with the human)
- Pushing the version-bump commit

## Known gaps found while writing this skill (not yet fixed in the repo)

- Doppler `prd` is missing `RC_API_KEY`, `RC_ANDROID_API_KEY`, `RC_IOS_API_KEY`. A release build
  with `DOPPLER_CONFIG=prd` fails `doppler-check` today. Verified live with
  `doppler secrets --project prism --config prd --only-names`.
- `firebase projects:list` under this session's logged-in account does not show
  `prism-wallpapers` (only unrelated projects). Whoever runs this skill needs an
  account added via `firebase login:add` that has access.
- `android/key.properties`, `android/google-play-console.json`, and the decrypted keystore are all
  absent in a fresh checkout (expected, gitignored) and need the human to provide them per-run.
- `make build-ipa` does not obfuscate or wire Sentry dart-defines, unlike `make build-aab`. Confirm
  with the human whether iOS Sentry symbolication is handled some other way, or accept unsymbolicated
  iOS crash reports for this release.
- `android/fastlane/Fastfile`'s only lane (`beta`) targets the Play `beta` track directly with
  `release_status: completed`, not `internal`. There is no `internal`-track fastlane lane in this
  repo; going to `internal` first means uploading manually in Play Console.
- No `verify-prism` skill was found in this worktree's `.claude/skills/` at the time of writing;
  another agent is expected to add it. If it is still missing when this skill runs, do the smoke
  test manually and say so.

See `references/troubleshooting.md` for error-mode detail on doppler-check failures, keystore
issues, and Play/TestFlight upload errors.
