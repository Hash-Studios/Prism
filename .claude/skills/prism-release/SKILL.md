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
   `firebase login:use <email>` to switch, then re-run `firebase projects:list`. Or pass the
   account on every call: `--account <email>` (the Make targets take `FIREBASE_ACCOUNT=<email>`),
   which changes nothing else on the machine. The account that owns Prism is
   `akshaymaurya3006@gmail.com`. Do not guess a project id and deploy blind. `.firebaserc` already pins `"default": "prism-wallpapers"`, so a
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

3. **Release worktree has the gitignored files.** Build from a fresh worktree on the release
   branch. The human keeps the private files in the **main checkout**
   (`/Users/codenameakshay/Development/codenameakshay/Prism`). The agent copies them into the
   worktree. Never commit them, and never print `key.properties` (it holds the keystore
   passwords):
   ```sh
   M=/Users/codenameakshay/Development/codenameakshay/Prism
   cp "$M/lib/firebase_options.dart"            lib/
   cp "$M/android/app/google-services.json"     android/app/
   cp "$M/ios/Runner/GoogleService-Info.plist"  ios/Runner/
   cp "$M/android/key.jks" "$M/android/key.properties" android/
   # The human's copy may point at an old path (it pointed at C:/Users/... in 2026-09).
   # Gradle resolves storeFile from android/app/, so point the worktree copy at ../key.jks:
   sed -i '' 's|^storeFile=.*$|storeFile=../key.jks|' android/key.properties
   grep '^storeFile' android/key.properties     # read only this line, never the passwords
   git status --short --ignored android/key.jks android/key.properties   # must show "!!"
   ```
   Without `android/app/google-services.json` the Makefile silently adds
   `SKIP_FIREBASE_INIT=true`, which ships an app with Firebase off. `build-aab` and `build-ipa`
   now fail fast when a Firebase config file is missing. If the key files are not in the main
   checkout, ask the human to put them there. Fallback: the human decrypts
   `android/android_keys.zip.gpg` (gpg asks for the passphrase; never ask for it in chat). Never
   generate a new keystore: Play rejects updates signed with a different key.

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

Before asking for the go, show the human the exact diff against production:
```sh
firebase functions:list --project prism-wallpapers --account <email>     # compare with functions/src/index.ts exports
firebase firestore:indexes --project prism-wallpapers --account <email>   # compare with firestore.indexes.json
cd functions && npm ci && npm run build && node --test lib/__tests__/*.test.js && cd ..
git checkout -- functions/lib   # the build rewrites tracked output; keep it out of the diff
```
List the functions that will be created, updated, and deleted, and the indexes that will be
added. Firestore adds `__name__` to live indexes on its own, so compare index fields without it.
`firestore.indexes.json` must list every live index. A forced deploy deletes indexes that are
missing from the file.

Deploy (human-approval step):
```sh
make functions-deploy FIREBASE_ACCOUNT=<email>
# = make functions-env (functions/.env from Doppler prd), npm run build,
#   firebase deploy --only functions,firestore:indexes
```
Add `--non-interactive` when running `firebase deploy` by hand, and never `--force`, so a deploy
can never delete a function or an index. After the deploy: `firebase functions:list` shows every
export, and `firebase functions:log --lines 60` shows no new errors. Then `git checkout --
functions/lib`.

`firebase.json`'s `predeploy` also runs `npm run build`. Deploying `firestore:indexes` here (not
`firestore:rules`) is deliberate. See step 6.

### 4. Functions secrets and env (Doppler `prd` is the source)

Doppler `prd` holds the values. The human sets or rotates a secret in Doppler only (the command
prompts, so the value stays out of shell history):
```sh
doppler secrets set GH_TOKEN --project prism --config prd
doppler secrets set REVENUECAT_SECRET_KEY --project prism --config prd
```
- `GH_TOKEN`: a fine-grained token owned by `codenameakshay2`, only `prism-walls` and
  `prism-setups`, Contents read/write. Never the old classic token that shipped in the app.
