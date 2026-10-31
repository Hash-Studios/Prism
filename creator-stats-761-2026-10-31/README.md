# Creator stats device proof (PR #761)

Captured 2026-10-31 on a Mac with the real app, real Auth, Firestore and Functions emulators (`demo-prism`), and the real `getCreatorStats` callable. Seed data is synthetic. Navigation used real taps; the other creator's profile was opened with a `prism://user/qa-stats-other` link.

- Android: local AVD `Prism_QA_API36` (Android 16), debug APK with `CREATOR_STATS_EMULATOR_HOST=127.0.0.1` and `adb reverse` for ports 9099, 8080, 5001 and 9198.
- iOS: local simulator `Prism QA iPhone 17 Pro` (iOS 27.0), debug simulator build, demo-only `GoogleService-Info.plist`.
- Creator builds include fix `0ab0d548e`. Empty-state builds include fix `387b17adc`. `12a` (Android) shows the empty state before that fix.

Each `.png` has a matching `.tree.json` view tree from `agent-device snapshot --json`. `clip-profile-stats-wall.mp4` records profile, Stats, metric switch to Saves, and the top wall's own numbers. `clip-contact-sheet.png` summarizes each clip.
