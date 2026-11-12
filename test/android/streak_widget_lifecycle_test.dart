import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String sourceBlock(String source, String startMarker) {
  final int start = source.indexOf(startMarker);
  expect(start, isNonNegative, reason: startMarker);
  final int openBrace = source.indexOf('{', start);
  expect(openBrace, isNonNegative, reason: startMarker);
  var depth = 0;
  for (var index = openBrace; index < source.length; index++) {
    if (source[index] == '{') depth++;
    if (source[index] == '}') depth--;
    if (depth == 0) return source.substring(openBrace, index + 1);
  }
  fail('Unclosed source block for $startMarker');
}

void main() {
  late String manifest;
  late String provider;

  setUpAll(() {
    manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    provider = File('android/app/src/main/kotlin/com/hash/prism/StreakWidgetProvider.kt').readAsStringSync();
  });

  test('the streak widget restores its midnight refresh after system clock and app lifecycle changes', () {
    final RegExpMatch? receiver = RegExp(
      r'<receiver\s[^>]*android:name="\.StreakWidgetProvider"[^>]*>(.*?)</receiver>',
      dotAll: true,
    ).firstMatch(manifest);
    expect(receiver, isNotNull);
    final String receiverXml = receiver!.group(0)!;
    expect(receiverXml, contains('android:exported="false"'));
    final String onReceive = sourceBlock(provider, 'override fun onReceive(');
    final int refreshBranchEnd = onReceive.indexOf('-> refresh(context)');
    expect(refreshBranchEnd, isNonNegative);
    final String refreshBranch = onReceive.substring(0, refreshBranchEnd);
    const Map<String, String> actions = <String, String>{
      'android.intent.action.BOOT_COMPLETED': 'ACTION_BOOT_COMPLETED',
      'android.intent.action.MY_PACKAGE_REPLACED': 'ACTION_MY_PACKAGE_REPLACED',
      'android.intent.action.TIME_SET': 'ACTION_TIME_CHANGED',
      'android.intent.action.TIMEZONE_CHANGED': 'ACTION_TIMEZONE_CHANGED',
    };
    for (final MapEntry<String, String> action in actions.entries) {
      expect(receiverXml, contains('<action android:name="${action.key}"'), reason: action.key);
      expect(refreshBranch, contains('Intent.${action.value}'), reason: action.key);
    }
  });

  test('the streak widget does not poll and clears its alarm when no widget instances remain', () {
    final String info = File('android/app/src/main/res/xml/streak_widget_info.xml').readAsStringSync();
    expect(info, contains('android:updatePeriodMillis="0"'));
    final String refresh = sourceBlock(provider, 'fun refresh(context: Context)');
    final String noWidgets = sourceBlock(refresh, 'if (ids.isEmpty())');
    expect(noWidgets, contains('alarmManager(context).cancel(midnightIntent(context))'));
    expect(provider, contains('alarms.cancel(pending)'));
  });

  test('signed-out and streak taps have distinct explicit immutable PendingIntent identities', () {
    final String views = sourceBlock(provider, 'private fun views(');
    expect(views, contains('openApp(context, null)'));
    expect(views, contains('openApp(context, STREAK_WIDGET_LINK)'));

    final String openApp = sourceBlock(provider, 'private fun openApp(');
    expect(openApp, contains('Intent(context, MainActivity::class.java)'));
    expect(openApp, contains('if (link != null)'));
    expect(openApp, contains('launch.action = Intent.ACTION_VIEW'));
    expect(openApp, contains('launch.data = Uri.parse(link)'));
    expect(openApp, contains('PendingIntent.getActivity(context, REQUEST_OPEN, launch'));
    expect(openApp, contains('PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT'));

    final RegExpMatch? midnightIntentMatch = RegExp(
      r'private fun midnightIntent\([\s\S]*?\n        \)',
    ).firstMatch(provider);
    expect(midnightIntentMatch, isNotNull);
    final String midnightIntent = midnightIntentMatch!.group(0)!;
    expect(midnightIntent, contains('Intent(context, StreakWidgetProvider::class.java).setAction(ACTION_MIDNIGHT)'));
    expect(midnightIntent, contains('PendingIntent.getBroadcast('));
    expect(midnightIntent, contains('PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT'));
    expect(provider, contains('private const val REQUEST_OPEN = 0'));
    expect(provider, contains('private const val REQUEST_MIDNIGHT = 1'));
  });
}
