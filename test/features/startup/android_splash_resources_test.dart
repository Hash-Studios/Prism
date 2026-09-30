import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const String resources = 'android/app/src/main/res';

  String readResource(String path) => File('$resources/$path').readAsStringSync();

  test('launch background follows Android day and night resource qualifiers', () {
    for (final String qualifier in <String>['drawable', 'drawable-v21']) {
      expect(readResource('$qualifier/launch_background.xml'), contains('@android:color/white'));
    }

    for (final String qualifier in <String>['drawable-night', 'drawable-night-v21']) {
      expect(readResource('$qualifier/launch_background.xml'), contains('@android:color/black'));
    }
  });

  test('API 31 splash resources match their day and night theme colors', () {
    final String icon = readResource('drawable/splash_icon_transparent.xml');
    expect(icon, contains('android:fillColor="?android:windowSplashScreenBackground"'));

    for (final (String qualifier, String expectedColor) in <(String, String)>[
      ('values-v31', '@android:color/white'),
      ('values-night-v31', '#000000'),
    ]) {
      final String theme = readResource('$qualifier/styles.xml');
      expect(theme, contains('<item name="android:windowSplashScreenBackground">$expectedColor</item>'));
      expect(theme, contains('<item name="android:windowSplashScreenIconBackgroundColor">$expectedColor</item>'));
      expect(
        theme,
        contains('<item name="android:windowSplashScreenAnimatedIcon">@drawable/splash_icon_transparent</item>'),
      );
      expect(theme, contains('<item name="android:windowBackground">@drawable/launch_background</item>'));
    }

    expect(readResource('values/styles.xml'), isNot(contains('@drawable/splash_icon_transparent')));
    expect(readResource('values-night/styles.xml'), isNot(contains('@drawable/splash_icon_transparent')));
  });
}
