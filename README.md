<div align="center">

<img src="demo/header.jpg" alt="Prism on iPhone: a wallpaper, the home feed with the Wall of the Day, and colour search" width="100%">

# Prism

Prism is an open-source wallpaper app for Android and iOS, built with Flutter and Dart by Hash Studios.

[![Release](https://img.shields.io/github/v/release/Hash-Studios/Prism?label=release&color=2ea44f)](https://github.com/Hash-Studios/Prism/releases/latest)
[![Flutter](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2FHash-Studios%2FPrism%2Fmaster%2F.fvmrc&query=%24.flutter&label=Flutter&logo=flutter&color=02569B)](.fvmrc)
[![Dart](https://img.shields.io/badge/Dart-language-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Platforms](https://img.shields.io/badge/platform-Android%20%7C%20iOS-555555)](#download)
[![License](https://img.shields.io/github/license/Hash-Studios/Prism?color=blue)](LICENSE.txt)
<br>
[![Google Play downloads](https://img.shields.io/badge/Google%20Play-100K%2B%20downloads-34A853?logo=googleplay&logoColor=white)](https://play.google.com/store/apps/details?id=com.hash.prism)
[![Stars](https://img.shields.io/github/stars/Hash-Studios/Prism?style=flat&color=yellow)](https://github.com/Hash-Studios/Prism/stargazers)
[![Last commit](https://img.shields.io/github/last-commit/Hash-Studios/Prism/master)](https://github.com/Hash-Studios/Prism/commits/master)
[![Telegram](https://img.shields.io/badge/Telegram-PrismWallpapers-26A5E4?logo=telegram&logoColor=white)](https://t.me/PrismWallpapers)
[![X](https://img.shields.io/badge/X-%40PrismWallpapers-000000?logo=x&logoColor=white)](https://x.com/PrismWallpapers)

[Website](https://prismwalls.com) · [Google Play](https://play.google.com/store/apps/details?id=com.hash.prism) · [Releases](https://github.com/Hash-Studios/Prism/releases) · [Changelog](CHANGELOG.md) · [Contributing](CONTRIBUTING.md)

</div>

Prism brings wallpapers from the community, Wallhaven, and Pexels into one feed that learns what you like.
Preview a wallpaper with a clock, set it in a few taps, or make it move.
Upload your own art, follow creators, make new wallpapers with AI, and earn Prism Coins as you go.

## Contents

1. [Features](#features)
2. [Screenshots](#screenshots)
3. [Download](#download)
4. [Repository layout](#repository-layout)
5. [Development setup (FVM)](#development-setup-fvm)
6. [Secrets with Doppler](#secrets-with-doppler)
7. [Common development commands](#common-development-commands)
8. [Contributing](#contributing)
9. [Support](#support)
10. [Contributors](#contributors)
11. [License](#license)
12. [Privacy](#privacy)

## Features

**Discover**

- Browse community wallpapers, Wallhaven, and Pexels, with a personalized home feed and a Wall of the Day.
- Search by keyword, color, or tag, with filters and recent searches. Open "More like this" to find similar wallpapers.
- Browse categories and collections, and follow creators.
- See this week's trending wallpapers in a row on the home feed. Open the Trending page for this week and all time.

**Preview, set, and edit**

- Preview wallpapers with a clock overlay. Set them with Fill or Fit, crop them, or pick a default target on supported platforms.
- Make any wallpaper move, pick a living gradient, or use a video as a live wallpaper (Android).
- See the wallpapers you set before and set them again.
- Edit wallpapers with stacked filters, blur, hue, saturation, and brightness controls.
- Rotate favourites or downloads on a timer, only while charging or in set hours, with Prism Pro on Android.
- Change the wallpaper on its own on iPhone with a Shortcuts automation and the "Get Prism Wallpaper" action. See [iOS Shortcuts](docs/features/ios-shortcuts.md).

**Create**

- Upload wallpapers for review and track their approval status.
- Generate AI wallpapers from text prompts, create variations, and share the results.

**Library and app**

- Save favourites to your account, then sort, filter, search, and select many at once. Share or delete many downloads at once.
- Read notifications in an inbox with unread marks, and set preferences in one sheet.
- Customize the app's theme and accent, and manage cached images and downloads.

**Prism Coins and Prism Pro**

- Earn Prism Coins through rewarded ads and daily rewards, and spend them on supported actions.
- Prism Pro makes all downloads and premium filters free.
- Pro members get a daily coin bonus and extra coins on each streak claim.
- Pro members have no weekly upload limit and can upload up to 10 wallpapers at once.
- Pro unlocks every live wallpaper style and auto-rotate on Android.

Platform capabilities vary. Android supports home-screen and lock-screen wallpaper actions. iOS supports saving images for manual application.
Premium access and coin costs depend on the action. The app shows the applicable gate before proceeding.

See [docs/features](docs/features/README.md) for a short page on each feature.

## Screenshots

<!--
  Most screenshots come from the redesign in PR #438 (iPhone). Clock preview, Set wallpaper, Filter editor,
  Favourites and Downloads come from later QA runs, and Live wallpaper, Auto-rotate and Pro wallpaper are widget renders.
  All sources are on the qa/screenshots branch.
-->

**Get started**

| <img src="demo/screens/onboarding-welcome.jpg" alt="Welcome screen with sign in" width="180"> | <img src="demo/screens/onboarding-interests.jpg" alt="Pick the wallpaper styles you like" width="180"> | <img src="demo/screens/onboarding-creators.jpg" alt="Follow suggested creators" width="180"> | <img src="demo/screens/tune-feed-sheet.jpg" alt="Tune your feed" width="180"> |
| :---: | :---: | :---: | :---: |
| Welcome | Pick your vibe | Find your people | Tune your feed |

**Discover**

| <img src="demo/screens/home.jpg" alt="Home feed with the Wall of the Day and trending wallpapers" width="180"> | <img src="demo/screens/search.jpg" alt="Search with recent searches and colours" width="180"> | <img src="demo/screens/search-colour-results.jpg" alt="Search results for a colour" width="180"> | <img src="demo/screens/collections-tab.jpg" alt="Collections" width="180"> |
| :---: | :---: | :---: | :---: |
| Home and trending | Search | Colour results | Collections |

**Preview, set, and edit**

| <img src="demo/screens/wallpaper-detail.jpg" alt="Wallpaper" width="180"> | <img src="demo/screens/wallpaper-detail-info-panel.jpg" alt="Wallpaper details and colours" width="180"> | <img src="demo/screens/clock-preview.jpg" alt="Lock screen clock preview" width="180"> | <img src="demo/screens/set-wallpaper.jpg" alt="Wallpaper set, with Match accent and Undo" width="180"> |
| :---: | :---: | :---: | :---: |
| Wallpaper | Details and colours | Clock preview | Set wallpaper |
| <img src="demo/screens/filter-editor.jpg" alt="Filter editor" width="180"> | <img src="demo/screens/live-wallpaper.jpg" alt="Live wallpapers" width="180"> | <img src="demo/screens/auto-rotate.jpg" alt="Auto-rotate settings" width="180"> | <img src="demo/screens/ios-shortcuts.jpg" alt="Change the wallpaper automatically with iOS Shortcuts" width="180"> |
| Filter editor | Live wallpaper | Auto-rotate | iOS Shortcuts |

**Create and collect**

| <img src="demo/screens/ai-wallpaper.jpg" alt="AI wallpaper" width="180"> | <img src="demo/screens/upload-wall-ready.jpg" alt="Upload a wallpaper" width="180"> | <img src="demo/screens/favourites.jpg" alt="Library: favourites" width="180"> | <img src="demo/screens/downloads-list.jpg" alt="Library: downloads" width="180"> |
| :---: | :---: | :---: | :---: |
| AI wallpaper | Upload | Favourites | Downloads |

**Profile and rewards**

| <img src="demo/screens/profile-own.jpg" alt="Your profile" width="180"> | <img src="demo/screens/edit-profile.jpg" alt="Edit profile" width="180"> | <img src="demo/screens/rewards-tab.jpg" alt="Rewards" width="180"> | <img src="demo/screens/daily-claim-sheet.jpg" alt="Daily streak reward" width="180"> |
| :---: | :---: | :---: | :---: |
| Profile | Edit profile | Rewards | Daily streak |
| <img src="demo/screens/share-prism-referral.jpg" alt="Invite friends" width="180"> | <img src="demo/screens/pro-wallpaper.jpg" alt="Pro wallpaper: save with coins or get Prism Pro" width="180"> | <img src="demo/screens/notifications.jpg" alt="Notifications" width="180"> | <img src="demo/screens/theme-manager.jpg" alt="Themes and accent colour" width="180"> |
| Invite friends | Pro wallpaper | Notifications | Themes and accent |

**Light theme (Frost White)**

| <img src="demo/screens/light-home.jpg" alt="Home in the Frost White theme" width="180"> | <img src="demo/screens/light-detail.jpg" alt="Wallpaper details in the Frost White theme" width="180"> | <img src="demo/screens/light-profile.jpg" alt="Creator profile in the Frost White theme" width="180"> | <img src="demo/screens/light-theme-manager.jpg" alt="Themes in the Frost White theme" width="180"> |
| :---: | :---: | :---: | :---: |
| Home | Wallpaper | Creator profile | Themes |

## Download

<a href="https://play.google.com/store/apps/details?id=com.hash.prism"><img alt="Get it on Google Play" src="https://play.google.com/intl/en_us/badges/static/images/badges/en_badge_web_generic.png" height="80"></a>

Get Prism for Android on [Google Play](https://play.google.com/store/apps/details?id=com.hash.prism).
Release notes and build files for each version are on [GitHub Releases](https://github.com/Hash-Studios/Prism/releases). The [changelog](CHANGELOG.md) lists every change.

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
If you like Prism, rate it on [Google Play](https://play.google.com/store/apps/details?id=com.hash.prism) and star this repository.
You can support development through [Buy Me a Coffee](https://www.buymeacoffee.com/HashStudios):

<a href="https://www.buymeacoffee.com/HashStudios"><img src="https://cdn.buymeacoffee.com/buttons/default-orange.png" alt="Buy Me a Coffee" height="51" width="217"></a>

## Contributors

See the [contributors](https://github.com/Hash-Studios/Prism/graphs/contributors) who maintain Prism.

<a href="https://github.com/Hash-Studios/Prism/graphs/contributors"><img src="https://contrib.rocks/image?repo=Hash-Studios/Prism" alt="Prism contributors"></a>

## License

Prism uses the [BSD 3-Clause License](LICENSE.txt).

Google Play and the Google Play logo are trademarks of Google LLC.

## Privacy

Read [PRIVACY.md](PRIVACY.md) for data collection and third-party services.
