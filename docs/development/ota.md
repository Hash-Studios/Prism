# Over-the-air updates with Shorebird

Prism uses Shorebird Cloud code push. A patch replaces Dart code in a store release.

A patch cannot change native code, plugins, assets, fonts, permissions, or the version and build number.

The app id is in `shorebird.yaml`. A store release embeds the public verification key so the app can verify signed patches. The app never has the private patch-signing key or the Shorebird publishing token.

## When to patch and when to ship a store build

| Change | Ship as | Notes |
|---|---|---|
| Dart-only bug fix | Patch | |
| Copy or layout change in Dart | Patch | |
| Logic fix in Dart | Patch | |
| Any change under a native path (see the list below) | Store build | |
| New or changed dependency (`pubspec.yaml`, `pubspec.lock`) | Store build | |
| Flutter version change (`.fvmrc`) | Store build | |
| Assets, fonts and shaders | Store build | |
| Storage code (see the list below) | Patch only with `ALLOW_STORAGE_CHANGES=1` | Read the data-migration warning first. |

The native paths are the `NATIVE_PATHS` list in `tool/shorebird_ota.py`. A change under any of these paths needs a store build:

| Path | Meaning |
|---|---|
| `android/` | Android project. Includes `AndroidManifest.xml` with the permissions. |
| `ios/` | iOS project. Includes `Info.plist`. |
| `packages/` | Local packages, such as the vendored `packages/cloud_functions/`. |
| `pigeons/` | Pigeon host API definitions. |
| `lib/core/platform/pigeon/` | Generated Dart code for the Pigeon host APIs. |
| `assets/` | Bundled files. |
| `shaders/` | Shader files. |
| `pubspec.yaml` | Dependencies and declared assets. |
| `pubspec.lock` | Locked dependency versions. |
| `shorebird.yaml` | Shorebird app id and update setting. |
| `.fvmrc` | Pinned Flutter version. |

The storage guard checks `STORAGE_PATHS`, `STORAGE_SUFFIXES`, and `STORAGE_API` in `tool/shorebird_ota.py`. A patch that changes storage code is refused unless you pass `ALLOW_STORAGE_CHANGES=1`. Storage code is:

- Any change under `lib/core/persistence/` or `lib/core/offline/`.
- Any `lib/` file named `*_local_data_source.dart` or `*_store.dart`.
- Any changed `lib/` line that uses `SettingsLocalDataSource`, `SharedPreferences`, `PersistenceKeys`, `DurableJsonStore`, `LocalStore` or `settings.get/set/delete`.

## First release note

Users get OTA patches only after they install a store build made with `shorebird release`. Use `make release-android`, `make release-ios`, or the two release workflows.

A build made with `flutter build` never gets patches.

The first patch for a release can only reach users on that release.

## How the app updates

The dashboard hosts the update check. The dashboard loads after startup, onboarding, and blocking prompts finish, so the check waits for them.

- The app checks for a patch when the dashboard opens. It checks again when the app resumes.
- A 15-minute cooldown applies between checks.
- Only one check or download runs at a time.
- The app downloads a patch in the background.
- The app records the pending restart with the release version, the build, and the patch number.
- The app shows one toast for each release and patch: "Close and reopen Prism to finish updating."
- The toast waits while another screen, a sheet or a paywall is on top, or while the app is not in front.
- The patch applies on the next launch.
- A rollback works the same way.
- Debug, profile, and non-Shorebird builds skip all of this.
- Offline and failed downloads are silent. The app records only an analytics event.

The app sends these analytics events:

- `ota_check_started`
- `ota_update_available`
- `ota_download_done`
- `ota_download_failed`, with a `reason` value
- `ota_patch_running`, when a patch runs for the first time

The Sentry scope tag `shorebird_patch` holds the running patch number.

Admin testers see two debug panel controls:

- The Tools tab has the switch "Get staging patches".
- The App info tab shows the row "Shorebird patch" with the patch number.

## One-time setup (owner)

a. Create a Shorebird account and organization at https://console.shorebird.dev. Create the app "Prism" in the console. Put its app id in `shorebird.yaml`. Replace `REPLACE_WITH_SHOREBIRD_APP_ID`. Keep `auto_update: false`. Commit this change in a pull request.

b. Install the pinned CLI, version 1.6.133:

```sh
git clone --depth 1 --branch v1.6.133 https://github.com/shorebirdtech/shorebird.git ~/.shorebird
export PATH="$HOME/.shorebird/bin:$PATH"
shorebird --version
```

To change the pin, edit `CLI_VERSION` in `tool/shorebird_ota.py`. CI reads the same value.

c. Create a CI API key. In the console, open Account, then API Keys, then Create API Key. A service account key is better for shared CI. Store the key in Doppler:

```sh
doppler secrets set SHOREBIRD_TOKEN --project prism --config prd
```

Paste the value when Doppler asks. Never print the value. The CI workflow reads Doppler with the GitHub secret `DOPPLER_TOKEN_PRODUCTION`, then reads `SHOREBIRD_TOKEN` from Doppler. An environment variable named `SHOREBIRD_TOKEN` wins over Doppler.

