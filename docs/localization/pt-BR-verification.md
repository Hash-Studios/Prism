# Brazilian Portuguese verification

## Dependencies

This locale reuses the canonical Flutter localisation foundation merged in
[#519](https://github.com/Hash-Studios/Prism/pull/519), commit
`bdd3e48c3543c81c007ac13d0ee896f9128c048a`.

The shared indirect-string fixes from the Spanish thread are included from
`785403a67e469065de4d80ec56a2ae6baf0697aa`, cherry-picked as `92fec989a`.
They localise AI progress, coin errors, category chips, the download ledger,
onboarding style labels, and launcher shortcuts. This PR does not depend on
the Spanish translation file or introduce another localisation system.

Further shared fixes are reused from `0b562d29b`, `b86755b35`, and
`133170f10`. They localise prompt suggestions, sign-in feature labels,
upload number formatting, and collection-preview spend failures. The
canonical catalogue now contains 2,502 messages.

The device-locale fixes are reused from `e6f66cd8d`, `b4dfe6bb3`,
`305219fcc`, `4c041480d`, and `eb7b20343`. They resolve background
messages against the framework's complete preferred-language list.
The latest master purchase-confirmation states are also translated.

`app_pt_BR.arb` uses the canonical message keys and inherits placeholder
metadata from the English template. Flutter generates locale registration.
Flutter requires a base `pt` catalogue for the regional `pt_BR` catalogue.
Both contain the same Brazilian copy. A parity test prevents drift.
The existing `preferred-supported-locales: [en]` setting keeps English first
for unsupported locales. Device locale selection uses the existing app
delegates and context-free localisation loader.

Brand names, creator content, protocol values, paths, and identifiers remain
unchanged. Existing persisted `Prism User` names are user data, not a label
to rewrite. Portuguese also uses terms such as `Downloads` and `Anime`.

All 2,502 canonical keys have nonempty translations. Generation validates
ICU syntax and inherited placeholder types. Portuguese zero-count branches
use explicit `=0` selectors because `intl` otherwise classifies zero as
singular in pt-BR. Existing selectors and English messages are unchanged.

## Native coverage

The Android pt-BR resources contain all 58 default string keys. Positional
format placeholders match the English resources. The iOS catalogue contains
pt-BR translations for all 50 source entries, with matching placeholders.
The three iOS permission descriptions have pt-BR translations registered in
the Xcode project. English native fallback values remain unchanged.

All nine bundled text fonts contain the 26 Portuguese accented letters
checked with `fc-query`. The JamIcons icon font is not a text font.

## Device limits

This host runs Linux and has no Xcode, iOS Simulator, or `axe` executable.
The Android SDK is present, but it has no emulator executable, system image,
or AVD. `adb devices -l` lists no device, and `/dev/kvm` is absent.

Both `verify-prism doctor` platform checks fail on those missing tools.
No device screenshots or runtime verification are claimed. Widget layout
tests and APK builds are separate checks, not substitutes for device proof.

## Verification commands

`python3 tool/check_l10n.py` checks all 2,502 messages in each of the three
catalogues. `fvm flutter gen-l10n` passed with no missing pt-BR keys.
`make file-gen` passed and left no unrelated generated-source changes.
The hard-coded-string audit passed with zero probable UI literals.
Indirect literals were reviewed separately, including native error callers.

Focused locale and native tests live in `test/l10n/pt_br_localization_test.dart`
and `test/l10n/pt_br_native_resources_test.dart`. The three native resource
tests passed. Locale behaviour tests cover region selection, English fallback,
interpolation, number/date formatting, zero/one/many coin plurals, and real
onboarding/button/sheet layouts at 320 pixels with enlarged text.

The full local commands are `make ci ANALYZE_FLAGS=--no-fatal-infos
TEST_FLAGS=--concurrency=2` and `make native-android-check` with this host's
Java 21 installation. Their final results and hosted CI belong to the PR
verification record. Neither command provides the missing device proof.
