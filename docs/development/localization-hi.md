# Hindi localisation verification

Hindi uses the canonical English ARB catalogue. Its source was merged as
`#519` (`bdd3e48c3543c81c007ac13d0ee896f9128c048a`) with 2,401 initial keys.
The Spanish foundation PR is not a prerequisite. Spanish documentation at
`eea336def` was not cherry-picked; reuse the existing foundation and bring in
shared fixes when available. This branch reuses shared source fix `785403a67`
as `6a2ae5b7b`, then common commit `0b562d29b` as `83ec4b4c8`. The 92 shared
additions brought both catalogues to 2,498 messages. Subsequent common changes
were integrated as `c4df6a713`, `8eecb594e`, and `756902add`, from
`e6f66cd8d`, `b86755b35`, and `133170f10` respectively. The catalogue now has
2,499 messages and 1,273 exact metadata entries. The added
`economyExportFailedLabel` is translated as “एक्सपोर्ट नहीं हो सका”.

## Rerun checks

Run from the repository root:

```sh
python3 tool/check_l10n.py
python3 tool/check_hi_l10n.py
fvm flutter gen-l10n
fvm flutter test test/l10n/hindi_localization_test.dart
make ci
```

The current ARB contains 2,499 messages and 1,273 metadata entries. Both
`tool/check_l10n.py` and `tool/check_hi_l10n.py` passed on the current tree at
18:10 UTC. The English ARB matches `origin/t3/localisation-es`. The prior
focused localisation suite passed 13 tests before the latest shared updates
(`/tmp/prism-hi-prompt-limit-tests.log`). The full 14-test suite has not run.
Its device-preference test has a confirmed red result: `Expected hi Actual en`
at `test/l10n/hindi_localization_test.dart:40`
(`/tmp/prism-hi-device-locale-red.log`). The focused router/upload analyzer
exited with status 1. It reported four unused `flutter/widgets.dart` imports
and a directives-ordering info in `wallfirestore.dart`
(`/tmp/prism-hi-shared-analyze.log`). These source findings were reported to
the shared owner. Guard checks passed through `system-ui`.
The first worker check using the global Dart SDK hash failed; its retry with the
pinned PATH passed the deep-link and 64 Cloudflare worker tests and the
repository-assets check. The prior 2,498-message `make ci` stopped at the
formatter when a new source commit arrived; this was not a formatter failure or
timeout. Full local CI has not passed and was not restarted on the saturated
host. The Android native build was aborted because its tree was stale and the
host was under swap pressure; this is not evidence of a platform build failure.
Master commit `f51c177d8` merged cleanly. The public PR #598 head is
`cd338f2a8`. Hosted Flutter CI run `39297879204` on that public head failed:
5,009 tests passed, 3 failed, and 191 were skipped. The failures are obsolete
English assertions in `onboarding_v2_save_error_test.dart:610`,
`rewards_widgets_test.dart:108`, and `personalized_feed_screen_test.dart:602`.
They were reported to the common owner. Hosted iOS native checks passed on
that public head. This is not device QA and does not cover the final local head.
Newer local 2,499-message commits have not been pushed pending checks.
The baseline AST scan found zero probable direct literals and 4,870 indirect
candidates; treat the latter as review leads, not confirmed untranslated UI.
The existing native inventory is 58 Android strings, 50 iOS strings, and 3
permissions. Xcode locale-specific string identifiers were added in
`22a48a1aa`.
The tests cover Hindi locale resolution, English fallback, Indian digit grouping,
dates, plural zero/one/many forms, nested selectors, and a real narrow sheet at 2x text.
Review found 231 over-limit suggestions among 4,375 generated AI
prompt combinations, with a maximum of 177 UTF-16 units against the existing
160-unit submission limit. Shorter Hindi copy reduces the maximum to 154 units;
all 35 onboarding suggestions are at most 91 units. An exhaustive production-pool
regression test passed, bringing the then-current localisation suite to 13
passing tests (`/tmp/prism-hi-prompt-limit-tests.log`). The current 14-test
suite and newer source updates have not yet been verified.

## Known verification limits

- `ProximaNova` has no Devanagari cmap. Android is expected to fall back to
  `NotoSansDevanagari`; iOS is expected to use `Kohinoor`. Neither fallback was
  verified on a device.
- T3's device inventory says iOS needs macOS/Xcode and did not detect Android
  SDK. On the actual local host, an Android SDK exists, but no emulator binary,
  AVD, or `/dev/kvm` is available. `verify-prism` doctor also fails because
  `axe` is missing. No simulator/emulator screenshots or live UI QA are
  available; do not claim them.
- RevenueCat remote paywall and store metadata need external credentials and
  configuration. App-owned source copy was translated; no remote metadata was
  changed.
- Common commit `0b562d29b` fixes the onboarding recovery literal and adds the
  prompt-pool catalogue unit. Newly seeded prompts are translated into Hindi;
  restored and user-entered prompts are preserved, and protocol identifiers
  remain unchanged. The common foundation section is preserved, and the
  regenerated locale registry keeps English first and Hindi registered.
- The analyzer confirmed four unused `flutter/widgets.dart` imports and a
  directives-ordering info; see `/tmp/prism-hi-shared-analyze.log`. They were
  reported to the shared owner. The device-preference test confirmed a locale
  resolution assertion failure, with `Expected hi Actual en` at
  `test/l10n/hindi_localization_test.dart:40`. Do not describe this result as an
  unconfirmed test-platform dispatcher mismatch. Shared source fixes have been
  requested; no new source fix is present yet.

See [localisation decisions](localization-hi-decisions.tsv) for the audit trail.
