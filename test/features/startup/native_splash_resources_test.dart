import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Prism defaults to a dark app theme, so the native launch stays black in both
// system modes to avoid a white flash before the dark Flutter splash.
void main() {
  const String resources = 'android/app/src/main/res';

  String readResource(String path) => File('$resources/$path').readAsStringSync();

  test('native launch background is black in day and night', () {
    for (final String qualifier in <String>['drawable', 'drawable-v21', 'drawable-night', 'drawable-night-v21']) {
      expect(readResource('$qualifier/launch_background.xml'), contains('@android:color/black'));
    }
    for (final String qualifier in <String>['values-v31', 'values-night-v31']) {
      expect(
        readResource('$qualifier/styles.xml'),
        contains('<item name="android:windowSplashScreenBackground">#000000</item>'),
      );
    }
  });

  test('iOS launch screen background is black', () {
    final String storyboard = File('ios/Runner/Base.lproj/LaunchScreen.storyboard').readAsStringSync();
    expect(storyboard, contains('<color key="backgroundColor" red="0" green="0" blue="0" alpha="1"'));
  });
}
