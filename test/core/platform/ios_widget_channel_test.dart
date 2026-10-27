import 'package:Prism/core/platform/ios_widget_channel.dart';
import 'package:Prism/core/platform/pigeon/prism_widget_api.g.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeWidgetApi extends PrismWidgetHostApi {
  final List<StreakWidgetSnapshot?> snapshots = <StreakWidgetSnapshot?>[];
  int reloads = 0;
  Object? error;

  @override
  Future<void> setStreakSnapshot(StreakWidgetSnapshot? snapshot) async {
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
  final PrismWidgetHostApi defaultApi = IosWidgetChannel.api;
  final bool Function() defaultSupported = IosWidgetChannel.isSupportedPlatform;
  late _FakeWidgetApi fake;

  setUp(() {
    fake = _FakeWidgetApi();
    IosWidgetChannel.api = fake;
    IosWidgetChannel.isSupportedPlatform = () => true;
  });

  tearDown(() {
    IosWidgetChannel.api = defaultApi;
    IosWidgetChannel.isSupportedPlatform = defaultSupported;
  });

  test('does nothing on unsupported platforms', () async {
    IosWidgetChannel.isSupportedPlatform = () => false;
    await IosWidgetChannel.setStreak(_snapshot());
    await IosWidgetChannel.clearStreak();
    await IosWidgetChannel.reloadWallOfTheDay();
    expect(fake.snapshots, isEmpty);
    expect(fake.reloads, 0);
  });

  test('setStreak passes the snapshot through', () async {
    await IosWidgetChannel.setStreak(_snapshot());
    expect(fake.snapshots, <StreakWidgetSnapshot?>[_snapshot()]);
  });

  test('clearStreak sends null', () async {
    await IosWidgetChannel.clearStreak();
    expect(fake.snapshots, <StreakWidgetSnapshot?>[null]);
  });

  test('reloadWallOfTheDay calls the api', () async {
    await IosWidgetChannel.reloadWallOfTheDay();
    expect(fake.reloads, 1);
  });

  test('an api error does not throw out of the channel', () async {
    fake.error = PlatformException(code: 'x');
    await expectLater(IosWidgetChannel.setStreak(_snapshot()), completes);
    await expectLater(IosWidgetChannel.clearStreak(), completes);
    await expectLater(IosWidgetChannel.reloadWallOfTheDay(), completes);
  });
}
