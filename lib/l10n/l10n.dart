import 'package:Prism/l10n/generated/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

export 'package:Prism/l10n/generated/app_localizations.dart';

/// Provides the generated messages for the active app locale.
extension AppLocalizationsBuildContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// Messages for [context], or the device locale when [context] is above the app's [Localizations] widget.
///
/// [AppLocalizations.of] throws in that case. Callers that can run before the widget is under
/// [MaterialApp], such as the auto-rotate session listener, use this instead.
Future<AppLocalizations> localizationsFor(BuildContext context) {
  final AppLocalizations? inherited = Localizations.of<AppLocalizations>(context, AppLocalizations);
  if (inherited != null) return Future<AppLocalizations>.value(inherited);
  return loadDeviceAppLocalizations();
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
    WidgetsBinding.instance.platformDispatcher.locales,
    AppLocalizations.supportedLocales,
  );
  return loadAppLocalizations(resolvedLocale);
}
