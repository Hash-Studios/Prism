# Creator stats local QA

Run only against `demo-prism`. These tools use the real app, Firebase Auth emulator, Firestore emulator and real `getCreatorStats` callable. No cache documents or callable responses are seeded. Inbox creation calls the real backend `deliverCreatorWeek` transaction locally. No production data, Doppler, service account, dependency installation or deployment is needed.

## Static validation now

```sh
node tool/creator_stats_qa/validate.cjs
bash -n tool/creator_stats_qa/start.sh
```

Validation transpiles only six local modules using the existing Functions TypeScript dependency, checks script syntax, the exact export/module allowlist, daily API wiring, normalized IDs, ISO week boundaries and production-project rejection. It starts no services. It does not replace emulator assertions or device proof.

## Later: start, seed, assert

From the repository root, after the parent releases its QA lock and authorizes emulator/device work:

```sh
# Terminal 1, foreground. Ctrl-C stops the Firebase emulators.
bash tool/creator_stats_qa/start.sh demo-prism
# Terminal 2, foreground. Ctrl-C stops the local PNG server.
node tool/creator_stats_qa/images.cjs demo-prism
# Terminal 3, only after Auth 9099, Firestore 8080 and Functions 5001 are ready:
node tool/creator_stats_qa/seed.cjs demo-prism
node tool/creator_stats_qa/assert.cjs demo-prism
```

Do not reuse ports occupied by someone else's emulators. The launcher never stops existing services or imports/exports their data. It runs Firebase with isolated CLI configuration directories, a disabled ADC file path and an allowlisted environment, so inherited credentials, secrets, CLI login and ambient ADC files are unavailable. All Admin instances use a newly generated, disposable demo certificate and explicit emulator hosts. This certificate is generated in memory, never loaded from disk, and has no real service-account authority.

`prepare.cjs` transpiles current backend source to ignored `.runtime/`. It includes `creatorStats`, `creatorStatsHistory`, `creatorStatsDaily`, `common`, `notificationCatalog`, and the exact `normalizeId` function plus `MAX_ID_LEN` parsed from `viewStats.ts`. It avoids the latter's economy/asset imports. Only `getCreatorStats`, `onCreatorStatsDailyWritten` (the real enqueue trigger from the daily module), and `onCreatorStatsFolderCreated` are exported to Firebase. The direct `processCreatorStatsDailyQueue()` API is loaded only by `local.cjs` and called from assertions; it is not exposed as an HTTP function. The weekly scheduler, notifications, authored-content, upload, payment, remix and push triggers are excluded. Remix history is a deterministic fixture; this sandbox does not claim to exercise remix acceptance. There are no secret bindings. Existing `functions/node_modules` is reused by symlink. Restart after backend edits to regenerate the local bundle. No root Functions build is needed.

The seed uses fixed Auth UIDs, verified email/password users and complete Prism profile/wall shapes. Logical wall IDs are `QA-CREATOR` and `QA-OTHER`; canonical paths are `walls/qa-creator` and `walls/qa-other`. History keys use each wall snapshot's actual Firestore creation time. Eight deterministic ISO UTC weeks, seven metrics, lifetime counters and a distinct empty account are included. The seed preserves existing history increments, lifetime documents and wall creation incarnations on replay. New weeks get fixture values; old weeks are pruned. Never interpret this synthetic historical coverage as real activity. An older scaffold with conflicting random Auth UIDs fails safely; use a fresh dedicated demo emulator session rather than deleting unknown data.

The creator's inbox item is created by backend delivery during seed. The second creator is left for the assertion's first-delivery concurrency race. Assertions authenticate through the Auth emulator and call HTTP `getCreatorStats` with the returned ID token. They check each account's exact wall IDs, totals, eight UTC windows, metric values, empty-account zeros, unauthenticated rejection and UID-override rejection.

The same assertion script performs real Firestore concurrency checks, ready to execute later:

- A real daily trigger creates only a durable queue item. The test then calls the real processor directly and checks that history and checkpoint commit exactly once. It races duplicate enqueues and processors, deletes a source before processing, recreates the same path with a new incarnation, and checks approval and normalized-alias changes while work is queued. Eight private collections are checked through authenticated and unauthenticated REST reads and authenticated writes.
- Four simultaneous folder projections race the automatic trigger, then replay the same creation snapshot. History must increase by exactly one, once.
- Four simultaneous inbox retries preserve the creator's existing notification byte-for-byte. Four simultaneous deliveries for the second creator must yield exactly one winner on the first run and zero on repeats.

Assertions intentionally add daily projection events and one new folder event for the second creator on each run. They preserve previous test events and markers. Run only one seed/assert process at a time. Do not run across a UTC week boundary; rerun seed afterward if the boundary passes. The backend callable creates its own normal cache; tools never write or delete it. Projection assertions inspect committed private history, so cache TTL cannot hide duplicate increments.

