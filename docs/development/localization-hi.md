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
Use the pinned SDK on PATH for full CI, including Cloudflare worker checks.
An earlier attempt with global Dart failed with an SDK-hash mismatch; the pinned
retry passed. Three stale English assertions from the earlier hosted run are
corrected in reusable test-only commit `6086803bc` and pass in the focused run.
Full local CI did not finish at those checkpoints. Historical stopped runs and
findings remain in the decision trail rather than representing current failures.
The latest local and hosted results are recorded on
[PR #598](https://github.com/Hash-Studios/Prism/pull/598).
The existing native inventory is 58 Android strings, 50 iOS strings, and 3
permissions. Xcode locale-specific string identifiers were added in
`22a48a1aa`.

## Review follow-up

The final copy and focused evidence were pushed as `0adc49e66`. Hosted Flutter
verification passed 5,047 tests with 191 skipped, followed by six release-mode
tests. Hosted Android and iOS native verification and the required `ci`
aggregate also passed on that commit. These results do not prove a later local
commit.

Common onboarding race fix `cb46d8613` is included as `8ce3f4408`. It guards
navigation after an awaited locale load, with a regression for backing out while
the load is pending. The three English assertion fixes in the common commit
already matched the earlier Hindi test-only fix. Required `make file-gen` passed
with 138 outputs and zero formatting changes across 1,437 files. No generated
diff or deletion remains. The onboarding BLoC and localisation suites passed
all 78 tests (`/tmp/prism-hi-onboarding-review-focused.log`).

The `0adc49e66` local CI run passed formatting, catalogue and audit tests,
analytics generation and contract tests, static analysis with nonfatal infos,
all guards, unused-code checks, Cloudflare worker tests, and repository assets.
It was deliberately stopped during full Flutter tests when the newer shared
fix was integrated. It did not finish, so it is not a full local CI pass.

CodeRabbit discussion `r4318102300` identified a second shared issue. Explicit
Shuffle and Scene idea selections can skip draft persistence because the new
text equals the automatic seed. A deferred draft restore can also overwrite
that explicit choice. Root and an independent Luna review confirmed both code
paths. After reporting it to the common-source owner and finding its page and
test paths clean, Hindi took ownership of a source-only reusable fix in this
assigned worktree. The first actual-widget regression run finished with two
passes and four failures before any source edit. It reproduced missing saves
for Shuffle and Scene idea, a scene overwritten by deferred hydration, and
missing persistence for typing during hydration
(`/tmp/prism-hi-ai-prompt-red.log`). No catalogue extraction or metadata change
is needed.

The source fix separates automatic controller writes from explicit user intent.
It keeps a selected prompt during deferred hydration and saves it afterward.
Selection-only changes do not save the automatic seed. Root reviewed the exact
source diff, and an independent Luna review found no source regression. The
first green run passed ten prompt widget tests
(`/tmp/prism-hi-ai-prompt-green.log`). The existing AI page, generation
lifecycle, prompt-pool, and localisation suites then passed all 66 tests
(`/tmp/prism-hi-ai-review-focused.log`). The final regression file also asserts
that the app resolved to Hindi and separately exercises an account switch with
a save debounce pending. Root's final run passed all 11 tests
(`/tmp/prism-hi-ai-prompt-final-reviewed.log`). The reusable source-and-test
unit is `264aeaf66`. It contains no catalogue or language resource changes.

## Runtime checks

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
  complete. The PR records the final full CI result separately.

See [localisation decisions](localization-hi-decisions.tsv) for the audit trail.
