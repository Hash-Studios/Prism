# Prism

Prism is an open-source wallpaper app for Android and iOS, built with Flutter and Dart by Hash Studios.

[Google Play](https://play.google.com/store/apps/details?id=com.hash.prism) · [Releases](https://github.com/Hash-Studios/Prism/releases) · [Changelog](CHANGELOG.md) · [Contributing](CONTRIBUTING.md)

## Features

- Browse community wallpapers, Wallhaven, and Pexels, with a personalized home feed and a Wall of the Day.
- Search by keyword, color, or tag, with filters and recent searches. Open "More like this" to find similar wallpapers.
- Browse categories and collections, and follow creators.
- See this week's trending wallpapers in a row on the home feed. Open the Trending page for this week and all time.
- Save favourites to your account, then sort, filter, search, and select many at once. Share or delete many downloads at once.
- Preview wallpapers with a clock overlay. Set them with Fill or Fit, crop them, or pick a default target on supported platforms.
- Make any wallpaper move, pick a living gradient, or use a video as a live wallpaper (Android).
- See the wallpapers you set before and set them again.
- Edit wallpapers with stacked filters, blur, hue, saturation, and brightness controls.
- Upload wallpapers for review and track their approval status.
- Generate AI wallpapers from text prompts, create variations, and share the results.
- Earn Prism Coins through rewarded ads and daily rewards, and spend them on supported actions.
- Read notifications in an inbox with unread marks, and set preferences in one sheet.
- Customize the app's theme and accent, and manage cached images and downloads.
- Rotate favourites or downloads on a timer, only while charging or in set hours, with Prism Pro on Android.
- Change the wallpaper on its own on iPhone with a Shortcuts automation and the "Get Prism Wallpaper" action. See [iOS Shortcuts](docs/features/ios-shortcuts.md).

Platform capabilities vary. Android supports home-screen and lock-screen wallpaper actions. iOS supports saving images for manual application.
Premium access and coin costs depend on the action. The app shows the applicable gate before proceeding.

See [docs/features](docs/features/README.md) for a short page on each feature.

## Repository layout

| Path | Purpose |
| --- | --- |
| [`lib/`](lib/) and [`test/`](test/) | Flutter app and unit/widget tests |
| [`android/`](android/) and [`ios/`](ios/) | Native platform projects |
| [`pigeons/`](pigeons/) | Source definitions for platform APIs |
| [`functions/`](functions/) | Firebase Cloud Functions, written in TypeScript |
| [`firestore.rules`](firestore.rules) and [`firestore.indexes.json`](firestore.indexes.json) | Firestore access rules and indexes |
| [`web/`](web/) | Next.js website |
| [`infra/cloudflare/`](infra/cloudflare/) | Worker for deep links, social previews, and AI requests |
| [`packages/cloud_functions/`](packages/cloud_functions/) | Local FlutterFire plugin fork |
| [`tool/`](tool/) and [`Makefile`](Makefile) | Development commands, generation, and repository checks |

The app uses BLoC, freezed, get_it/injectable, and auto_route. See [architecture guidance](CLAUDE.md#architecture) for feature structure.
Dependency versions live in [`pubspec.yaml`](pubspec.yaml), [`functions/package.json`](functions/package.json), and [`web/package.json`](web/package.json).

## Development setup (FVM)

Install [FVM](https://fvm.app/documentation/getting-started/installation), Make, and a POSIX shell.
Android development needs the Android SDK. iOS development needs macOS, Xcode, and CocoaPods.

### Clone the repository

Use a shallow, single-branch clone when you do not need old commit history:

```sh
git clone --depth 1 --single-branch https://github.com/Hash-Studios/Prism.git
```

Use a single-branch blobless clone when you need commit ancestry but can fetch file contents on demand:

```sh
git clone --filter=blob:none --single-branch https://github.com/Hash-Studios/Prism.git
```

A full clone fetches every branch, including `qa/screenshots`, and historical binaries. Sparse checkout limits files in your working tree, but does not avoid fetching history. Fetch another branch when you need it:

```sh
git fetch origin branch-name:refs/remotes/origin/branch-name
```

Keep tracked files at or below 1 MiB. Store APK, AAB, and IPA release files on [GitHub Releases](https://github.com/Hash-Studios/Prism/releases). Run `make repo-assets-check` to check tracked files before opening a pull request; `make ci` runs the same check.

From the repository root, run:

```sh
make setup
fvm flutter doctor -v
```

`make setup` installs and selects the Flutter SDK pinned in [`.fvmrc`](.fvmrc), then resolves app dependencies.
On macOS, it also prepares iOS pods. Use `fvm flutter` and `fvm dart` for subsequent SDK commands.
Prism's Flutter app needs a mobile device, emulator, or simulator. The separate Next.js website runs in a browser.

### Local checks without service access

A fresh checkout has no `lib/firebase_options.dart`. Create the ignored stub for local analysis and tests:

```sh
tool/write_firebase_options_stub.sh
make format-check
fvm flutter analyze --no-pub --no-fatal-infos
make test
```

The stub script preserves an existing real Firebase options file. Do not commit Firebase configuration files.
For a UI-only debug run without Doppler or Firebase access, use:

```sh
fvm flutter run --dart-define=SKIP_FIREBASE_INIT=true
```

Firebase-backed feeds, sign-in, notifications, and rewards need real development service configuration.
A run that skips Firebase does not verify those features.

## Secrets with Doppler

Runtime secrets come from Doppler, using project `prism` and local configuration `dev`.
`.env.example` lists key names for reference. Make targets do not load it as a runtime secrets file.

Obtain development service access and Firebase configuration from a maintainer. The app needs matching local files:

- `lib/firebase_options.dart`
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`

Replace any Firebase stubs before a service-backed run. Install the [Doppler CLI](https://docs.doppler.com/docs/install-cli), then run:

```sh
make doppler-login
make setup-dev
make run
```

`make run` injects Dart defines from Doppler. If the Android Google Services file is absent, it skips Firebase initialization, including on iOS.
See the [Doppler workflow](docs/development/doppler.md) for access checks, secret updates, and troubleshooting.
The [contribution guide](CONTRIBUTING.md) covers configuration for your own development Firebase project.

## Common development commands

Run these commands from the repository root:

| Command | Purpose |
| --- | --- |
| `make get` | Resolve Flutter dependencies with FVM |
| `make run` | Run the app with development secrets from Doppler |
| `make format` / `make format-check` | Format Dart source / check formatting |
| `make test` | Run Flutter unit and widget tests |
| `fvm flutter analyze --no-pub --no-fatal-infos` | Run static analysis without treating infos as failures |
| `make file-gen` | Regenerate freezed, JSON, route, and dependency injection code |
| `make pigeon-gen` | Regenerate native platform APIs |
| `make analytics-gen` / `make analytics-check` | Generate typed analytics events / check the generated output |
| `make ci ANALYZE_FLAGS=--no-fatal-infos` | Run the complete local app and worker gate |

The local app gate also needs Node.js 22.6 or newer for worker tests.
Functions, website, and Firestore rules checks run separately. See [Contributing](CONTRIBUTING.md) for their commands and UI verification requirements.
[`web/README.md`](web/README.md) covers website development, and [`infra/cloudflare/README.md`](infra/cloudflare/README.md) covers the worker.

GitHub CI runs on pull requests that are ready for review and selects jobs by changed paths. Draft PRs skip the checks.
The required `ci` check aggregates app, functions, website, and rules results. See the [CI workflow](.github/workflows/ci.yml).

## Contributing

Read [CONTRIBUTING.md](CONTRIBUTING.md) before submitting a change. Open a focused PR against `master` with the linked issue and verification results.
Report bugs through the [issue templates](https://github.com/Hash-Studios/Prism/issues/new/choose).

## Support

Contact Hash Studios at hash.studios.inc@gmail.com, join the [Telegram community](https://t.me/PrismWallpapers), or follow [Prism Wallpapers](https://twitter.com/PrismWallpapers).
You can support development through [Buy Me a Coffee](https://www.buymeacoffee.com/HashStudios).
See the [contributors](https://github.com/Hash-Studios/Prism/graphs/contributors) who maintain Prism.

## License

Prism uses the [BSD 3-Clause License](LICENSE.txt).

## Privacy

Read [PRIVACY.md](PRIVACY.md) for data collection and third-party services.
