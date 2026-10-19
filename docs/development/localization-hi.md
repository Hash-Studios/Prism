# Hindi localisation verification

Hindi uses the canonical English ARB catalogue. Its source was merged as
`#519` (`bdd3e48c3543c81c007ac13d0ee896f9128c048a`) with 2,401 initial keys.
The Spanish foundation PR is not a prerequisite. Spanish documentation at
`eea336def` was not cherry-picked; reuse the existing foundation and bring in
shared fixes when available. This branch reuses shared source fix `785403a67`
as `6a2ae5b7b`, then common commit `0b562d29b` as `83ec4b4c8`. The 92 shared
additions brought both catalogues to 2,498 messages. Subsequent common changes
were integrated as `c4df6a713`, `8eecb594e`, and `756902add`, from
`e6f66cd8d`, `b86755b35`, and `133170f10` respectively. Master commit
`eeaa36d59` merged as `058994c15` and added three canonical purchase keys. The
catalogue now has 2,502 messages and 1,276 exact metadata entries. The added
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

The current ARB contains 2,502 messages and 1,276 metadata entries. Both
`tool/check_l10n.py` and `tool/check_hi_l10n.py` passed on this tree. The
current `test/l10n` suite and `tool/l10n_audit_test.dart` passed 16 tests
including the three purchase keys (`/tmp/prism-hi-final-2502-focused.log`).
The focused run passed all 138 tests, including onboarding, Rewards, Following,
and purchase callers. An AST audit found zero
probable untranslated direct literals and 4,890 indirect candidates. Treat the
indirect candidates as review leads, not confirmed untranslated UI
(`/tmp/prism-hi-final-ast-audit.log`).

Shared fixes `b4dfe6bb3` as `732ad8342`, `305219fcc` as `2de6f12fb`, and
`4c041480d` as `29f62ef88` are integrated. Purchase-status caller fix
`eb7b20343` is integrated as `4a7affd36`. The device-preference regression
test now passes. Earlier red-test and analyzer results below describe prior
checkpoints, not current failures. `make file-gen` passed with 210 outputs and
the formatter checked 1,437 files (`/tmp/prism-hi-final-file-gen.log`). No
generated deletions or unrelated generated changes remain. Final `gen-l10n`
also passed (`/tmp/prism-hi-final-2502-l10n-gen.log`). The generated Hindi
catalogue includes the latest purchase-key and settings-copy changes.
The first worker check using the global Dart SDK hash failed; its retry with the
pinned PATH passed the deep-link and 64 Cloudflare worker tests and the
repository-assets check. The prior 2,498-message `make ci` stopped at the
formatter when a new source commit arrived; this was not a formatter failure or
timeout. Full local CI has not passed yet. The Android native build was aborted because its tree was stale and the
host was under swap pressure; this is not evidence of a platform build failure.
Master commit `f51c177d8` merged cleanly. The public PR #598 head is
`cd338f2a8`. Hosted Flutter CI run `39297879204` on that public head failed:
5,009 tests passed, 3 failed, and 191 were skipped. The failures are obsolete
English assertions in `onboarding_v2_save_error_test.dart:610`,
`rewards_widgets_test.dart:108`, and `personalized_feed_screen_test.dart:602`.
They were reported to the common owner. Hosted iOS native checks passed on
that public head. This is not device QA and does not cover the final local head.
The public PR #598 head is still `cd338f2a8`; the newer local 2,502-message
head is not published. Three stale English assertions are corrected in reusable
test-only commit `6086803bc` and sent to the source owner. Their focused retest
passed in the 138-test run. Full CI has not passed on the current local head.
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
passing tests (`/tmp/prism-hi-prompt-limit-tests.log`). The current localisation
suite passes all 16 tests, including this exhaustive prompt check.

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
- At an earlier checkpoint, the analyzer confirmed four unused
  `flutter/widgets.dart` imports and a directives-ordering info; see
  `/tmp/prism-hi-shared-analyze.log`. The findings were reported to the shared
  owner. The device-preference test confirmed a locale
  resolution assertion failure, with `Expected hi Actual en` at
  `test/l10n/hindi_localization_test.dart:40`. Shared source fixes have since
  been integrated, and the device-preference test now passes. Generation is
  complete; final full CI is still pending.

See [localisation decisions](localization-hi-decisions.tsv) for the audit trail.
