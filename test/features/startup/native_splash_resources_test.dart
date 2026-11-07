import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// The native launch follows the system mode, like the default System theme mode: white by day, black at night.
// Android 12+ also gets the in-app mode through `prism/launch_theme` (#683).
void main() {
  const String resources = 'android/app/src/main/res';

  String readResource(String path) => File('$resources/$path').readAsStringSync();

  String? styleAttribute(String style, String attribute, List<String> qualifiers) {
    for (final qualifier in qualifiers.reversed) {
      final path = File('$resources/$qualifier/styles.xml');
      if (!path.existsSync()) continue;
      final declaration = RegExp(
        '<style name="$style" parent="([^"]+)"(?:\\s*/>|>(.*?)</style>)',
        dotAll: true,
      ).firstMatch(path.readAsStringSync());
      if (declaration == null) continue;
      final value = RegExp('<item name="$attribute">(.*?)</item>').firstMatch(declaration.group(2) ?? '')?.group(1);
      if (value != null) return value;
      final parent = declaration.group(1)!;
      return parent.startsWith('@android:') ? null : styleAttribute(parent, attribute, qualifiers);
    }
    return null;
  }

  String? color(String value, {required bool night}) {
    final String? name = RegExp(r'^@color/(.+)$').firstMatch(value)?.group(1);
    if (name == null) return value;
    for (final qualifier in <String>[if (night) 'values-night', 'values']) {
      final file = File('$resources/$qualifier/colors.xml');
      if (!file.existsSync()) continue;
      final match = RegExp('<color name="$name">(.*?)</color>').firstMatch(file.readAsStringSync());
      if (match != null) return match.group(1);
    }
    return null;
  }

  String? boolean(String? value, {required bool night}) {
    if (value == null) return null;
    final String? name = RegExp(r'^@bool/(.+)$').firstMatch(value)?.group(1);
    if (name == null) return value;
    for (final qualifier in <String>[if (night) 'values-night', 'values']) {
      final file = File('$resources/$qualifier/bools.xml');
      if (!file.existsSync()) continue;
      final match = RegExp('<bool name="$name">(.*?)</bool>').firstMatch(file.readAsStringSync());
      if (match != null) return match.group(1);
    }
    return null;
  }

  test('native system bar icons contrast with the day and night backgrounds', () {
    for (final sdk in <int>[24, 25, 26, 27, 29, 30, 31, 37]) {
      for (final night in <bool>[false, true]) {
        final qualifiers = <String>[
          'values',
          if (sdk >= 26) 'values-v26',
          if (sdk >= 27) 'values-v27',
          if (sdk >= 29) 'values-v29',
          if (sdk >= 31) 'values-v31',
          if (night) 'values-night',
        ];
        for (final theme in <String>['LaunchTheme', 'NormalTheme']) {
          final reason = '$theme on API $sdk in ${night ? 'night' : 'day'} mode';
          expect(
            boolean(styleAttribute(theme, 'android:windowLightStatusBar', qualifiers), night: night),
            night ? 'false' : 'true',
            reason: reason,
          );
          expect(
            boolean(styleAttribute(theme, 'android:windowLightNavigationBar', qualifiers), night: night),
            sdk >= 26 ? (night ? 'false' : 'true') : null,
            reason: reason,
          );
          // Before API 26 the navigation glyphs are always light, so their background must stay dark.
          expect(
            styleAttribute(theme, 'android:navigationBarColor', qualifiers),
            sdk >= 26 ? '@android:color/transparent' : '@android:color/black',
            reason: reason,
          );
        }
      }
    }
  });

  test('native launch background is white by day and black at night', () {
    final String? drawableColor = RegExp(
      r'android:drawable="([^"]+)"',
    ).firstMatch(readResource('drawable/launch_background.xml'))?.group(1);
    expect(color(drawableColor!, night: false), '#FFFFFF');
    expect(color(drawableColor, night: true), '#000000');
    for (final sdk in <int>[24, 27, 29, 31, 37]) {
      for (final night in <bool>[false, true]) {
        final qualifiers = <String>[
          'values',
          if (sdk >= 26) 'values-v26',
          if (sdk >= 27) 'values-v27',
          if (sdk >= 29) 'values-v29',
          if (sdk >= 31) 'values-v31',
          if (night) 'values-night',
        ];
        expect(styleAttribute('LaunchTheme', 'android:windowBackground', qualifiers), '@drawable/launch_background');
        final String? splash = styleAttribute('LaunchTheme', 'android:windowSplashScreenBackground', qualifiers);
        expect(splash == null ? null : color(splash, night: night), sdk >= 31 ? (night ? '#000000' : '#FFFFFF') : null);
        final String? iconBackground = styleAttribute(
          'LaunchTheme',
          'android:windowSplashScreenIconBackgroundColor',
          qualifiers,
        );
        expect(
          iconBackground == null ? null : color(iconBackground, night: night),
          sdk >= 31 ? (night ? '#000000' : '#FFFFFF') : null,
        );
        expect(
          styleAttribute('LaunchTheme', 'android:windowLayoutInDisplayCutoutMode', qualifiers),
          sdk >= 27 ? 'shortEdges' : null,
        );
        expect(
          styleAttribute('LaunchTheme', 'android:enforceNavigationBarContrast', qualifiers),
          sdk >= 29 ? 'false' : null,
        );
        expect(
          styleAttribute('NormalTheme', 'android:windowBackground', qualifiers),
          night ? '?android:colorBackground' : '@android:color/white',
        );
      }
    }
  });

  test('iOS launch screen background follows the system appearance', () {
    final String storyboard = File('ios/Runner/Base.lproj/LaunchScreen.storyboard').readAsStringSync();
    expect(storyboard, contains('<color key="backgroundColor" systemColor="systemBackgroundColor"/>'));
  });
}
