---
name: verify-prism
description: Drive the Prism Flutter wallpaper app on the iOS Simulator and the Android emulator the way a user does. Launch it, check its health, tap through a mapped feature, and capture screenshots plus accessibility or view trees. Use this skill to prove a user-facing change, or to reproduce a UI bug, on the real app.
---

# Verify Prism (iOS Simulator + Android emulator)

Primary surface: the **Flutter app** (package `com.hash.prism`, product name `Prism`), driven on:

- **iOS Simulator**, with the `axe` CLI.
- **Android emulator**, with `adb` and `uiautomator`.

There is no existing e2e harness in this repo. This skill's `bin/verify-prism` script is the whole harness: it wraps `axe` and `adb` directly. Do not add a second tap stack.

Read `features/README.md` before driving. Drive the feature file, not a convenient shortcut.

## Our devices only

Use only these two devices. Never boot, erase, wipe, or drive any other simulator or emulator, even if one is already booted or running.

- **iOS**: simulator named `Prism QA iPhone 17 Pro`. Resolve its UDID by name at run time, do not hardcode one. It exists on this Mac as of 2026-10-29 (iOS 27.0). If `doctor` says it is missing, create it once, then reuse it:
  ```bash
  xcrun simctl list runtimes                 # pick the iOS runtime id
  xcrun simctl create "Prism QA iPhone 17 Pro" "iPhone 17 Pro" <runtime-id>
  ```
  `doctor` tells you if it is missing. If another simulator is booted (there usually is one), leave it running and driving; `axe` and `simctl` both take `--udid`, so two booted simulators do not conflict. Just never tap, screenshot, install to, or terminate anything on a UDID that is not ours.
- **Android**: AVD `Prism_QA_API36`, always on port 5580 (adb serial `emulator-5580`). Boot it yourself in a separate shell before `launch`:
  ```bash
  emulator -avd Prism_QA_API36 -port 5580
  ```
  Emulators on ports 5554 and 5570 belong to other agents or the human. Do not touch them. `doctor` lists any other running emulator as "do not touch".

Override the resolved device only with `PRISM_VERIFY_IOS_UDID` or `PRISM_VERIFY_ANDROID_SERIAL`, and only when the human asks for a different one of our own devices.

## Sign-in is the human's job

Prism has no E2E anonymous sign-in shortcut. `Continue with Google` and `Continue with Apple` (see `lib/features/onboarding_v2/src/views/onboarding_v2_shell.dart`) open real OAuth. Never type an email, password, or OTP into the app or the simulator's own Safari/Chrome.

- To verify signed-out screens (Welcome, onboarding, browsing feeds, wallpaper detail as a guest), drive them directly. Routes guarded by `_signedInGuard` in `lib/core/router/app_router.dart` redirect a signed-out user to `/onboarding/v2`.
- To verify a signed-in screen, ask the human to sign in on the device first, then drive from there. Say so instead of improvising a workaround.
- Following a real account, liking a real post, or any action that could notify a real user sends that user a push. Ask the human before doing this, same as any other real-user side effect.

## Launch

Repo root is the Flutter workspace (`pubspec.yaml` name: `Prism`). Bundle id / package: `com.hash.prism` (both platforms; iOS `RunnerTests` uses a different, irrelevant id).

**Build, without Doppler** (per `AGENTS.md`; `make run` / `make build-ios` need Doppler secrets you likely do not have here):

```bash
fvm flutter build ios --debug --simulator --dart-define=SKIP_FIREBASE_INIT=true
fvm flutter build apk --debug --dart-define=SKIP_FIREBASE_INIT=true
```

`SKIP_FIREBASE_INIT=true` is enough for UI-only proof. If a recipe needs real Firebase-backed data (feeds, coins, notifications), use Doppler dev secrets instead:

```bash
DOPPLER_PROJECT=prism DOPPLER_CONFIG=dev python3 tool/flutter_with_doppler.py -- \
  fvm flutter run
```
The runner passes allowlisted app settings directly as argv without printing values. Replace
`fvm flutter run` with the required debug build command if needed. Real native Firebase config
and Dart options must already exist for Firebase-backed debug verification.

In a T3 worktree, copy the gitignored `ios/Runner/GoogleService-Info.plist`, `android/app/google-services.json`
and `lib/firebase_options.dart` from the main checkout first. The Doppler token is scoped to the main checkout,
so pass it without printing it. This builds, installs and launches on our simulator (proven 2026-10-29):