The wrapper accepts a printable ASCII token with no whitespace. It rejects invalid tokens without printing the value.

d. Make the patch signing key pair on a trusted machine:

```sh
openssl genrsa -out private.pem 2048
openssl rsa -in private.pem -outform PEM -pubout -out public.pem
doppler secrets set SHOREBIRD_PATCH_PRIVATE_KEY --project prism --config prd < private.pem
doppler secrets set SHOREBIRD_PATCH_PUBLIC_KEY --project prism --config prd < public.pem
```

Keep an offline backup of `private.pem` in your password manager. Then delete the local `private.pem` and `public.pem` files.

The wrapper creates public and private key files with mode `0600` inside a private temporary directory. It removes the directory after success, failure, or `SIGTERM`. `SIGKILL` cannot run cleanup, so a killed process may leave temporary files behind.

WARNING: If you lose the private key, no patch can ever be made for releases built with its public key. The only fix is a new store release.

e. Check the secret names only:

```sh
doppler secrets --project prism --config prd --only-names
```

Look for `SHOREBIRD_TOKEN`, `SHOREBIRD_PATCH_PRIVATE_KEY`, and `SHOREBIRD_PATCH_PUBLIC_KEY`.

f. Optional: add these Remote Config keys for the store-update prompt:

- `min_build_android` (number)
- `min_build_ios` (number)
- `store_update_blocking` (boolean)

A store build below the minimum build gets a prompt to update from the Play Store or the App Store. The prompt can be dismissed. If `store_update_blocking` is true, the build gets the blocking old-version screen instead. A value of 0 turns the prompt off.

Patches never change the build number, so this rule works on its own.

## Store releases

Run the release command for each platform:

```sh
make release-android DOPPLER_CONFIG=prd
make release-ios BUILD_NUMBER=<n> DOPPLER_CONFIG=prd
```

The Make targets use the same `--obfuscate` and `--split-debug-info` flags, and the same Doppler dart-defines, as `build-aab` and `build-ipa`. They also pass `--flutter-version` from `.fvmrc` and the public key. Sentry symbols upload after the build. The TestFlight workflow keeps its existing behavior: it sets the build number and export options, but does not obfuscate or split debug info. The Android release workflow builds an AAB with obfuscation and split debug info at `build/symbols`.

The release wrapper refuses a dirty worktree. For the TestFlight workflow, it allows only the known manual-signing settings in `ios/Runner.xcodeproj/project.pbxproj` and Xcode reordering of `PBXBuildFile` or `PBXFileReference` records. Other tracked changes and non-ignored untracked files block the release.

Pass `--dry-run` or `-n` in `BUILD_ARGS` or `IOS_BUILD_ARGS` to skip the Shorebird upload. The wrapper creates no release tag. The Make targets also skip Sentry symbol upload and tag push, even if an old tag marker file exists.

The wrapper records the release in the annotated git tag `shorebird/<platform>/<version>+<build>`. The make target then pushes the tag. CI does the same in the "TestFlight" and "Android Release With Sentry Symbols" workflows. The patch workflow checks the exact tag name and record fields, but it does not verify a tag signature. Protect Shorebird release tags with repository policy; do not treat an unsigned tag record as proof of who created it.

The release wrapper writes a schema 2 release record. The patch tool rejects schema 1 records. The record stores these values:

- The platform, release version, Shorebird CLI version, and release commit.
- The Flutter version.
- The build settings: split-debug-info, target, flavor, and target platform.
- Whether the build is obfuscated.
- A SHA-256 fingerprint of the prepared Firebase options and the matching native Firebase configuration. The configuration contents are not stored in the record.
- The names of the dart-defines, and a SHA-256 hash of their names and values. Define values are not stored, except for the recorded Sentry metadata below.
- The Sentry environment, release, dist, and enabled values. The patch reuses these values.

## Publish a patch

Run the patch command:

```sh
make patch PLATFORM=android RELEASE_VERSION=3.14.0+353
```

`TRACK` defaults to `staging`. The `stable` track is refused. To promote a patch, use the separate step in "Promote to stable".

You can also run the "Shorebird Patch" workflow. Enter the platform, the release version, and the track.

The patch command refuses these inputs:

- A release without a release record tag.
- A Flutter version that differs from the release.
- Build flags that differ from the release.
- Dart-define names or values that differ from the release.
- `--track stable`, or no track.
- `--release-version latest`.
- `--allow-native-diffs` or `--allow-asset-diffs`.
- Any changed or untracked file under a native path since the release commit.
- Storage code, unless you pass `ALLOW_STORAGE_CHANGES=1`.

The patch is signed with `SHOREBIRD_PATCH_PRIVATE_KEY`. The app rejects a patch with no signature or a wrong signature at launch. The app then runs the last good patch or the release.

Sentry symbols upload after the patch. The workflow and Make target read split-debug info, target, and flavor settings from the validated release record. They also pass the recorded Sentry environment, release, dist, and enabled values to the symbol uploader. TestFlight releases do not split debug info; Make iOS releases do. Android release workflows split debug info at `build/symbols`; Make Android releases use `build/app/outputs/symbols`. The iOS patch workflow uses `--no-codesign`.

