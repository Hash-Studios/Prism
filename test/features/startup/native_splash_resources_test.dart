import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Prism defaults to a dark app theme, so the native launch stays black in both
// system modes to avoid a white flash before the dark Flutter splash.
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

  test('native launch background is black in day and night', () {
    expect(readResource('drawable/launch_background.xml'), contains('@android:color/black'));
    for (final sdk in <int>[24, 27, 29, 31, 37]) {
      for (final night in <bool>[false, true]) {
        final qualifiers = <String>[
          'values',
          if (sdk >= 27) 'values-v27',
          if (sdk >= 29) 'values-v29',
          if (sdk >= 31) 'values-v31',
          if (night) 'values-night',
        ];
        expect(styleAttribute('LaunchTheme', 'android:windowBackground', qualifiers), '@drawable/launch_background');
        expect(
          styleAttribute('LaunchTheme', 'android:windowSplashScreenBackground', qualifiers),
          sdk >= 31 ? '#000000' : null,
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

  test('iOS launch screen background is black', () {
    final String storyboard = File('ios/Runner/Base.lproj/LaunchScreen.storyboard').readAsStringSync();
    expect(storyboard, contains('<color key="backgroundColor" red="0" green="0" blue="0" alpha="1"'));
  });
}