```bash
TOK=$(doppler configure get token --plain --scope <main checkout>)
env DOPPLER_TOKEN="$TOK" DOPPLER_PROJECT=prism DOPPLER_CONFIG=dev python3 tool/flutter_with_doppler.py -- \
  fvm flutter run --debug --no-resident -d <our udid> < /dev/null
```

Installing over the existing app keeps its sign-in. A Flutter build can rewrite `lib/l10n/generated/*`; check
`git status` before you commit.

**One lock per platform.** The helper takes `/tmp/prism-verify-ios.lock` and `/tmp/prism-verify-android.lock`. If a lock is held by a live run, **stop**; run `cleanup` first. Override only with `PRISM_VERIFY_TAKEOVER=1` after you confirm the other run is done.

**Start a verification instance** (from repo root):

```bash
.claude/skills/verify-prism/bin/verify-prism launch --platform ios [--fresh] [--build]
.claude/skills/verify-prism/bin/verify-prism launch --platform android [--fresh] [--build]
```

`--build` runs the `fvm flutter build` command above first. `--fresh` resets app state (iOS keychain reset + reinstall if a local build exists; Android `pm clear` + reinstall) before launching. Without `--fresh`, launch reuses whatever is already installed, which may already be signed in.

**Teardown** (always, including failed runs):

```bash
.claude/skills/verify-prism/bin/verify-prism cleanup --platform ios
.claude/skills/verify-prism/bin/verify-prism cleanup --platform android
```

Cleanup terminates/force-stops the app on our device only, drops that platform's lock, and keeps `artifacts/`. It does not quit Simulator.app, does not kill the emulator process, and does not delete evidence. It refuses (exit 3) when another run holds the lock, so it never stops a peer's app.

## Doctor

Run this first whenever anything looks off, and after every failed drive before retrying:

```bash
.claude/skills/verify-prism/bin/verify-prism doctor                 # both platforms
.claude/skills/verify-prism/bin/verify-prism doctor --platform ios
.claude/skills/verify-prism/bin/verify-prism doctor --platform android
```

It is read-only. It checks: `axe` on PATH (>= 1.7) for iOS, `adb`/`emulator` on PATH for Android, whether our named device exists and its boot state, any other booted/running device (printed as "do not touch", never acted on), whether the lock is free or held by this run, and whether `com.hash.prism` is installed. A lock held by another run (even a free-text lock a peer wrote by hand) fails `doctor`. Exit 0 means drive it; any other exit means fix the printed cause first.

## Drive

Helper commands (repo root), same shape on both platforms via `--platform`:

```bash
.claude/skills/verify-prism/bin/verify-prism describe --platform ios
.claude/skills/verify-prism/bin/verify-prism tap --platform ios --label "Continue with Apple"
.claude/skills/verify-prism/bin/verify-prism tap --platform android --text "Home"
.claude/skills/verify-prism/bin/verify-prism type --platform ios --text "hello"
.claude/skills/verify-prism/bin/verify-prism snapshot --platform ios --tag home
```

- **iOS**: `describe`/`tap`/`type` shell out to `axe describe-ui` / `axe tap --label` / `axe type`. Prefer `--label` (accessibility label) over `-x/-y` coordinates.
- **Android**: `describe` dumps the `uiautomator` view tree; `tap` matches a node's `text` or `content-desc` and taps its bounds' center; `type` shells out to `adb shell input text` (US keyboard characters only, same limits as `axe type`).
- **Android UiAutomation is single-client.** While another client is connected (the T3 `agent-device` session, Appium), `describe`, `tap` and `snapshot` fail with `uiautomator dump failed (exit 137)`. Close that session first (`agent-device close`).
- **Host load.** When the Mac's load average is very high (other sessions building), `screencap` and `uiautomator dump` can time out. Check `uptime` and retry once.
- Prefer accessibility labels / text from live Dart source (see `features/*.md`) over coordinates or memorized strings; source drifts, re-check with `describe` when a tap misses.

**When `axe describe-ui` shows only `Application`** (iOS): the Flutter accessibility tree did not attach. Fall back to the Dart VM service, or `lldb` the `Runner` process for `FlutterView.accessibilityElements`, per prior QA notes. This has happened before with `Semantics(container)` gaps around sliders in a popped route. It also happens after the iOS system photo picker closes (upload flow, 2026-10-29): the tree stays empty until the app relaunches. Drive by screenshot and coordinates, then relaunch.

