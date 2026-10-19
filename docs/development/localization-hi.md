# Hindi localisation verification

Hindi uses the canonical English ARB catalogue. Its source was merged as
`#519` (`bdd3e48c3543c81c007ac13d0ee896f9128c048a`) with 2,401 initial keys.
The Spanish foundation PR is not a prerequisite. Spanish documentation at
`eea336def` was not cherry-picked; reuse the existing foundation and bring in
shared fixes when available. This branch reuses shared source fix `785403a67`
as `6a2ae5b7b`, then common commit `0b562d29b` as `83ec4b4c8`. The 92 shared
additions bring both catalogues to 2,498 messages.

## Rerun checks

Run from the repository root:

```sh
python3 tool/check_l10n.py
python3 tool/check_hi_l10n.py
fvm flutter gen-l10n
fvm flutter test test/l10n/hindi_localization_test.dart
make ci
```

Both Python contract checkers pass for all 2,498 messages; the Hindi catalogue
also has 1,272 exact metadata entries. The prior focused localisation suite
passed all 11 tests at 2,406 messages (`/tmp/prism-hi-2406-tests.log`). Final
2,498-message generation passed, followed by all 12 localisation tests with
`fvm flutter test --no-pub --concurrency=1 test/l10n --reporter expanded`
(`/tmp/prism-hi-2498-tests.log`). Guard checks have
passed through `system-ui`. The first worker check using the global Dart SDK
hash failed; its retry with the pinned PATH passed the deep-link and 64 Cloudflare
worker tests and repository-assets check. Full CI was intentionally aborted
before the source updates and clean merge from master; it did not pass and has
not been restarted on the saturated host. The Android native build was aborted
because its tree was stale and the host was under swap pressure; this is not
evidence of a platform build failure. Master commit `f51c177d8` merged cleanly.
The baseline AST scan found zero probable direct literals and 4,870 indirect
candidates; treat the latter as review leads, not confirmed untranslated UI.
The existing native inventory is 58 Android strings, 50 iOS strings, and 3
permissions. Xcode locale-specific string identifiers were added in
`22a48a1aa`.
The tests cover Hindi locale resolution, English fallback, Indian digit grouping,
dates, plural zero/one/many forms, nested selectors, and a real narrow sheet at 2x text.
Final review reproduced 231 over-limit suggestions among 4,375 generated AI
prompt combinations, with a maximum of 177 UTF-16 units against the existing
160-unit submission limit. Shorter Hindi copy reduces the maximum to 154 units;
all 35 onboarding suggestions are at most 91 units. An exhaustive production-pool
regression test passed, bringing the localisation suite to 13 passing tests
(`/tmp/prism-hi-prompt-limit-tests.log`). Subsequent following-label grammar
changes are included in the final CI run rather than covered by that earlier log.

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
  remain unchanged. Final 2,498-message generation and all 12 focused tests passed.

See [localisation decisions](localization-hi-decisions.tsv) for the audit trail.
