# Weekly challenge local QA

This mode boots the real application, providers, router and challenge repositories against a disposable `demo-prism` backend. It requires an explicitly enabled mobile debug build. Profile and release builds fail before startup. Web, `SKIP_FIREBASE_INIT`, an unknown identity, or a missing fixture certificate also fail before startup. No production configuration, credentials, uploads, deploys or dependency installation belongs in this recipe.

All entries are **administratively seeded**. Local readiness checks prove the fixture bytes, protected wall shape and Auth-emulator owner exist. They do not prove R2 delivery or authenticated upload admission. AI and upload screens remain real, but this runtime has no generation, storage or economy callable. Their proof stops at the composer. Product auth and Firestore rules remain unchanged.

## Local preparation

Use installed dependencies only. Functions target Node 24; the helper supports installed Node 24 or newer and records the actual version. A different local major does not prove production runtime parity.

```sh
npm --prefix functions run build
node --test tool/weekly_challenge_qa/*.test.cjs
node tool/weekly_challenge_qa.cjs preflight
node tool/weekly_challenge_qa.cjs prepare
```

Preflight rejects explicit Firebase and Google credentials, occupied ports, missing installed prerequisites, and real native Firebase config. Preparation also refuses an existing runtime directory. Preflight starts no emulator. Preparation does not install dependencies or compile Functions. The default root is `/tmp/prism-weekly-qa`. Commands accept only `--root <directory>` and `--project demo-prism`. Use `--root /tmp/prism-weekly-qa-RUN` for a separate run. Pass the same root to each command for that run. Other projects and options are rejected. Never reuse a peer's runtime or reset its emulator. The project is fixed to `demo-prism`.

Listeners bind to 127.0.0.1. Auth uses 19371, Firestore 19372, Functions 19373, hub 19374 and fixture HTTPS 19375. Logging uses 19376 and Firestore websocket uses 19377. Eventarc/task ports are explicitly reserved as 19378/19379 so CLI defaults cannot collide with peers. Function discovery/workers can use ephemeral loopback ports. Abort if Firebase selects a fallback service port.

Preparation copies compiled modules, rules, indexes and the existing local wallpaper JPEG. It generates a seven-day localhost TLS certificate, synthetic native configs and `dart-defines.json`. It does not write native repo config. Read `manifest.json` for fixture/source digests and runtime identity.

Run these in separate foreground terminals:

```sh
node tool/weekly_challenge_qa.cjs serve
node tool/weekly_challenge_qa.cjs emulators
```

The emulator command uses an empty runtime-specific CLI config directory, disables metadata detection/telemetry, and preloads a loopback-only TCP policy into Node CLI/discovery children. Backend modules enforce the exact declared port allowlist before loading Admin or product modules. Admin uses the generated disposable key and synthetic demo service-account name, never ADC or a real account. Native/Java processes are separate from the Node policy. This is not a measured zero-egress device sandbox.

The generated wrapper exports the real list/get/vote callables in both existing regions. It also exports one narrowly scoped auth-context probe for `walls/qa-upload-probe`. That probe passes the original event principal to real `admitChallengeWall` and records before/after data. It exports no upload processing, push, global schedule, economy or storage functions. The wrapper reuses installed modules through a symlink without dependency installation. Firebase CLI 15.34.1 can warn that the wrapper has no declared firebase-admin dependency; inspect successful function initialization and actual callable assertions, not its ready banner alone.

## Backend proof

Run sequentially after both services are ready:

```sh
node tool/weekly_challenge_qa.cjs seed
node tool/weekly_challenge_qa.cjs assert
node tool/weekly_challenge_qa.cjs probe-admission
node tool/weekly_challenge_qa.cjs publish-wotd
node tool/weekly_challenge_qa.cjs close
node tool/weekly_challenge_qa.cjs publish-wotd
node tool/weekly_challenge_qa.cjs assert
```

Seed refuses existing challenge data. It creates deterministic email/password emulator users `qa-viewer`, `qa-creator-a`, `qa-creator-b`, their profiles and private `postAlerts=false` sessions, zero coins and no push tokens. Their emails are `<uid>@example.test`; their public disposable password is `local-demo-only-password`. No OAuth or real credentials are used.

Seed creates approved wall fixtures and private admission records, then invokes real reconciliation. It uses real voting transactions for initial votes and invokes real scheduler/finalizer functions for historical and empty fixtures. The actual winner notification writer creates the inbox document with push disabled. `challengeIo.ready` and `premium` are the only replaced backend integration seams. Owner lookup stays real against the Auth emulator.

