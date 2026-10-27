import 'package:Prism/features/theme_mode/domain/entities/theme_preferences.dart';
import 'package:Prism/theme/prism_theme_options.dart';
import 'package:flutter/material.dart';

/// The theme copy kept on the account at `usersv2/{uid}.themePrefs`.
class AccountTheme {
  const AccountTheme({required this.preferences, required this.changedAt});

  static const String field = 'themePrefs';

  final ThemePreferences preferences;

  /// Milliseconds since epoch of the local change that produced this copy.
  final int changedAt;

  /// Null when [raw] is missing or does not match the wire shape.
  static AccountTheme? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final ThemeMode? mode = ThemeMode.values.asNameMap()[raw['mode']];
    final String? lightId = _asId(raw['lightThemeId']);
    final int? lightAccent = _asInt(raw['lightAccent']);
    final String? darkId = _asId(raw['darkThemeId']);
    final int? darkAccent = _asInt(raw['darkAccent']);
    final int? changedAt = _asInt(raw['changedAt']);
    if (mode == null ||
        lightId == null ||
        lightAccent == null ||
        darkId == null ||
        darkAccent == null ||
        changedAt == null) {
      return null;
    }
    return AccountTheme(
      preferences: ThemePreferences(
        light: ThemeSelection(themeId: lightId, accentColorValue: lightAccent),
        dark: ThemeSelection(themeId: darkId, accentColorValue: darkAccent),
        mode: mode,
      ),
      changedAt: changedAt,
    );
  }

  Map<String, Object> toMap() => <String, Object>{
    'mode': preferences.mode.name,
    'lightThemeId': preferences.light.themeId,
    'lightAccent': preferences.light.accentColorValue,
    'darkThemeId': preferences.dark.themeId,
    'darkAccent': preferences.dark.accentColorValue,
    'changedAt': changedAt,
  };

  static String? _asId(Object? value) => value is String && value.isNotEmpty ? value : null;

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num && value.isFinite && value == value.truncateToDouble()) return value.toInt();
    return null;
  }
}

/// The account copy applied over [local]. A light or dark slot keeps the local selection
/// when this device may not use the account's theme for that slot. The mode always follows the account.
/// Material You is always kept, even where the phone has no Material You colours: that device shows the default
/// theme for the slot, and the account keeps Material You for the devices that have them.
ThemePreferences mergeAccountTheme({
  required ThemePreferences account,
  required ThemePreferences local,
  required Set<String> owned,
  required Set<String> legacyThemes,
}) {
  return ThemePreferences(
    light: _mergeSlot(account.light, local.light, prismLightThemes, prismMaterialYouLightThemeId, owned, legacyThemes),
    dark: _mergeSlot(account.dark, local.dark, prismDarkThemes, prismMaterialYouDarkThemeId, owned, legacyThemes),
    mode: account.mode,
  );
}

ThemeSelection _mergeSlot(
  ThemeSelection account,
  ThemeSelection local,
  List<PrismThemeOption> options,
  String materialYouId,
  Set<String> owned,
  Set<String> legacyThemes,
) {
  if (account.themeId == materialYouId) return account;
  final PrismThemeOption? option = prismThemeById(options, account.themeId);
  if (option == null) return local;
  final String? shopItemId = option.shopItemId;
  final bool usable =
      shopItemId == null ||
      option.id == local.themeId ||
      legacyThemes.contains(option.id) ||
      owned.contains(shopItemId);
  return usable ? account : local;
}
