# Creator directory local QA

This harness runs the real app against a disposable `demo-prism` emulator backend. It seeds creators, walls, follows and one block, then runs the real `rebuildCreatorDirectory` job and the real `getFollowedBy` callable. It never touches production. All fixture data is written by Admin code and is marked `ADMIN SEEDED`.

It proves backend behavior and the app wiring. It does not prove store builds, production data or real-device sign-in.

## Order of commands

Run from the repo root. Use the same `--root` for each command in one run. The default root is `/tmp/prism-creators-qa`.

```sh
npm --prefix functions run build
node tool/creator_directory_qa.cjs preflight
node tool/creator_directory_qa.cjs prepare
node tool/creator_directory_qa.cjs serve        # terminal 1
node tool/creator_directory_qa.cjs emulators    # terminal 2
node tool/creator_directory_qa.cjs seed
node tool/creator_directory_qa.cjs assert
node tool/creator_directory_qa.cjs build-apk    # or build-ios on an authorized Mac
adb -s emulator-5580 reverse tcp:19371 tcp:19371
adb -s emulator-5580 reverse tcp:19372 tcp:19372
adb -s emulator-5580 reverse tcp:19373 tcp:19373
adb -s emulator-5580 reverse tcp:19374 tcp:19374
adb -s emulator-5580 reverse tcp:19375 tcp:19375
# install and run the APK on the device, then check the screens below
node tool/creator_directory_qa.cjs opt-out      # after device proof
```

`preflight` starts nothing. It fails on a busy port, a missing build output, or a real native Firebase config. `prepare` refuses an existing root. `seed` refuses a root that already has creator directory docs. `opt-out` changes one user and rebuilds the directory again.

`assert` writes `evidence.json`. It exits nonzero if any check fails, and the failed checks are listed in that file. It signs in `qa-viewer` through the Auth emulator and calls the callable over HTTP. Tokens are never written to disk.

## Seeded cast

- `qa-viewer` (Riya QA) follows `qa-friend-1` to `qa-friend-4` and `qa-maker-1`. It blocks `qa-maker-8`.
- `qa-friend-1` to `qa-friend-4` (Maya Chen, Arjun Mehta, Lena Fischer, Tom Okafor) have no walls.
- `qa-maker-1` to `qa-maker-9` (Aria Bloom to Ivy Moreau) each have five walls. Makers 1 to 3 use Nature and Space. Makers 4 to 6 use Abstract and Neon. Makers 7 to 9 use Space and Minimal. Maker 9 is new: its first wall is 3 days old.
- Daily wall stats exist for makers 2, 4 and 7, so their ranks differ.

## What each seed proves

- Home row hides `qa-maker-1`, because the viewer already follows it.
- `qa-maker-8` is in the directory, but the app hides it, because the viewer blocks it.
- `qa-maker-2` shows "Followed by Maya Chen, Arjun Mehta and 2 others you follow". The callable returns count 4 and 3 people. The app uses the first two names and `count - 2`.
- `qa-maker-3` shows two names: "Followed by Maya Chen and Arjun Mehta".
- The see-all filter for Nature, Abstract and Space lists the matching makers.
- Following `qa-maker-2` offers "More like Kai Nakamura". The similar list comes from shared followers (friends 1 to 3 follow both maker-2 and maker-5) and shared categories (makers 1 to 3 share Nature).
- `qa-maker-6` opts out with `opt-out`. Its directory doc is removed, and the directory drops to 8 creators.

## Known gap

`assert` checks that `qa-maker-9` ranks above an older creator with no activity. Every seeded maker's first wall is under 30 days old, so the seed has no such creator. That check fails on purpose until the seed gets an older zero-activity creator.
