import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/platform/ios_widget_channel.dart';
import 'package:Prism/core/platform/pigeon/prism_widget_api.g.dart';
import 'package:Prism/core/platform/streak_widget_sync.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeWidgetApi extends PrismWidgetHostApi {
  final List<StreakWidgetSnapshot?> snapshots = <StreakWidgetSnapshot?>[];
  int reloads = 0;

  @override
  Future<void> setStreakSnapshot(StreakWidgetSnapshot? snapshot) async {
    snapshots.add(snapshot);
  }

  @override
  Future<void> reloadWallOfTheDay() async {
    reloads++;
  }
}

const StreakStatus _status = StreakStatus(
  streakDay: 3,
  count: 12,
  best: 20,
  freezes: 1,
  active: true,
  claimedToday: true,
  reminderEnabled: true,
  timezoneOffsetMinutes: 330,
  lastClaimDate: '2026-10-27',
);

StreakStatus _nextStatus() => const StreakStatus(
  streakDay: 4,
  count: 13,
  best: 20,
  freezes: 1,
  active: true,
  claimedToday: true,
  reminderEnabled: true,
  timezoneOffsetMinutes: 330,
  lastClaimDate: '2026-10-28',
);

void main() {
  final PrismWidgetHostApi defaultApi = IosWidgetChannel.api;
  final bool Function() defaultSupported = IosWidgetChannel.isSupportedPlatform;
  final ValueListenable<StreakStatus> Function() defaultStreak = StreakWidgetSync.streak;
  final bool Function() defaultSignedIn = StreakWidgetSync.isSignedIn;
  late _FakeWidgetApi fake;
  late ValueNotifier<StreakStatus> notifier;
  bool signedIn = true;

  setUp(() {
    fake = _FakeWidgetApi();
    IosWidgetChannel.api = fake;
    IosWidgetChannel.isSupportedPlatform = () => true;
    notifier = ValueNotifier<StreakStatus>(StreakStatus.empty);
    StreakWidgetSync.streak = () => notifier;
    signedIn = true;
    StreakWidgetSync.isSignedIn = () => signedIn;
    StreakWidgetSync.resetForTest();
  });

  tearDown(() {
    StreakWidgetSync.resetForTest();
    notifier.dispose();
    IosWidgetChannel.api = defaultApi;
    IosWidgetChannel.isSupportedPlatform = defaultSupported;
    StreakWidgetSync.streak = defaultStreak;
    StreakWidgetSync.isSignedIn = defaultSignedIn;
  });

  test('writes on app open', () async {
    notifier.value = _status;
    StreakWidgetSync.start();
    await pumpEventQueue();
    expect(fake.snapshots.length, 1);
    final StreakWidgetSnapshot sent = fake.snapshots.single!;
    expect(sent.count, 12);
    expect(sent.lastKeptDay, '2026-10-27');
    expect(sent.utcOffsetMinutes, 330);
    expect(sent.freezes, 1);
  });

  test('skips the empty status while the user loads', () async {
    StreakWidgetSync.start();
    await pumpEventQueue();
    expect(fake.snapshots, isEmpty);
  });

  test('writes on change', () async {
    StreakWidgetSync.start();
    await pumpEventQueue();
    notifier.value = _status;
    await pumpEventQueue();
    notifier.value = _nextStatus();
    await pumpEventQueue();
    expect(fake.snapshots.map((StreakWidgetSnapshot? s) => s!.count).toList(), <int>[12, 13]);
  });

  test('does not resend an unchanged snapshot', () async {
    StreakWidgetSync.start();
    notifier.value = _status;
    await pumpEventQueue();
    notifier.value = StreakStatus(
      streakDay: _status.streakDay,
      count: _status.count,
      best: _status.best,
      freezes: _status.freezes,
      active: _status.active,
      claimedToday: _status.claimedToday,
      reminderEnabled: _status.reminderEnabled,
      timezoneOffsetMinutes: _status.timezoneOffsetMinutes,
      lastClaimDate: _status.lastClaimDate,
    );
    await pumpEventQueue();
    expect(fake.snapshots.length, 1);
  });

  test('clears on sign-out', () async {
    StreakWidgetSync.start();
    notifier.value = _status;
    await pumpEventQueue();
    signedIn = false;
    notifier.value = StreakStatus.empty;
    await pumpEventQueue();
    expect(fake.snapshots.last, isNull);
  });

  test('clears on app open when signed out', () async {
    signedIn = false;
    StreakWidgetSync.start();
    await pumpEventQueue();
    expect(fake.snapshots, <StreakWidgetSnapshot?>[null]);
  });
}
