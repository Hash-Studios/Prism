import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String manifest;

  setUpAll(() => manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync());

  test('Auto Backup is off so a new phone starts without stale app flags', () {
    expect(manifest, contains('android:allowBackup="false"'));
  });

  test('the prism scheme opens the app', () {
    expect(manifest, contains('android:scheme="prism"'));
  });

  test('the Wall of the Day widget is registered and not exported', () {
    final RegExpMatch? receiver = RegExp(
      r'<receiver\s[^>]*android:name="\.WotdWidgetProvider"[^>]*>',
    ).firstMatch(manifest);
    expect(receiver, isNotNull);
    expect(receiver!.group(0), contains('android:exported="false"'));
    expect(manifest, contains('android.appwidget.action.APPWIDGET_UPDATE'));
    expect(File('android/app/src/main/res/xml/wotd_widget_info.xml').readAsStringSync(), contains('86400000'));
  });
}
