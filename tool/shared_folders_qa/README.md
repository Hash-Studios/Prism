# Shared folders local QA

This harness runs the real app against a disposable `demo-prism` emulator backend. It seeds one private folder, three users and eight walls. It then runs the real invite, join and refusal callables, the real `onFolderItemWritten` trigger and the real `sendDueFolderActivity` push job. It never touches production. All fixture data is written by Admin code and is marked `ADMIN SEEDED`.

It proves backend behavior and the app wiring. It does not prove store builds, production data, real push delivery or a real-device sign-in.

## Order of commands

Run from the repo root. Use the same `--root` in each command of one run. The default root is `/tmp/prism-shared-folders-qa`.

Run A: backend proof.

```sh
npm --prefix functions run build
node tool/shared_folders_qa.cjs preflight
node tool/shared_folders_qa.cjs prepare
node tool/shared_folders_qa.cjs serve        # terminal 1
node tool/shared_folders_qa.cjs emulators    # terminal 2
node tool/shared_folders_qa.cjs seed
node tool/shared_folders_qa.cjs assert       # Riya joins, Bo is refused twice, writes evidence.json
node tool/shared_folders_qa.cjs push         # Riya adds wall 3, then the activity push runs
```

Run B: device proof. Stop `emulators` with Ctrl-C in terminal 2, then start it again. This gives fresh state. Then seed again. Do not run `assert` in this run. `assert` joins Riya on the backend, so a device join would show "member".

```sh
node tool/shared_folders_qa.cjs emulators    # terminal 2, fresh state
node tool/shared_folders_qa.cjs seed
node tool/shared_folders_qa.cjs invite       # prints the link for Riya
bash tool/write_firebase_options_stub.sh                     # the build needs lib/firebase_options.dart; never use the production file
node tool/shared_folders_qa.cjs build-ios --user creator    # Ana, on an authorized Mac with Xcode
node tool/shared_folders_qa.cjs build-apk --user viewer     # Riya, Android emulator
adb -s emulator-5580 reverse tcp:19371 tcp:19371
adb -s emulator-5580 reverse tcp:19372 tcp:19372
adb -s emulator-5580 reverse tcp:19373 tcp:19373
adb -s emulator-5580 reverse tcp:19374 tcp:19374
adb -s emulator-5580 reverse tcp:19375 tcp:19375
# install and open the APK, then the device steps below
node tool/shared_folders_qa.cjs push         # after Riya joins on the device
```

`preflight` starts nothing. It fails on a busy port, a missing build output, or a real native Firebase config. `prepare` refuses an existing root. `seed` refuses a project that already has the `qa-trip` folder, so restart `emulators` first. `assert` refuses to run when Riya is already a member.

`assert` writes `evidence.json`. It exits nonzero if any check fails, and the failed checks are listed in that file. It prints the two invite codes. Tokens are never written to disk.

`serve` is the fixture image server on port 19375. The app loads wall thumbnails from it. Use the same port for the `adb reverse` line.

## Seeded cast

- `qa-creator-a` (Ana QA) owns the private folder `folders/qa-trip`, named "Trip". Trip holds walls 1 and 2.
- `qa-viewer` (Riya QA) is the editor to be. Her favourites hold walls 1 to 6. Walls 7 and 8 are only in the feed.
- Two refused codes for Trip: `UsedXyzABC` (Bo already used it) and `ExpiredXYZ` (its 7 days ended). Riya opens either one on a device to prove a refused join.
- `qa-blocked` (Bo QA) has blocked Ana. Bo cannot join Ana's folders.
- `qa-shared-1` to `qa-shared-8` are approved Prism walls, uploaded by Ana. Their thumbs point at the local image server.
- Ana and Riya have a `private/session` with `folderAlerts` true, a `folderAlertsToken` and a matching `fcmToken`. The binding fields match `fcm_token_service.dart`. No real FCM runs in the emulator, so the inbox doc is the evidence.

## What each step proves

