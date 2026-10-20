# Brazilian Portuguese verification

## Dependencies

The Portuguese branch work began from the canonical Flutter localisation
foundation merged in [#519](https://github.com/Hash-Studios/Prism/pull/519),
commit `bdd3e48c3543c81c007ac13d0ee896f9128c048a`. Its historical commits
below record how the locale work reused shared changes while those changes
were still being developed on other locale branches.

The shared indirect-string fixes were originally reused from
`785403a67e469065de4d80ec56a2ae6baf0697aa`, cherry-picked as `92fec989a`.
They localise AI progress, coin errors, category chips, the download ledger,
onboarding style labels, and launcher shortcuts. This PR does not depend on
the Spanish translation file or introduce another localisation system.

Further shared fixes are reused from `0b562d29b`, `b86755b35`, and
`133170f10`. They localise prompt suggestions, sign-in feature labels,
upload number formatting, and collection-preview spend failures. The
canonical catalogue now contains 2,502 messages.

The shared prompt-persistence fix is reused from Spanish commits
`8d0498874`, `1085c5ab5`, and `fef381070`, cherry-picked here as
`39bd66f9e`, `1ba749c4a`, and `48b40cdba`. It preserves explicit generated-
prompt choices through hydration, persistence, and locale changes. The
catalogue remains unchanged, and this does not depend on the Spanish
translation PR.

The device-locale fixes are reused from `e6f66cd8d`, `b4dfe6bb3`,
`305219fcc`, `4c041480d`, and `eb7b20343`. They resolve background
messages against the framework's complete preferred-language list.
The latest master purchase-confirmation states are also translated.

Master commit `787a98b1f3ea2530f475ce093dde61caec2954b5` integrates the
Spanish, Hindi, and German locale work and the shared English fixes. The
common fixes are now part of master; Portuguese integration has no live
dependency on an open Spanish, Hindi, or German PR. Their translated locale
catalogues remain separate.

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

The following resource counts are from the earlier Portuguese-branch audit.
The Android pt-BR resources contain all 58 default string keys. Positional
format placeholders match the English resources. The iOS catalogue contains
pt-BR translations for all 50 source entries, with matching placeholders.
The three iOS permission descriptions have pt-BR translations registered in
the Xcode project. English native fallback values remain unchanged.

All nine bundled text fonts contain the 26 Portuguese accented letters
checked with `fc-query`. The JamIcons icon font is not a text font.

## Device limits

Fresh environment checks found no T3 devices. iOS verification requires
macOS. The Android SDK exists at `/home/ubuntu/android-sdk`, but there is no
AVD, emulator executable, or KVM; `adb devices -l` is empty. `verify-prism doctor`
reports missing `axe` for iOS and `adb` not on `PATH` for Android.

No device screenshots or runtime verification are claimed. Widget layout
tests and APK builds are separate checks, not substitutes for device proof.

## Current integration status

The current merged tree has six Flutter catalogues: `en`, `de`, `es`, `hi`,
`pt`, and `pt_BR`. The current catalogue checker passed for all 2,502 messages
across all six catalogues. The font check passed for all nine bundled text
fonts and 26 Portuguese accented letters. Structural native-resource coverage
passed for the 50-entry platform-parent union, including the deliberate pt-BR
24-hour duration correction.

Final generation, focused tests, full local checks, and hosted CI results
should be recorded on the PR after completion. No device screenshots or
runtime results are available from this T3 environment. Credentials to verify
RevenueCat and store-managed purchase copy remain unverified; do not infer
remote paywall translation coverage from catalogue checks.

## Verification commands

Historical Portuguese-branch results (before integration with the current
master catalogue set):

`python3 tool/check_l10n.py` checks all 2,502 messages in each of the three
catalogues. `fvm flutter gen-l10n` passed with no missing pt-BR keys.
`make file-gen` passed and left no unrelated generated-source changes.
The hard-coded-string audit passed with zero probable UI literals.
Indirect literals were reviewed separately, including native error callers.

Focused locale and native tests live in `test/l10n/pt_br_localization_test.dart`
and `test/l10n/pt_br_native_resources_test.dart`. The four native resource
tests passed. Locale behaviour tests cover region selection, English fallback,
interpolation, number/date formatting, zero/one/many coin plurals, and real
onboarding/button/sheet layouts at 320 pixels with enlarged text.

The full local commands at that time were `make ci ANALYZE_FLAGS=--no-fatal-infos
TEST_FLAGS=--concurrency=2` and `make native-android-check` with this host's
Java 21 installation. Their final results and hosted CI belong to the PR
verification record. Neither command provides the missing device proof.
