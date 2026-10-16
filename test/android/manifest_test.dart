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
    expect(File('android/app/src/main/res/xml/wotd_widget_info.xml').readAsStringSync(), contains('10800000'));
  });

  test('the Wall of the Day widget refreshes every 3 hours and ships a picker preview', () {
    final String info = File('android/app/src/main/res/xml/wotd_widget_info.xml').readAsStringSync();
    expect(info, contains('android:previewLayout="@layout/wotd_widget_preview"'));
    expect(info, contains('android:previewImage="@drawable/wotd_widget_preview_art"'));
    expect(File('android/app/src/main/res/layout/wotd_widget_preview.xml').existsSync(), isTrue);
    expect(
      File('android/app/src/main/res/drawable-v31/wotd_widget_bg.xml').readAsStringSync(),
      contains('system_app_widget_background_radius'),
    );
  });

  test('the widget layout has a Set button and the strings it needs', () {
    final String layout = File('android/app/src/main/res/layout/wotd_widget.xml').readAsStringSync();
    expect(layout, contains('@+id/wotd_set'));
    final String strings = File('android/app/src/main/res/values/strings.xml').readAsStringSync();
    for (final String name in <String>[
      'wotd_widget_set_done',
      'wotd_widget_set_failed',
      'wotd_widget_set_description',
    ]) {
      expect(strings, contains('name="$name"'));
    }
  });
}
