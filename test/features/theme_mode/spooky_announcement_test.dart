import 'dart:io';

import 'package:Prism/core/offline/durable_json_store.dart';
import 'package:Prism/core/persistence/data_sources/notifications_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/features/theme_mode/data/spooky_announcement.dart';
import 'package:Prism/l10n/generated/app_localizations.dart';
import 'package:Prism/notifications/notification_pref_keys.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/in_memory_local_store.dart';

void main() {
  final AppLocalizations l10n = lookupAppLocalizations(const Locale('en'));
  final DateTime inSeason = DateTime(2026, 10, 25, 12);
  late Directory directory;
  late SettingsLocalDataSource settings;
  late NotificationsLocalDataSource inbox;
  late List<(String, String)> pushes;

  Future<void> showPush(String title, String body) async => pushes.add((title, body));

  setUp(() {
    directory = Directory.systemTemp.createTempSync('spooky_announcement_test');
    settings = SettingsLocalDataSource(InMemoryLocalStore());
    inbox = NotificationsLocalDataSource.withStore(DurableJsonStore('spooky_announcement', directory: directory))
      ..setOwner('user-1');
    pushes = <(String, String)>[];
  });

  tearDown(() => directory.deleteSync(recursive: true));

  test('announces once in season with an inbox item and a push', () async {
    final bool announced = await announceSpookyTheme(
      now: inSeason,
      l10n: l10n,
      settings: settings,
      inbox: inbox,
      showPush: showPush,
    );

    expect(announced, isTrue);
    final items = await inbox.readAll();
    expect(items, hasLength(1));
    expect(items.single.id, 'local_spooky_theme_2026');
    expect(items.single.title, 'New: the Spooky theme 🎃');
    expect(items.single.route, '/theme');
    expect(pushes, <(String, String)>[('New: the Spooky theme 🎃', l10n.spookyAnnouncementBody)]);
  });

  test('a second call does not announce again', () async {
    await announceSpookyTheme(now: inSeason, l10n: l10n, settings: settings, inbox: inbox, showPush: showPush);

    final bool again = await announceSpookyTheme(
      now: inSeason,
      l10n: l10n,
      settings: settings,
      inbox: inbox,
      showPush: showPush,
    );

    expect(again, isFalse);
    expect(pushes, hasLength(1));
    expect(await inbox.readAll(), hasLength(1));
  });

  test('does nothing after the season ends', () async {
    final bool announced = await announceSpookyTheme(
      now: DateTime(2026, 11, 3),
      l10n: l10n,
      settings: settings,
      inbox: inbox,
      showPush: showPush,
    );

    expect(announced, isFalse);
    expect(await inbox.readAll(), isEmpty);
    expect(pushes, isEmpty);
  });

  test('keeps the inbox item but skips the push when recommendations are off', () async {
    await settings.set(NotificationPrefKeys.recommendations, false);

    final bool announced = await announceSpookyTheme(
      now: inSeason,
      l10n: l10n,
      settings: settings,
      inbox: inbox,
      showPush: showPush,
    );

    expect(announced, isTrue);
    expect((await inbox.readAll()).map((item) => item.id), <String>['local_spooky_theme_2026']);
    expect(pushes, isEmpty);
  });
}
