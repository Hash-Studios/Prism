import 'dart:ui' show PlatformDispatcher;

import 'package:Prism/l10n/generated/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

export 'package:Prism/l10n/generated/app_localizations.dart';

/// Provides the generated messages for the active app locale.
extension AppLocalizationsBuildContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// Formats a whole number with the grouping and digits used by the active app locale.
String formatLocalizedNumber(int value, AppLocalizations l10n) =>
    NumberFormat.decimalPattern(l10n.localeName).format(value);

/// Loads messages for an explicit locale in code that has no [BuildContext].
///
/// The locale resolves with Flutter's supported-locale rules. This does not
/// create a process-wide default locale.
Future<AppLocalizations> loadAppLocalizations(Locale locale) {
  final Locale resolvedLocale = basicLocaleListResolution(<Locale>[locale], AppLocalizations.supportedLocales);
  return AppLocalizations.delegate.load(resolvedLocale);
}

/// Loads messages for the device's preferred locale list using Flutter's locale resolution rules.
Future<AppLocalizations> loadDeviceAppLocalizations() {
  final Locale resolvedLocale = basicLocaleListResolution(
    PlatformDispatcher.instance.locales,
    AppLocalizations.supportedLocales,
  );
  return AppLocalizations.delegate.load(resolvedLocale);
}
