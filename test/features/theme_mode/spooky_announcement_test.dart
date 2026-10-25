import 'dart:async';
import 'dart:io';

import 'package:Prism/core/offline/durable_json_store.dart';
import 'package:Prism/core/persistence/data_sources/notifications_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/features/in_app_notifications/domain/entities/in_app_notification_entity.dart';
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

  test('retries after the inbox write fails', () async {
    await directory.delete(recursive: true);
    await File(directory.path).writeAsString('not a directory');

    await expectLater(
      announceSpookyTheme(now: inSeason, l10n: l10n, settings: settings, inbox: inbox, showPush: showPush),
      throwsA(isA<FileSystemException>()),
    );
    expect(settings.get<bool>(spookyAnnouncedKey, defaultValue: false), isFalse);

    await File(directory.path).delete();
    final bool announced = await announceSpookyTheme(
      now: inSeason,
      l10n: l10n,
      settings: settings,
      inbox: inbox,
      showPush: showPush,
    );

    expect(announced, isTrue);
    expect(await inbox.readAll(), hasLength(1));
    expect(pushes, hasLength(1));
  });

  test('keeps an app-update announcement pending and retries it next launch', () async {
    var attempts = 0;
    final bool firstInstallUpdated = await checkSpookyAnnouncementOnAppUpdate(
      currentVersion: '1.1.0',
      currentBuild: '348',
      settings: settings,
      announce: () async {
        attempts++;
        return true;
      },
    );
    expect(firstInstallUpdated, isFalse);
    expect(attempts, 0);
    expect(
      await checkSpookyAnnouncementOnAppUpdate(
        currentVersion: '1.1.0',
        currentBuild: '348',
        settings: settings,
        announce: () async {
          attempts++;
          return true;
        },
      ),
      isFalse,
    );
    expect(attempts, 0);

    await settings.set('lastSeenVersion', '1.0.0');

    final bool firstLaunchUpdated = await checkSpookyAnnouncementOnAppUpdate(
      currentVersion: '1.1.0',
      currentBuild: '348',
      settings: settings,
      now: inSeason,
      announce: () {
        attempts++;
        return Future<bool>.error(StateError('inbox unavailable'));
      },
    );
    expect(firstLaunchUpdated, isTrue);
    expect(settings.get<bool>(spookyAnnouncementPendingKey, defaultValue: false), isTrue);

    final bool retryLaunchUpdated = await checkSpookyAnnouncementOnAppUpdate(
      currentVersion: '1.1.0',
      currentBuild: '348',
      settings: settings,
      now: inSeason,
      announce: () async {
        attempts++;
        return true;
      },
    );

    expect(retryLaunchUpdated, isFalse);
    expect(attempts, 2);
    expect(settings.get<bool>(spookyAnnouncementPendingKey, defaultValue: false), isFalse);
  });

  test('coalesces concurrent announcement attempts into one push', () async {
    final Completer<void> finishPush = Completer<void>();
    var pushCount = 0;
    Future<void> blockedPush(String title, String body) async {
      pushCount++;
      await finishPush.future;
    }

    final Future<bool> first = announceSpookyTheme(
      now: inSeason,
      l10n: l10n,
      settings: settings,
      inbox: inbox,
      showPush: blockedPush,
    );
    final Future<bool> second = announceSpookyTheme(
      now: inSeason,
      l10n: l10n,
      settings: settings,
      inbox: inbox,
      showPush: blockedPush,
    );
    finishPush.complete();

    expect(await first, isTrue);
    expect(await second, isTrue);
    expect(pushCount, 1);
  });

  test('does not mark announced if the notification owner changes during the inbox write', () async {
    await inbox.writeAll(<InAppNotificationEntity>[]);
    final Completer<void> readStarted = Completer<void>();
    final Completer<void> finishRead = Completer<void>();
    inbox = NotificationsLocalDataSource.withStore(
      DurableJsonStore(
        'spooky_announcement',
        directory: directory,
        beforeReadContents: (_) async {
          if (!readStarted.isCompleted) readStarted.complete();
          await finishRead.future;
        },
      ),
    )..setOwner('user-1');

    final Future<bool> announcement = announceSpookyTheme(
      now: inSeason,
      l10n: l10n,
      settings: settings,
      inbox: inbox,
      showPush: showPush,
    );
    await readStarted.future;
    inbox.setOwner('user-2');
    finishRead.complete();

    expect(await announcement, isFalse);
    expect(settings.get<bool>(spookyAnnouncedKey, defaultValue: false), isFalse);
    expect(pushes, isEmpty);
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

  test('clears an expired pending announcement without retrying it', () async {
    await settings.set(spookyAnnouncementPendingKey, true);
    var attempts = 0;

    await checkSpookyAnnouncementOnAppUpdate(
      currentVersion: '1.1.0',
      currentBuild: '348',
      settings: settings,
      announce: () async {
        attempts++;
        return false;
      },
      now: DateTime(2026, 11, 3),
    );

    expect(attempts, 0);
    expect(settings.get<bool>(spookyAnnouncementPendingKey, defaultValue: false), isFalse);
  });

  test('treats a same-version build change as an app update', () async {
    await settings.set('lastSeenVersion', '1.1.0');
    await settings.set('lastSeenBuildVersion', '347');
    var attempts = 0;

    final bool updated = await checkSpookyAnnouncementOnAppUpdate(
      currentVersion: '1.1.0',
      currentBuild: '348',
      settings: settings,
      now: inSeason,
      announce: () async {
        attempts++;
        return true;
      },
    );

    expect(updated, isTrue);
    expect(attempts, 1);
    expect(settings.get<String>('lastSeenBuildVersion'), '348');
  });

  test('migrates an existing version marker to build-aware update tracking', () async {
    await settings.set('lastSeenVersion', '1.1.0');
    var attempts = 0;

    final bool updated = await checkSpookyAnnouncementOnAppUpdate(
      currentVersion: '1.1.0',
      currentBuild: '348',
      settings: settings,
      now: inSeason,
      announce: () async {
        attempts++;
        return true;
      },
    );

    expect(updated, isTrue);
    expect(attempts, 1);
    expect(settings.get<String>('lastSeenBuildVersion'), '348');
  });

  test('keeps the inbox announcement complete when the local push fails', () async {
    final bool announced = await announceSpookyTheme(
      now: inSeason,
      l10n: l10n,
      settings: settings,
      inbox: inbox,
      showPush: (String title, String body) => Future<void>.error(StateError('permission denied')),
    );

    expect(announced, isTrue);
    expect(await inbox.readAll(), hasLength(1));
    expect(settings.get<bool>(spookyAnnouncedKey, defaultValue: false), isTrue);
    expect(
      await announceSpookyTheme(now: inSeason, l10n: l10n, settings: settings, inbox: inbox, showPush: showPush),
      isFalse,
    );
  });
}
