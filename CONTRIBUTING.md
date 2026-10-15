# Contributing to Prism

Prism is a Flutter wallpaper app for Android and iOS. Contributions include bug reports, documentation, tests, and code changes.

## Report a bug or propose a change

Use the [GitHub issue templates](https://github.com/Hash-Studios/Prism/issues/new/choose). Check existing issues and pull requests before opening one.

For a bug report, include:

- The Prism version and installation source.
- The device model, operating system, and steps to reproduce the bug.
- The expected result and actual result.
- Screenshots or the relevant error log, with account details and tokens removed.

For a development setup failure, also include your checkout commit, `fvm flutter doctor -v` output, the command you ran, and its error.
For a feature request, describe the user problem and proposed behavior. Discuss large changes before starting implementation.

## Prepare your checkout

1. Fork the repository and create a branch from `master`.
2. Install [FVM](https://fvm.app/documentation/getting-started/installation) with its required host Dart SDK.
3. Install Make and a POSIX shell. On Windows, use Git Bash or MSYS2 for the Makefile commands.
4. Install the Android SDK for Android development. For iOS development, use macOS with Xcode and CocoaPods.
5. From the repository root, run:

```sh
make setup
fvm flutter doctor -v
```

`make setup` installs and selects the Flutter version in [`.fvmrc`](.fvmrc), then resolves dependencies.
On macOS, it also prepares iOS pods and installs a Firebase plist stub if the real file is absent.
Fix the toolchain errors for your target platform reported by `flutter doctor` before running the app.

Use `fvm flutter` and `fvm dart` so your commands use the pinned SDK. Follow one of the setup paths below.

### Run local checks without service access

You do not need Doppler access or a Firebase project for analysis and unit or widget tests.
Generate the ignored Firebase options stub before running those checks:

```sh
tool/write_firebase_options_stub.sh
make format-check
fvm flutter analyze --no-pub --no-fatal-infos
make test
```

The script preserves an existing real `lib/firebase_options.dart`. Never commit that file or the native Firebase configuration files.

For a UI-only debug run on an emulator, simulator, or connected device, use:

```sh
fvm flutter run --dart-define=SKIP_FIREBASE_INIT=true
```

This skips Firebase initialization. Firebase-backed feeds, sign-in, notifications, and rewards cannot serve as verification of live behavior in this mode.
Use the service setup below when your change needs those features. Prism's Flutter app does not run in a desktop browser.

### Run with development services

1. Install the [Doppler CLI](https://docs.doppler.com/docs/install-cli) and obtain access to the `prism/dev` configuration from a maintainer.
2. Obtain the development Firebase configuration from a maintainer. For your own development project, install the [Firebase and FlutterFire CLIs](https://firebase.google.com/docs/flutter/setup) and run:

```sh
firebase login
flutterfire configure --project=YOUR_DEV_FIREBASE_PROJECT_ID --platforms=android,ios
```

Replace `YOUR_DEV_FIREBASE_PROJECT_ID` with your development project ID. Confirm these local files belong to the same project:

- `lib/firebase_options.dart`
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`

Replace the iOS plist stub if setup created it. Configure the required authentication providers and Android signing fingerprints in your development Firebase project.
An independent project also needs the backend services and runtime secrets for the features you exercise.
The checked-in [Firebase configuration](firebase.json), [Firestore rules](firestore.rules), [indexes](firestore.indexes.json), and [Cloud Functions](functions/src/) define the current backend.
Use those sources instead of copying an old schema or permissive rules. Do not deploy to the maintained project as part of local setup.

Then, from the repository root, authenticate and run:

```sh
make doppler-login
make setup-dev
make run
```

`make run` loads runtime secrets from Doppler. Without `android/app/google-services.json`, it adds `SKIP_FIREBASE_INIT=true`, including for iOS runs.
Have that file present for a Firebase-backed run. See the [Doppler workflow](docs/development/doppler.md) for configuration and troubleshooting.

For VS Code, use **Prism: Run (make)** or **Prism: Run (direct fvm + env)** in [`.vscode/launch.json`](.vscode/launch.json).
Both configurations require Doppler access. The direct configuration prepares an ignored file of Dart defines before launch.

## Make and verify your change

Keep each pull request focused on one change. Follow nearby feature code and the [architecture guidance](CLAUDE.md#architecture).
For UI changes, follow the [design guidance](.impeccable.md) and use theme colors and accessible control labels.

Use single quotes, package imports, and the repository's 120-column Dart format:

```sh
make format
```

After changing models, routes, or dependency injection registrations, run `make file-gen` and include the generated files in your commit.
For Pigeon host API changes, run `make pigeon-gen`.
Add a regression test for a bug fix and update documentation when behavior or setup changes.

For app changes, run the full local gate:

```sh
make ci ANALYZE_FLAGS=--no-fatal-infos
```

This runs Flutter tests, analysis, formatting, repository guards, and Cloudflare worker checks. It requires Node.js 22.6 or newer for the worker checks.
The analysis flag permits existing info-level findings, including the package-name info. Fix warnings, errors, and new findings introduced by your change.
`make ci` covers the app and worker checks. Run the relevant backend checks separately.

For Cloud Functions changes, use Node.js 24 and run from `functions/`:

```sh
npm ci
npm run build
npm run lint
node --test lib/__tests__/*.test.js
```

For website changes, use Node.js 24 and run from `web/`:

```sh
npm ci
npx tsc --noEmit
npm run build
```

For Firestore rules changes, install the Firebase CLI and the Java version required by its emulator, then run `make rules-test` from the repository root.
The current [CI workflow](.github/workflows/ci.yml) uses Java 21 and a local `demo-prism` project for this check.
For UI changes, exercise the real user path on Android and iOS and capture the before and after states.
The [device verification guide](.claude/skills/verify-prism/SKILL.md) describes the repository's QA devices and screenshot commands.

## Keep secrets and backend changes scoped

Runtime secrets belong in Doppler. `.env.example` is a reference for key names, not a runtime secrets file.
When adding a secret, update the relevant Doppler configuration, `.env.example`, and `lib/env/env.dart` if the app reads it.
Run `make secrets-guard` and `make env-guard`.

Never commit credentials, signing keys, generated Firebase configuration, or logs that contain tokens.
Check the staged diff before committing. Keep coin, premium, refund, and upload validation in the server code.
For a new callable or a rules change, explain the deployment order and compatibility with installed app versions in the pull request.
Deployment, data migration, and store publication are separate maintainer actions.

## Open a pull request

Target `master` and include:

- The problem and resulting behavior, with a linked issue.
- The local commands you ran and their results.
- Device screenshots for UI changes, plus any device or service checks you could not complete.
- Backend deployment or compatibility requirements, if applicable.

Optionally run `make hooks` to enable the repository's pre-push checks.
GitHub CI runs on pull requests that are ready for review, and skips drafts.
Its jobs run according to the changed paths. The required `ci` check combines the app, functions, website, and rules results.
Unrelated jobs can be skipped. Local tests and screenshots do not establish hosted CI or deployed behavior.

Contributions use the repository's [BSD 3-Clause License](LICENSE.txt).
