# Doppler Secrets Workflow

Prism uses Doppler as the source of truth for runtime secrets.

- Project: `prism`
- Local config: `dev`
- Release config: `prd`

`.env.example` remains a key contract reference only and is not used as runtime input by Make targets.

## Local onboarding

1. Install Doppler CLI: <https://docs.doppler.com/docs/install-cli>
2. From repo root, run:

```sh
make doppler-login
make setup-dev
```

3. Run the app:

```sh
make run
```

## CI/CD

Release workflows use Doppler Service Tokens.

- Required GitHub secret: `DOPPLER_TOKEN_PRODUCTION`

Workflows load secrets from `prism/prd`.

### Shorebird keys

`SHOREBIRD_TOKEN`, `SHOREBIRD_PATCH_PRIVATE_KEY` and `SHOREBIRD_PATCH_PUBLIC_KEY` live in `prd`. The runner reads them
from the same download for `shorebird` commands only. It writes the keys to private temporary files and passes the
token in the environment. They are never dart-defines. See `docs/development/ota.md`.

### Release Firebase prerequisites

Release builds use real native Firebase configuration, then derive the selected
platform's `lib/firebase_options.dart` from it. No separate Dart options secret
is required. All three generated files are gitignored. Never commit or print them.

- Android uses the existing Doppler `FIREBASE_SECRET` value, containing raw
  `google-services.json`. The Android workflow restores it with
  `python3 tool/prepare_release_firebase.py android --from-doppler`.
- iOS requires a **new, owner-supplied** GitHub Actions secret named
  `IOS_GOOGLE_SERVICE_INFO_PLIST`. Its value must be the complete raw XML
  `GoogleService-Info.plist` for Firebase project `prism-wallpapers`, iOS bundle
  `com.hash.prism`. It is not base64 and is not an Android config or a Dart file.
  TestFlight prepares it before importing signing credentials. This secret and
  the real iOS plist were confirmed absent; the workflow remains blocked until
  the owner explicitly approves obtaining and storing that real configuration.

For local builds, put approved native files at
`android/app/google-services.json` or `ios/Runner/GoogleService-Info.plist`.
`make build`, `build-aab`, `build-ios` and `build-ipa` validate the file and regenerate
Dart options before invoking the build. Preparation checks the project, package
or bundle, sender, Firebase app platform, API key and storage bucket. A missing,
malformed, mismatched or checked-in stub config fails. It does not fetch or create
a replacement for a missing local file. Prepare each platform immediately before
building it; Dart options intentionally contain only that platform.

Distributable builds reject `SKIP_FIREBASE_INIT` arguments and unchecked
`--dart-define-from-file` inputs. Offline stubs and skip flags are only for explicit
local debug/CI verification, not a fallback for release prerequisites. Existing
signing, non-uploading release builds and device Firebase/authentication checks
are still separate gates. A fixture test does not prove live Firebase readiness.

### App defines and commands

`tool/flutter_with_doppler.py` parses Doppler JSON and passes an allowlist of the
shipping `Env` keys directly as process arguments. It does not emit shell text or
use `eval`. Backend credentials, unknown keys and development switches never enter
the app's defines. Nonempty `SENTRY_DSN`, `SENTRY_ENV`, `SENTRY_RELEASE`, `SENTRY_DIST`
and `SENTRY_ENABLED` environment variables override their Doppler app settings.
Do not print the configuration or enable shell tracing.

`META_APP_ID` is optional. It is the Meta app ID for Instagram Stories sharing.
When it is empty, the Instagram Stories share target is hidden. The owner adds it
to Doppler `dev` and `prd`.

```sh
DOPPLER_CONFIG=prd python3 tool/flutter_with_doppler.py --release-platform ios -- \
  fvm flutter build ios --config-only --release --build-number=401
```

Use a confirmed build number in place of `401`. Prefer the Make targets for normal
builds. All Make and release-workflow consumers use the same runner. The former
`dart_defines_from_doppler.sh` shell-string interface is removed.

Focused fixture checks, with no network or real credentials:

```sh
make guard-test secrets-guard
make notification-contract-fixture-test
```

The YAML command/schedule fixtures use Ruby's standard-library YAML parser.
The notification fixture needs the existing Flutter dependencies and runs the
actual contract against an isolated backend tree, including an unregistered
synthetic channel that must fail. Functions-only top-level TypeScript changes
schedule this required contract job without scheduling the full Flutter gate.

## Secret update protocol

When adding or changing secrets:

1. Add/update key in Doppler (`prism/dev` and `prism/prd` as needed).
2. Reflect key contract in:
   - `/.env.example`
   - `/lib/env/env.dart` (if app code reads it)
3. Run guards:

```sh
make secrets-guard
make env-guard
```

## Rotation procedure

1. Create a new Doppler Service Token for `prism/prd`.
2. Update `DOPPLER_TOKEN_PRODUCTION` in GitHub Secrets.
3. Trigger a release workflow and verify successful secret fetch.
4. Revoke the old token.

## Troubleshooting

- `doppler: command not found`
  - Install CLI and retry.
- `no DOPPLER_TOKEN and not logged in`
  - Run `make doppler-login`.
- `cannot access prism/dev`
  - Confirm project/config names and team access.
- `missing key in Doppler config`
  - Add missing key to the selected config (`dev` or `prd`).
