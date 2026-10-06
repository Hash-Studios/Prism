/// Picks the theme mode to store on launch. Builds before the System default always wrote `WHcategories` at
/// startup but only wrote `themeMode` after a manual change, so those installs keep Dark. Fresh installs get System.
/// Returns null when a mode is already stored.
String? initialThemeModeToStore({required Object? storedMode, required bool hasLegacyMarker}) {
  if (storedMode != null) return null;
  return hasLegacyMarker ? 'Dark' : 'System';
}