Pass `PATCH_ARGS=--dry-run` to validate a Make patch without publishing it. The Make target skips Sentry symbol upload for that run.

## Test on the staging track

1. Install a store build from TestFlight or Play internal testing.
2. Sign in with an admin account.
3. Open the debug panel. Turn on "Get staging patches" in the Tools tab.
4. Open the app and close it.
5. Wait for the toast. The toast shows when the patch downloads.
6. Close and reopen the app.
7. Open the App info tab. Check that the patch number is the new patch.

To list the patches and their tracks, run:

```sh
make patch-list RELEASE_VERSION=<v>
```

## Promote to stable

```sh
make patch-promote RELEASE_VERSION=3.14.0+353 PATCH_NUMBER=1
```

This is the only command that sends a patch to all users. Run it only after the staging test passes.

## Roll back

```sh
make patch-rollback RELEASE_VERSION=3.14.0+353 PATCH_NUMBER=1
```

Devices remove the patch at their next check. After the next launch, the app runs the previous patch or the release.

To roll forward, run:

```sh
python3 tool/flutter_with_doppler.py -- shorebird patches rollforward --release-version 3.14.0+353 --patch-number 1
```

To use the console instead, open console.shorebird.dev. Open the release, open the three-dots menu on the patch, and select Rollback.

## Data-migration warning

WARNING: A rollback runs the release code again on data that a patch wrote. If the release code cannot read that data, the rollback can lose or corrupt user data.

If a patch changes a local storage format, a key, a schema version, or a migration, the release code must still read that data. Check these paths before you patch:

- `lib/core/persistence/`
- `lib/core/offline/`
- `*_local_data_source.dart`
- `*_store.dart`
- Any changed line that uses `SettingsLocalDataSource`, `SharedPreferences`, `PersistenceKeys`, `DurableJsonStore`, `LocalStore`, or `settings.get`, `settings.set` or `settings.delete`

The patch command finds these changes and refuses them unless you pass `ALLOW_STORAGE_CHANGES=1`.

Ship storage format changes in a store build. Never write a new schema version from a patch.

## Owner end-to-end test script

Run the Android test first. Then run the iOS test on TestFlight.

### Android

1. Choose the app id. Either put a test app id in `shorebird.yaml` on a scratch branch, or use the real app id with `TRACK=staging`. Never commit a test app id to master.
2. In `pubspec.yaml`, set the version to a test build number. Use `<v>` for this release version.
3. Build the release:

```sh
make release-android BUILD_ARGS="--artifact apk"
```

4. Install the APK:

```sh
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

5. Sign in with an admin account.
6. Turn on "Get staging patches" in the debug panel.
7. Change one Dart label in the debug panel.
8. Publish the patch:

```sh
make patch PLATFORM=android RELEASE_VERSION=<v> TRACK=staging
```

9. Open the app and wait for the toast.
10. Close and reopen the app.
11. Check the new label and the patch number in App info. Check the `ota_patch_running` event in the debug panel logs or in Mixpanel.
12. Roll back the patch:

```sh
make patch-rollback RELEASE_VERSION=<v> PATCH_NUMBER=1
```

13. Open the app, close it, and reopen it.
14. Check that the old label appears.

Wrong key test:

15. Make a second key pair that the release does not know. Keep it out of Doppler:

```sh
openssl genrsa -out wrong-private.pem 2048
openssl rsa -in wrong-private.pem -outform PEM -pubout -out wrong-public.pem
```

16. Publish a test patch signed with the wrong key. This calls Shorebird directly, because the wrapper always signs with the Doppler key:

```sh
shorebird patch android --release-version=<v> --track=staging \
  --public-key-path=wrong-public.pem --private-key-path=wrong-private.pem
```

17. Open the app, close it, and reopen it. Read the log with `adb logcat | grep shorebird`. Look for the signature check failure.
18. Check that the app keeps the old code.
19. Roll back the test patch with `make patch-rollback`. Delete both `wrong-*.pem` files.
20. Delete the test release record tag: `git push origin :refs/tags/shorebird/android/<v>` and `git tag -d shorebird/android/<v>`.

### iOS (TestFlight)

1. Run the TestFlight workflow.
2. Install the build from TestFlight on your own device. Patches do not run on the iOS Simulator. Shorebird needs a release build on a device.
3. Repeat the staging, patch, relaunch, and rollback steps. Use `PLATFORM=ios`, or run the "Shorebird Patch" workflow with the platform set to `ios`.

## Files

- `shorebird.yaml`: Shorebird app id and update setting.
- `tool/shorebird_ota.py`: CLI pin, native and storage path lists, release records, and patch checks.
- `tool/flutter_with_doppler.py`: Runs Shorebird commands with Doppler secrets.
- `.github/workflows/shorebird_patch.yml`: Publishes a patch from CI.
- `lib/core/updates/`: Checks for patches, downloads them, and shows the restart message.