- `REVENUECAT_SECRET_KEY`: RevenueCat, Project settings, API keys, new secret key, **API
  version V1** (`sk_...`). `syncSubscription` calls the v1 API.

Then the agent pipes them into Firebase after the human's go. Values are never printed:
```sh
make functions-secrets-sync FIREBASE_ACCOUNT=<email>
firebase functions:secrets:get GH_TOKEN --project prism-wallpapers --account <email>   # version ENABLED
```
Plain settings (`GH_USERNAME`, `GH_REPO_WALLS`, `GH_REPO_SETUPS`) go into the gitignored
`functions/.env` via `make functions-env`. `make functions-deploy` runs it for you.

### 5. Data migrations (dry run, then human-approved apply)

Migration scripts use Admin credentials from gcloud. The human logs in once:
`gcloud auth application-default login` (as the account that owns Prism). Every run needs
`GOOGLE_CLOUD_PROJECT=prism-wallpapers`.

Before any `--apply`, check which functions fire on the written collection (for example
`onFollowCreated` fires on every `usersv2` update) and confirm they do nothing harmful, such as
sending a push. After the apply, re-run the dry run and expect `changed=0`.

Current migration scripts, both in `functions/package.json`:

```sh
cd functions
GOOGLE_CLOUD_PROJECT=prism-wallpapers npm run migrate:username-lower   # dry run: "scanned=N changed=M applied=false"
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

### 7b. Release notes (one source for Play and the App Store)

Collect the user-facing changes since the last release tag:
```sh
git log v<LAST_VERSION>..HEAD --no-merges --pretty=format:"- %s" \
  | grep -vE "^- (chore|style|test|ci|build|docs|refactor)"
```
Do not paste the list. Write **one** polished note from it:
- 80 to 140 words. Calm, premium, restrained. No emojis, no exclamation marks, no em dashes.
- Open with an observation about the release (craft, trust, momentum), not "What's new".
- Group changes into user-facing themes. Fold small fixes into one phrase, for example
  "Plus a number of fixes and improvements behind the scenes."
- End with a short closing line, for example "Quietly, a lot better." or "Refined where it matters."
- British spelling: the Play listing's default language is **en-GB** (also de-DE, es-ES, fr-FR).
- Leave out platform-only changes on the other store (no "Save to Photos" on Play).

**Play version:** at most **500 characters** (Play rejects the whole edit above that). Rewrite to
fit; never cut mid-sentence. Measure with `printf '%s' "$(cat notes-play.txt)" | wc -m`. Pass
it as locale-tagged JSON, because a bare `--release-notes` string is filed under en-US, which
no one sees on an en-GB listing:
```sh
python3 -c 'import json,sys; print(json.dumps([{"language":"en-GB","text":open(sys.argv[1]).read().strip()}]))' notes-play.txt > notes.json
```
Show the human both versions before any upload. The full note goes to TestFlight What to Test
and the App Store "What's New" (4000 characters max).

### 8. Android: upload (human decides the track and the rollout)

Preferred: `gplay`. It already has Release manager access to `com.hash.prism`.
```sh
gplay status --package com.hash.prism          # current tracks and version codes
gplay release --package com.hash.prism --track internal \
  --bundle build/app/outputs/bundle/release/app-release.aab \
  --release-notes @notes.json --wait   # notes.json from step 7b
