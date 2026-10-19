# Spanish localization verification

## Catalog and runtime

`lib/l10n/app_en.arb` remains the canonical English catalog. Spanish uses `app_es.arb`, Flutter `gen-l10n`, and device-locale selection. Unsupported languages fall back to English. The catalog contains 2,499 messages, including accessibility text, errors, onboarding, search, downloads, creator tools, Premium, coins, rewards, referrals, and AI prompts.

`python3 tool/check_l10n.py` checks key parity across both locales. A separate placeholder-use audit found no missing English placeholder names in Spanish messages. Native coverage includes all 58 Android resources, 50 iOS string-catalog records, and three iOS permission descriptions. Existing English resource values and backend identifiers remain unchanged.

The generated messages are exercised by `test/l10n/spanish_locale_test.dart`. It checks device selection, es-MX and es-ES resolution, English fallback, live locale changes, plurals, number grouping, and a 320-pixel confirmation sheet at double text scale. Shared tests cover AI prompt composition, user prompt preservation, localized progress, coin shortfall errors, and upload size formatting.

## Manual source review

The AST audit alone misses indirect strings. Source review also traced AI example pools, sign-in feature interpolation, app shortcuts, upload sliders, saved transaction labels, category chips, native errors, and purchase presentation. Persisted creator names, user prompts, artwork titles, protocol codes, routes, analytics values, and product brands are not translated.

The nine bundled text font assets cover the Spanish accented letters and punctuation. This is a font-character-set check, not a device-rendering result.

## Unavailable proof

This Linux host has no Xcode or `axe`, so the required iOS Simulator run cannot start. The Android build SDK exists, but there is no emulator executable, AVD, system image, attached device, or `/dev/kvm`. The `verify-prism` doctor fails on missing platform tools. No device screenshots or signed-in app-flow checks are claimed.

The purchase sheet comes from `RevenueCatUI.presentPaywall`. Its remote templates and App Store and Play product metadata cannot be inspected from this repository without authorized dashboard credentials. Spanish coverage of those externally managed surfaces remains unverified. No remote product, paywall, store, or deployment changes were made.

## Final gates

Final generation, local gates, Android build, and hosted CI results are recorded here after their runs finish. Earlier tests that overlapped source generation are not final-tree proof.
