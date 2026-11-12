import 'dart:async';

import 'package:Prism/core/platform/pigeon/prism_widget_api.g.dart';
import 'package:Prism/core/platform/widget_channel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeWidgetApi extends PrismWidgetHostApi {
  final List<StreakWidgetSnapshot?> snapshots = <StreakWidgetSnapshot?>[];
  int reloads = 0;
  Object? error;
  Completer<void>? setStarted;
  Completer<void>? releaseSet;

  @override
  Future<void> setStreakSnapshot(StreakWidgetSnapshot? snapshot) async {
    if (releaseSet != null && snapshot != null && setStarted?.isCompleted == false) {
      setStarted?.complete();
      await releaseSet!.future;
    }
    snapshots.add(snapshot);
    if (error != null) throw error!;
  }

  @override
  Future<void> reloadWallOfTheDay() async {
    reloads++;
    if (error != null) throw error!;
  }
}

StreakWidgetSnapshot _snapshot() =>
    StreakWidgetSnapshot(count: 12, lastKeptDay: '2026-10-27', utcOffsetMinutes: 330, freezes: 1);

void main() {
  final PrismWidgetHostApi defaultApi = WidgetChannel.api;
  final bool Function() defaultSupported = WidgetChannel.isSupportedPlatform;
  late _FakeWidgetApi fake;

  setUp(() {
    fake = _FakeWidgetApi();
    WidgetChannel.api = fake;
    WidgetChannel.isSupportedPlatform = () => true;
  });

  tearDown(() {
    WidgetChannel.api = defaultApi;
    WidgetChannel.isSupportedPlatform = defaultSupported;
  });

  test('does nothing on unsupported platforms', () async {
    WidgetChannel.isSupportedPlatform = () => false;
    await WidgetChannel.setStreak(_snapshot());
    await WidgetChannel.clearStreak();
    await WidgetChannel.reloadWallOfTheDay();
    expect(fake.snapshots, isEmpty);
    expect(fake.reloads, 0);
  });

  test('setStreak passes the snapshot through', () async {
    await WidgetChannel.setStreak(_snapshot());
    expect(fake.snapshots, <StreakWidgetSnapshot?>[_snapshot()]);
  });

  test('clearStreak sends null', () async {
    await WidgetChannel.clearStreak();
    expect(fake.snapshots, <StreakWidgetSnapshot?>[null]);
  });

  test('reloadWallOfTheDay calls the api', () async {
    await WidgetChannel.reloadWallOfTheDay();
    expect(fake.reloads, 1);
  });

  test('an api error does not throw out of the channel', () async {
    fake.error = PlatformException(code: 'x');
    await expectLater(WidgetChannel.setStreak(_snapshot()), completes);
    await expectLater(WidgetChannel.clearStreak(), completes);
    await expectLater(WidgetChannel.reloadWallOfTheDay(), completes);
  });

  test('a clear invalidates a snapshot that has not reached the host yet', () async {
    fake.setStarted = Completer<void>();
    fake.releaseSet = Completer<void>();
    final Future<bool> firstWrite = WidgetChannel.setStreak(_snapshot());
    await fake.setStarted!.future;
    final StreakWidgetSnapshot newer = StreakWidgetSnapshot(
      count: 13,
      lastKeptDay: '2026-10-28',
      utcOffsetMinutes: 330,
      freezes: 1,
    );
    final Future<bool> queuedWrite = WidgetChannel.setStreak(newer);
    final Future<void> clear = WidgetChannel.clearStreak();
    fake.releaseSet!.complete();
    await Future.wait<void>(<Future<void>>[firstWrite.then<void>((_) {}), queuedWrite.then<void>((_) {}), clear]);
    expect(fake.snapshots, <StreakWidgetSnapshot?>[_snapshot(), null]);
  });
}