**Jumping to a page**: use its documented URL through `simctl openurl` or Android's VIEW intent. The [deep-link recipe](features/deep-links.md) and [page catalog](../../../docs/features/deep-links.md) cover all page families, including picker continuations for local images. This exercises the same dispatcher as external links and push taps. Keep normal sign-in and admin guards in place.

**Signed-in debug builds (Android).** Google sign-in fails on a debug build: the debug key is not registered in
Firebase, and the failure looks like a cancel (`signInWithGoogle canceled by user`). For a signed-in debug run, sign
the debug build with the release key in a local, uncommitted change to `android/app/build.gradle`
(`buildTypes { debug { signingConfig signingConfigs.release } }`), with `android/key.jks` and `android/key.properties`
copied from the main checkout. Revert the Gradle change before you commit. Release builds strip app logs, so use
this debug run whenever you need logs from a signed-in path.

**Restarting the app.** Open `prism://settings` and use Restart App, or terminate and launch the QA app for a cold-start test. Logout and account deletion also restart the app; verify that they discard pending destinations.

**Full route map**: `lib/core/router/app_router.dart` (`AppRouter.routes`). Routes with `guards: [_signedInGuard]` need a signed-in human first; `guards: [_adminGuard]` need an admin account, skip those unless the human says otherwise.

## Evidence

Proof root: `.claude/skills/verify-prism/artifacts/<run_id>/`. `<run_id>` is printed by `launch` and stored in `/tmp/prism-verify-<platform>.state`. `snapshot --tag <name>` writes:

- `<tag>.png`: device screenshot
- `<tag>.tree.txt`: accessibility tree (iOS) or view tree (Android): type/class, label/text, value, id
- `<tag>.meta.txt`: device id, package, timestamp, tag

Proof standards:

- Exercise the **real user path** (bottom nav, top bar, sheets, deep links). Do not call test-only shortcuts; there are none in this app for auth, so drive signed-out flows or ask the human to sign in.
- Capture the **action and the resulting state**, not only the last frame (for example: wallpaper detail before tap + the "Set as wallpaper" sheet after).
- Check side effects when the user would: a saved favourite must reappear in Favourites, not only a toast.
- `SKIP_FIREBASE_INIT=true` is a **verification flavor** for UI-only proof; screens that read Firestore (feeds, coins, streak, notifications inbox) will look empty or stuck under it. Say so in the proof notes, and use Doppler dev secrets instead when the feature needs real data.
- Cleanup must leave this directory on disk. Git ignores its contents (`.gitignore` in `artifacts/`); they are local proof, not source.
- For screenshots that go into a PR description (not just local proof), the project convention is the orphan branch `qa/screenshots` (`qa-YYYY-MM-DD/*.jpg`), embedded via `raw.githubusercontent.com` URLs. That is a separate, human-reviewed publishing step; do not push to it automatically.

## Helpers

Executable: `.claude/skills/verify-prism/bin/verify-prism`

| Command | Purpose |
| --- | --- |
| `doctor [--platform ios\|android\|both]` | Read-only health check |
| `launch --platform <p> [--fresh] [--build]` | Lock + boot/verify device + install + launch |
| `describe --platform <p>` | Print accessibility/view tree |
| `tap --platform <p> [--label\|--text/--desc\|--x/--y]` | Tap by label (iOS) or text/desc (Android) |
| `type --platform <p> --text <t>` | Type text |
| `snapshot --platform <p> --tag <t>` | Screenshot + tree + meta into `artifacts/` |
| `cleanup --platform <p>` | Terminate app this run started; keep artifacts |

## Features

See `features/README.md` for the full index and driving conventions, then the matching file:

- [Onboarding and sign-in](./features/onboarding-signin.md)
- [Home feed](./features/home-feed.md)
- [Wallpaper detail](./features/wallpaper-detail.md)
- [Search](./features/search.md)
- [Profile and edit profile](./features/profile.md)
- [Rewards and coins](./features/rewards.md)
- [AI wallpaper](./features/ai-wallpaper.md)
- [Notifications inbox](./features/notifications.md)
- [Settings](./features/settings.md)
- [Deep links](./features/deep-links.md)
- [Library and Folders](./features/library-folders.md)
- [Drops, Shop and Premium](./features/drops-shop-premium.md)
- [Upload](./features/upload.md)