Assert checks exact wall/createTime admission identities, approved gate provenance, vote counts against vote documents, all fixture readiness/owners, winner/inbox/push-disabled state and WOTD consumption. It authenticates through Auth emulator and calls the real HTTP callables to list/get, vote/unvote, reload both results, reject self-votes and reject closed-challenge votes. Tokens are never written into evidence. Avoid concurrent assertions or UI votes because the actual rate ledger remains active.

`probe-admission` performs a real authenticated Firestore client create under the current rules, waits at most 30 seconds for the actual auth-context event, and saves `admission-probe.json`. The known emulator emits `fake-auth-id@gmail.com`, not the signed-in fixture UID. Rejection, removal of challengeId and absence of an entry are expected evidence of this blocker. Never seed that fake identity, remap it, or inject a successful principal. This is not an image-byte upload or full submission test.

Publish invokes real `reservedChallengePick` and `commitWotdPick` for the recorded reservation date. That date can be in the future; the device clock is unchanged. Close administratively changes only the fixture deadline, invokes the actual scheduler, and checks repeated finalization is a no-op. Repeated publication checks the persisted pointer/date. No global WOTD announcer or production schedule runs.

Evidence is written to `evidence.json`, `evidence-open.json`, `evidence-archived.json` or another actual challenge state filename, plus `admission-probe.json`. Keep logs, `manifest.json`, `state.json` and all evidence. Stop only the foreground processes this run started when finished.

## Android build and device proof

```sh
node tool/weekly_challenge_qa.cjs build-apk
```

This command validates the runtime path, explicit QA activation, identity, three allowed defines, pinned certificate, and synthetic native project and key. It then temporarily supplies the synthetic Android config and QA debug manifest. The command builds an x64 debug APK with two Gradle workers. It refuses a real native config.

Cleanup attempts every recorded restoration after success or an ordinary exception. If an input still matches the temporary replacement, cleanup restores its original bytes or removes a newly created file. Cleanup preserves concurrent edits and reports each conflict or file error. A missing file can also cause a cleanup error. Inspect every reported path before another build. SIGKILL, process loss, or machine loss can prevent cleanup. Restoration is not guaranteed after those interruptions. The QA overlay disables native Analytics/FCM auto-init and removes Mobile Ads initialization. Ordinary debug and release manifests remain unchanged outside this build operation. Do not run a competing build in this checkout during the temporary input window.

The artifact is `build/app/outputs/flutter-apk/app-debug.apk`. The generated defines select viewer; edit only the generated local identity define to `creator` or `guest` for a separate build. Do not use the verification helper's `--build`, which substitutes a skip-Firebase build.

Before any device operation, read `verify-prism`, run its read-only doctor and acquire its lock. The only Android device allowed here is `emulator-5580`, AVD `Prism_QA_API36`. A peer's live or unconfirmed lock blocks device work. Do not clear/take over it or act on another emulator. If available, use only that skill's tap/describe/snapshot harness and `tool/record_clip.sh`.

After owning the device, reverse ports 19371, 19372, 19373 and 19375 explicitly with `adb -s emulator-5580 reverse`. SDK automatic Android host mapping is disabled. Install the prepared APK with the existing verification helper. Read actual IDs from `state.json`; the deep links are `prism://challenges/<active>` and `<history>`.

Drive Home/card/challenge, top/new, vote/unvote/reload, self-vote rejection, history/winner/inbox, warm/cold links and light/dark through real Settings. Capture action/result screenshots, trees and metadata. Upload and AI are composer-only. Share-sheet visual inspection is allowed; send nothing externally. Remove only this run's reverses and call helper cleanup only if this run acquired the lock. Never publish screenshots from this helper.

## iOS and remaining gates

Linux cannot build/run the named iOS simulator. On an authorized Mac, use the prepared synthetic plist/config and explicitly select `native/Info-LocalQA.plist` when building Debug with Xcode. Ordinary Info.plist is not sufficient because native SDK initialization precedes Dart. The generated plist integration is unverified. Follow the same exclusive lock and named-device rules.

No full upload admission, AI Generate/result, coins, R2 readiness, native purchases/push, large pagination or production scheduler proof is provided. Historical Android screenshots, trees, clips, and APK identities are in `/tmp/prism-weekly-qa`. They predate local head `bf1740e2b` and its warm navigation, plurals, and QA guard fixes. Use `android-evidence/evidence-index.json` to exclude transitional captures. Fresh Android proof is forthcoming. iOS proof is unavailable here. The dark upload composer remains unverified after a picker ANR. Hosted CI, merge, deploy, publication and live behavior remain separate gates.