```
Default to the `internal` track first. Promote later with `gplay promote`, and use `--rollout
0.1` (a fraction) for a staged production rollout. `--release-notes` as a bare string files the
note under en-US only; use a JSON file for more locales.

Fallbacks: fastlane lane `beta` (`cd android && bundle exec fastlane beta`, needs
`android/google-play-console.json`, and it goes straight to the `beta` track), or the human uploads
by hand in Play Console.

The **track and rollout fraction are the human's decision.** Never pick them yourself.

### 9. iOS: build the ipa

```sh
make build-ipa BUILD_NUMBER=<N> DOPPLER_CONFIG=prd
```

`build-ipa` obfuscates and uploads Sentry symbols the same way as `build-aab` (since the 3.0.9
release branch). If you run an older checkout without that change, iOS crash reports are not
symbolicated.

Output: `build/ios/ipa/Prism.ipa` (confirmed name from `.github/workflows/testflight.yml`, not
`Runner.ipa`).

**If the archive fails with `No Accounts` / `doesn't include signing certificate`** (Xcode has no
Apple ID signed in on this Mac), sign with the `prism` App Store Connect API key instead. Its key
file is `~/.asc/keys/AuthKey_B3QRNA5QHB.p8`; get the issuer with `asc --profile prism auth issuer-id`.
This is what shipped 3.0.9 (336):
```sh
fvm flutter build ios --config-only --release --build-number=<N> \
  --obfuscate --split-debug-info=build/ios/outputs/symbols $(DOPPLER_CONFIG=prd ./tool/dart_defines_from_doppler.sh)
AUTH=(-allowProvisioningUpdates -authenticationKeyPath ~/.asc/keys/AuthKey_B3QRNA5QHB.p8
      -authenticationKeyID B3QRNA5QHB -authenticationKeyIssuerID <issuer>)
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Release \
  -destination 'generic/platform=iOS' -archivePath build/ios/archive/Runner.xcarchive archive "${AUTH[@]}"
xcodebuild -exportArchive -archivePath build/ios/archive/Runner.xcarchive -exportPath build/ios/ipa \
  -exportOptionsPlist ExportOptions.plist "${AUTH[@]}"   # method app-store-connect, teamID X2955Z4CKQ, signingStyle automatic
DOPPLER_PROJECT=prism SENTRY_DOPPLER_CONFIG=prd DART_CMD="fvm dart" ./tool/sentry_upload.sh
```
The ipa is then `build/ios/ipa/prism.ipa` (lower case). Run this from a script file, and never echo
the defines. Do not use `.github/workflows/testflight.yml` as it is: it reads Doppler config
`production` and passes `SKIP_FIREBASE_INIT=true`, which ships an app with Firebase off.

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

What 3.0.9 (336) needed to get submitted through `asc review` (App Store Connect quirks):
- **Resubmitting a rejected version:** the version stays in the old submission (`UNRESOLVED_ISSUES`),
  which accepts no new items. `asc review submissions-cancel --id <old> --confirm` frees it
  (`CANCELING` then `COMPLETE`, about a minute), then add the version to a new submission.
- **First-time purchases go in the same submission:** add `inAppPurchaseVersions` and
  `subscriptionVersions` items, **plus the `subscriptionGroupVersions` item** while the group has no
  approved version. The paywall sells `prism_v3_pro_monthly`, `prism_v3_pro_annual` and
  `prism_v3_pro_lifetime_ios`. Never add the old non-renewing `prism_v3_pro_lifetime`.
- A draft submission (`READY_FOR_REVIEW`) can neither be cancelled nor have items removed, so
  build it in the right order and check `asc validate` shows 0 blocking first.
- RevenueCat paywall edits show only after a cold app start (the SDK caches the paywall).

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

## Known gaps

- `asc`: the local App Store Connect key belongs to another team and cannot see Prism. Use an API
  key from team `X2955Z4CKQ`, or the `.github/workflows/testflight.yml` workflow.
- The old classic `GH_TOKEN` still works and ships in store builds up to 3.0.8. Revoke it after a
  release that forces old versions to update.
- Firestore rules that refuse direct client writes to coins and premium are in the repo but not
  deployed. The human picks the timing (step 6).

See `references/troubleshooting.md` for error-mode detail on doppler-check failures, keystore
issues, and Play/TestFlight upload errors.
