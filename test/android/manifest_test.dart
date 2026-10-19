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

  test('the Quick Settings tile setup hint comes from a translatable Android resource', () {
    final String strings = File('android/app/src/main/res/values/strings.xml').readAsStringSync();
    final String tileSource = File(
      'android/app/src/main/kotlin/com/hash/prism/WallpaperTileService.kt',
    ).readAsStringSync();
    expect(strings, contains('name="tile_setup_subtitle"'));
    expect(tileSource, contains('getString(R.string.tile_setup_subtitle)'));
    expect(tileSource, isNot(contains('"Open Prism to set up"')));
  });

  test('the media save confirmation uses a folder placeholder in an Android string resource', () {
    final String strings = File('android/app/src/main/res/values/strings.xml').readAsStringSync();
    final String mediaSource = File(
      'android/app/src/main/kotlin/com/hash/prism/PrismMediaHostApiImpl.kt',
    ).readAsStringSync();
    expect(strings, contains('name="media_saved_in_pictures">Saved in Pictures/%1\$s!</string>'));
    expect(mediaSource, contains('getString(R.string.media_saved_in_pictures, folder)'));
    expect(mediaSource, isNot(contains(r'"Saved in Pictures/$folder!"')));
  });

  group('launcher icons', () {
    const List<String> aliases = <String>['.IconNoir', '.IconGlass', '.IconSunset', '.IconMono'];

    String element(String tag, String name) {
      final RegExpMatch? match = RegExp(
        '<$tag\\s[^>]*?android:name="${RegExp.escape(name)}".*?</$tag>',
        dotAll: true,
      ).firstMatch(manifest);
      expect(match, isNotNull, reason: '$tag $name');
      return match!.group(0)!;
    }

    void expectLauncher(String body) {
      expect(body, contains('android.intent.action.MAIN'));
      expect(body, contains('android.intent.category.LAUNCHER'));
    }

    void expectDeepLinks(String body) {
      expect(body, contains('android:autoVerify="true"'));
      expect(body, contains('android:host="prismwalls.com"'));
      expect(body, contains('android:scheme="prism"'));
    }

    test('MainActivity is the default launcher icon and keeps the deep links', () {
      final String main = element('activity', '.MainActivity');
      expectLauncher(main);
      expectDeepLinks(main);
      expect(main, isNot(contains('android:enabled="false"')));
      expect(manifest, isNot(contains('.IconDefault')));
    });

    test('each alternate icon alias is off by default and carries the launcher and deep-link filters', () {
      for (final String name in aliases) {
        final String alias = element('activity-alias', name);
        expect(alias, contains('android:enabled="false"'), reason: name);
        expect(alias, contains('android:exported="true"'), reason: name);
        expect(alias, contains('android:targetActivity=".MainActivity"'), reason: name);
        expectLauncher(alias);
        expectDeepLinks(alias);
      }
    });
  });
}
