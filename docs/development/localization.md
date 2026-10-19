# Add a language to Prism

Prism uses Flutter `gen-l10n`. `lib/l10n/app_en.arb` is the English template. The app follows the device locale and falls back to English when the device language is unsupported. Keep `en` in `preferred-supported-locales` in `l10n.yaml` when adding catalogs.

## Shared English foundation

The shared English localization foundation is already integrated in baseline `bdd3e48c3543c81c007ac13d0ee896f9128c048a`. It contains 2,401 message keys in `app_en.arb`; extend this catalog when app copy changes, rather than extracting the existing copy again. Keep ARB message keys stable and preserve each typed placeholder's name, type, and format across translations. Translate full messages and retain valid ICU plural/select structure.

Flutter `gen-l10n` discovers `app_<locale>.arb` catalogs and generates `supportedLocales`; adding a catalog registers that locale without a separate Dart locale list. English remains the fallback through `preferred-supported-locales: [en]`. Each supported language still needs its native Android and iOS resources, including strings used by notifications and other background or platform UI, because Dart localization may not be available there. See the platform and notification steps below before shipping a locale.

1. Copy `lib/l10n/app_en.arb` to `lib/l10n/app_<locale>.arb` and set `@@locale` to the new locale.
2. Translate complete messages. Preserve message keys, placeholder names, and ICU plural and select syntax. Add the plural cases required by the target language.
3. Run `fvm flutter gen-l10n`. Flutter derives `supportedLocales` from the ARB catalogs; no manual locale list is needed. Commit the catalog and generated Dart files in `lib/l10n/generated/` together.
4. Add Android translations in `android/app/src/main/res/values-<locale>/strings.xml`. Include notification, widget, and Quick Settings text.
5. Add iOS translations to the Runner string resources, including permission descriptions, App Shortcuts, and background notifications. Register the locale in the Xcode project.
6. Follow the notification resource instructions in [Notifications](../features/notifications.md). Background push banners use native resources because Dart may not be running.
7. Run `make l10n-check` and `make ci`. Drive the app in the new language on the iOS Simulator and Android emulator. Check long labels, dialogs, accessibility announcements, plurals, dates, numbers, and text direction.

Do not ship machine-generated or placeholder translations as a supported locale.

## Change app copy

Import `package:Prism/l10n/l10n.dart` and use `context.l10n` in widgets. Pass an `AppLocalizations` instance to presentation helpers that do not have a widget context. For background work, call `loadAppLocalizations(locale)` with an explicit locale.

Keep whole sentences in ARB messages. Use typed placeholders for user data and ICU plurals for counts. Flutter does not expand ICU `#`; write the named number placeholder in each plural branch. Give numeric placeholders an appropriate `intl` format (usually `decimalPattern`) so separators follow the active locale. Do not join translated sentence fragments or derive labels by capitalizing stored identifiers.

Use the active `localeName` when formatting dates and numbers. Use Flutter's time formatting when the device's 12-hour or 24-hour preference matters. Use directional layout values for reading-order spacing.

Keep storage keys, routes, analytics identifiers, asset names, and external API values stable. Translate their display labels separately. User-created titles, names, and campaign messages are content, not translation keys. Diagnostic logs and exception details remain developer-facing; present localized errors to users.

## Audit source copy

`make l10n-check` checks catalog key parity, placeholder contracts, generated-file freshness, and source-copy rules. Each supported catalog must translate every English message and retain its placeholder names and types.

`fvm dart run tool/l10n_audit.dart` writes an AST-based JSON inventory. `--check` fails on probable UI literals. The report also lists indirect strings for review. A zero probable count alone does not prove that all user-facing copy is localized.

Inspect helper-returned strings, defaults, enum labels, validation messages, and strings arriving from repositories. Test fixtures can retain English expected values. Widget tests must provide `AppLocalizations.localizationsDelegates` and `AppLocalizations.supportedLocales` to their app wrapper.

## Externally managed purchase copy

The app-owned Premium screens and purchase errors belong in the ARB catalog. The purchase sheet uses `RevenueCatUI.presentPaywall` in `lib/core/purchases/paywall_orchestrator.dart`. Its remote template and store product titles, descriptions, and prices are managed outside this repository. Catalog parity cannot verify those translations. Verify each target language against the configured RevenueCat offering and the App Store and Play product metadata with an authorized account before release. Do not infer remote coverage from a localized fallback page.

iOS App Shortcuts use `ios/Runner/Localizable.xcstrings`, which is registered in the Runner resource build phase. Add locale entries there; do not add a second `Localizable.strings` table. Native media bridge diagnostic details remain English when their Dart callers map error codes to localized UI messages.
