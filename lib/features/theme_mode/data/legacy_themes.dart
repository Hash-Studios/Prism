import 'dart:async';

import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';

/// Settings key for the themes a device already used before the coin shop sold them, as comma separated ids.
const String legacyThemesSettingsKey = 'theme.legacy_themes';

/// Theme ids that stay free on this device.
Set<String> readLegacyThemes(SettingsLocalDataSource settings) {
  final String stored = settings.get<String>(legacyThemesSettingsKey, defaultValue: '');
  return stored.isEmpty ? const <String>{} : stored.split(',').toSet();
}

/// Stores the selected themes on the first run that knows about the shop, and does nothing after that.
void rememberLegacyThemes(SettingsLocalDataSource settings, {required String lightId, required String darkId}) {
  if (settings.get<String?>(legacyThemesSettingsKey) != null) return;
  unawaited(settings.set(legacyThemesSettingsKey, '$lightId,$darkId'));
}