## Later: Android demo build

```sh
# Refuses to overwrite any differing root google-services.json.
node tool/creator_stats_qa/native.cjs demo-prism
# The debug network security config permits cleartext only to localhost and 127.0.0.1.
for port in 9099 8080 5001 9198; do adb -s <serial> reverse tcp:$port tcp:$port; done
fvm flutter build apk --debug \
  --dart-define=CREATOR_STATS_EMULATOR=true \
  --dart-define=CREATOR_STATS_EMULATOR_HOST=127.0.0.1 \
  --dart-define=CREATOR_STATS_EMULATOR_PROJECT=demo-prism \
  --dart-define=CREATOR_STATS_EMULATOR_ACCOUNT=creator
```

Never commit `android/app/google-services.json` or `ios/Runner/GoogleService-Info.plist`. The native preparation command checks both ignored files before writing either. It creates missing files and accepts only exact existing demo configs. A real config is a blocker: use a dedicated QA checkout without it. The command also refuses any build-variant `google-services.json` under `android/app/src`. Native Firebase initializes only the demo project before Dart startup; the Dart bootstrap connects emulator services before normal app navigation. Do not add `SKIP_FIREBASE_INIT=true`. Do not use this native config for release/profile builds. No native file is modified by `validate.cjs` or the launcher.

Use `creator`, `other`, or `empty` for the account define and rebuild when switching. PNG wallpaper and avatar fixtures are generated locally by `images.cjs`, with no external image service or new dependency. Seed with `QA_IMAGE_HOST=127.0.0.1`; Android reaches them through the `adb reverse` port forward. Host `10.0.2.2` fails on Android because cleartext to it is not permitted. For iOS proof on a Mac, seed with `QA_IMAGE_HOST=127.0.0.1 node tool/creator_stats_qa/seed.cjs demo-prism` and use matching emulator Dart defines with host `127.0.0.1`. `native.cjs` also writes the ignored demo `ios/Runner/GoogleService-Info.plist` under the same rules. Its values must equal `CreatorStatsEmulator.options`; otherwise Firebase reports a duplicate default app and startup stops. Do not copy production native config. Linux cannot provide iOS Simulator proof.

## Later: real UI navigation

Follow `.agents/skills/verify-prism/SKILL.md`, its feature index and profile/notifications/deep-link recipes. This authorized demo email/password bootstrap replaces the skill's real-account sign-in requirement only for these isolated fixtures. Use only `Prism_QA_API36` and, on a Mac, `Prism QA iPhone 17 Pro`. Open them with the T3 device tools and drive them with the returned `agent-device` command. Leave peer devices and locks alone.

Install the APK built with the defines above, clear the app's data, then open it. Do not rebuild through a launcher that discards the defines. Another creator's profile needs the seeded `profiles` document; open it with `prism://user/qa-stats-other`. Drive normal profile/settings entries to Creator Stats and tap the real inbox item to enter it. Capture dashboard, metric/week changes, wall detail, both entries, inbox, owner isolation, empty account, dark/light themes and large text. Capture before and after states and the view trees. Restore text size and appearance afterwards, and remove the `adb reverse` forwards. Publish screenshots only when authorized.

The bootstrap keeps normal Firebase readiness false to suppress Remote Config, economy config and FCM, and uses real repositories through an emulator-connected Firestore client. This is not a separate fake stats screen. Unrelated home feed URLs/connectivity probes can still access external HTTP endpoints. Stay within the seeded profile, stats, wall and inbox paths. No device/emulator run, build, production access, commit, push or deploy is part of the tooling validation.

## Capacity proof

After seed and assertions, run `node tool/creator_stats_qa/capacity.cjs demo-prism` once in a dedicated fresh emulator session. It creates 500 caller walls, measures callable transaction reads and retries, tests a foreign normalized alias and warm withdrawal, fills the global identity census to 20,000 walls, and verifies callable rejection at 20,001. It then measures one full daily batch at 20,000 rows (20,307 total reads and 302 writes, including lease and empty-terminal work), and verifies 100 queued items remain byte-for-byte unchanged with no checkpoints at 20,001. It checks the 15-minute cooldown, removes the overflow row, advances `notBefore` with a local Admin write, and recovers all 100 items. This proves recovery after capacity returns, not a 15-minute wall-clock wait. The script intentionally leaves the demo database over capacity. Stop and restart the dedicated emulators before app screenshots or another capacity run. No production connection or cleanup is part of this tool.

`assert.cjs` also checks authenticated and unauthenticated reads and authenticated writes against all eight private creator-stats collections through REST, including the daily queue and processor state. These requests execute client rules; Admin SDK queries cannot prove that boundary.