| Step | What it proves |
|---|---|
| `seed` | Users, walls, Riya's favourites and the Trip folder exist as the app stores them. |
| `assert` 1 | Ana creates invite 1 with `createFolderInvite`. |
| `assert` 2 | Riya previews invite 1 with `getFolderInvite` and sees `join`, the name Trip and two items. |
| `assert` 3 | Riya joins with `joinFolder`. The folder gets Riya as the only editor, added by Ana. |
| `assert` 4 | Ana creates invite 2. It is a fresh code for the refused join. |
| `assert` 5 | Bo is refused on invite 2 with `blocked`. Invite 2 stays unused and the folder does not change. |
| `assert` 6 | Bo is refused on invite 1 with `used`. |
| `push` | Riya's add of wall 3 queues an activity through the real `onFolderItemWritten` trigger. `sendDueFolderActivity(now + 2 h)` runs. Ana's inbox gets "Riya QA added a wall to Trip". |

`push` writes the editor add itself, with Admin SDK, marked as a Riya add. If wall 3 is already in Trip, `push` skips the add and sends whatever is due. The reported send count can be 0 in the emulator. FCM is not reachable there, so the inbox doc is the evidence.

## Device steps

Use a fresh run B. Riya's device must not be a member before the join.

Ana, iOS Simulator (`build-ios --user creator`):

1. Install and open the app built at `build/ios/iphonesimulator/Runner.app`. Ana is signed in.
2. Open Library, then Folders. The Trip card shows two walls.
3. Open Trip, then People. Ana is listed as **Owner**.
4. After Riya joins, People lists Riya as **Can add and remove**.

Riya, Android emulator (`build-apk --user viewer`):

1. Install `build/app/outputs/flutter-apk/app-debug.apk` on emulator-5580.
2. Open the join link. The custom scheme is the form that works on a debug build:

   ```sh
   adb -s emulator-5580 shell am start -a android.intent.action.VIEW -c android.intent.category.BROWSABLE -d 'prism://folder/invite/<code>' -p com.hash.prism
   ```

3. The join page shows Trip, the covers, "Ana QA invited you" and **Join folder**. Tap **Join folder**.
4. Library, then Folders shows Trip under **Shared with you**.
5. Add wall 3 to Trip from Favourites or the feed. Riya's favourites hold walls 1 to 6.
6. Run `push`. The inbox doc for Ana is the evidence.

Deep link forms:

- Use `prism://folder/invite/<code>`. The `prism` scheme is in `CFBundleURLSchemes` on iOS and in the `prism` intent filter on Android. Neither needs the app-link file on prismwalls.com.
- The `https://prismwalls.com/folder/qa-trip?invite=<code>` form needs app-link verification. A debug build cannot pass it on Android, and iOS needs the hosted apple-app-site-association file. Do not use it for this QA.
- On iOS, open the custom scheme with `xcrun simctl openurl booted 'prism://folder/invite/<code>'`.
- No in-app URL input route was found. `/choose-wallpaper` takes an image, so it is not a link input.

## Not covered

- A refused join on a device. The app has no sign-in for `qa-blocked`. `build-apk` and `build-ios` accept only `viewer` and `creator`. Invite 2 is for the backend proof, and it is the code a blocked device would open once that identity exists.
- The `used` refusal on a device. Riya is already a member after her join, so the app shows "member", not "used".
- Real push delivery. FCM is blocked in the emulator.
- Wall full-size images. Wall docs keep `wallpaper_url`, `wallpaper_path`, `wallpaper_sha` and the thumb fields empty, as in creator directory QA. The app hides a wall whose original URL is set.

## Safety

- Project `demo-prism` only. Emulator hosts are `127.0.0.1` only.
- Refuses real or mixed native Firebase config. Android must match the generated synthetic fields. iOS must match the generated synthetic plist exactly, including whitespace. Use a fresh `prepare` runtime to regenerate these inputs.
- The 7-day certificate is disposable. The app pins it only for `localhost:19375`.
- The runtime root must be a real directory directly under `/tmp`, named `prism-shared-folders-qa*`. Runtime JSON paths and native build destinations refuse symlinks.
- `build-apk` and `build-ios` swap in synthetic native inputs and restore the originals afterwards.
- The Android debug manifest and the CLI network guard come from `tool/weekly_challenge_qa/`. The `backend.cjs` helper provides the project guard.
