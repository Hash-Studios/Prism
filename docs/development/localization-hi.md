# Hindi localisation verification

Hindi uses the canonical English ARB catalogue. Its source was merged as
`#519` (`bdd3e48c3543c81c007ac13d0ee896f9128c048a`) with 2,401 initial keys.
The Spanish foundation PR is not a prerequisite. Spanish documentation at
`eea336def` was not cherry-picked; reuse the existing foundation and bring in
shared fixes when available. This branch reuses shared source fix `785403a67`
as `6a2ae5b7b`. Its five new messages bring both catalogues to 2,406 keys.

## Rerun checks

Run from the repository root:

```sh
python3 tool/check_l10n.py
python3 tool/check_hi_l10n.py
fvm flutter gen-l10n
fvm flutter test test/l10n/hindi_localization_test.dart
make ci
```

The contract checks pass for all 2,406 Hindi messages with English metadata,
ICU selectors, and interpolation identifiers preserved. The updated focused
localisation suite passed all 11 tests (`/tmp/prism-hi-2406-tests.log`). Full CI
was intentionally aborted before the source updates and clean merge from master;
it did not pass and must be rerun against the merged tree. An Android native
build was also aborted because its tree was stale and the host was under swap
pressure; this is not evidence of a platform build failure. Master commit
`f51c177d8` merged cleanly. The shared prompt-pool catalogue unit is still
pending from the Spanish work, so Hindi coverage is not final. The baseline AST
scan found zero probable direct literals and 4,870 indirect candidates; treat
the latter as review leads, not confirmed untranslated UI. Key assembly (2,401)
and native localisation inventory (58 Android strings, 50 iOS strings, 3
permissions) were validated. Full baseline analysis passed with existing
informational findings.
The tests cover Hindi locale resolution, English fallback, Indian digit grouping,
dates, plural zero/one/many forms, nested selectors, and a real narrow sheet at 2x text.

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
- The shared fix translates AI generation status and refinement hints, quick
  action titles, category labels, and missing-coin errors. The remaining
  `onboarding_v2_shell.dart:643` recovery literal is reported to the Spanish
  owner for a common follow-up.

See [localisation decisions](localization-hi-decisions.tsv) for the audit trail.
