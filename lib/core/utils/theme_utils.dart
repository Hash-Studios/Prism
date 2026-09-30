import 'package:flutter/material.dart';

extension ThemeBrightnessX on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
}

extension ColorRgbHexX on Color {
  /// Six-digit RGB hex without alpha or `#`, as used by the SVG illustration templates.
  String get rgbHex => (toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0');
}

/// Picks the [dark] or [light] SVG template for the active theme and swaps the
/// template's placeholder hex colours for theme colours.
String themedIllustration(BuildContext context, {required String dark, required String light}) {
  final ThemeData theme = Theme.of(context);
  final String secondary = theme.colorScheme.secondary.rgbHex;
  return (theme.brightness == Brightness.dark ? dark : light)
      .replaceAll('181818', theme.primaryColor.rgbHex)
      .replaceAll('E57697', theme.colorScheme.error.rgbHex)
      .replaceAll('F0F0F0', secondary)
      .replaceAll('2F2E41', secondary)
      .replaceAll('3F3D56', secondary)
      .replaceAll('2F2F2F', theme.hintColor.rgbHex);
}
