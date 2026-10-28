import 'dart:async';

import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/platform/ios_widget_channel.dart';
import 'package:Prism/core/platform/pigeon/prism_widget_api.g.dart';
import 'package:Prism/core/platform/streak_widget_sync.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeWidgetApi extends PrismWidgetHostApi {
  final List<StreakWidgetSnapshot?> snapshots = <StreakWidgetSnapshot?>[];
  int reloads = 0;
  int setAttempts = 0;
  bool failNextSet = false;
  bool blockNextSet = false;
  Completer<void>? firstSetStarted;
  Completer<void>? releaseFirstSet;

  @override
  Future<void> setStreakSnapshot(StreakWidgetSnapshot? snapshot) async {
    setAttempts++;
    if (blockNextSet && snapshot != null && releaseFirstSet != null) {
      blockNextSet = false;
      firstSetStarted?.complete();
      await releaseFirstSet!.future;
    }
    if (failNextSet) {
      failNextSet = false;
      throw StateError('write failed');
    }
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
  final String Function() defaultOwnerId = StreakWidgetSync.ownerId;
  final Stream<String?> Function() defaultOwnerChanges = StreakWidgetSync.ownerChanges;
  late _FakeWidgetApi fake;
  late ValueNotifier<StreakStatus> notifier;
  late StreamController<String?> owners;
  bool signedIn = true;
  String ownerId = 'user-a';

  setUp(() {
    fake = _FakeWidgetApi();
    IosWidgetChannel.api = fake;
    IosWidgetChannel.isSupportedPlatform = () => true;
    notifier = ValueNotifier<StreakStatus>(StreakStatus.empty);
    StreakWidgetSync.streak = () => notifier;
    signedIn = true;
    ownerId = 'user-a';
    StreakWidgetSync.isSignedIn = () => signedIn;
    StreakWidgetSync.ownerId = () => ownerId;
    owners = StreamController<String?>();
    StreakWidgetSync.ownerChanges = () => owners.stream;
    StreakWidgetSync.resetForTest();
  });

  tearDown(() {
    StreakWidgetSync.resetForTest();
    notifier.dispose();
    IosWidgetChannel.api = defaultApi;
    IosWidgetChannel.isSupportedPlatform = defaultSupported;
    StreakWidgetSync.streak = defaultStreak;
    StreakWidgetSync.isSignedIn = defaultSignedIn;
    StreakWidgetSync.ownerId = defaultOwnerId;
    StreakWidgetSync.ownerChanges = defaultOwnerChanges;
    unawaited(owners.close());
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

  test("clears the previous user's snapshot while the signed-in user loads", () async {
    StreakWidgetSync.start();
    await pumpEventQueue();
    expect(fake.snapshots, <StreakWidgetSnapshot?>[null]);
  });

  test('writes on change', () async {
    StreakWidgetSync.start();
    await pumpEventQueue();
    notifier.value = _status;
    await pumpEventQueue();
    notifier.value = _nextStatus();
    await pumpEventQueue();
    expect(fake.snapshots.map((StreakWidgetSnapshot? s) => s?.count).toList(), <int?>[null, 12, 13]);
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
    expect(fake.snapshots.map((StreakWidgetSnapshot? s) => s?.count).toList(), <int?>[null, 12]);
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

  test('resends an unchanged snapshot for a different account', () async {
    notifier.value = _status;
    StreakWidgetSync.start();
    await pumpEventQueue();
    ownerId = 'user-b';
    StreakWidgetSync.start();
    StreakWidgetSync.start();
    await pumpEventQueue();
    expect(fake.snapshots.map((StreakWidgetSnapshot? s) => s?.count).toList(), <int?>[12, null]);
    notifier.value = _status.copyWith();
    await pumpEventQueue();
    expect(fake.snapshots.map((StreakWidgetSnapshot? s) => s?.count).toList(), <int?>[12, null, 12]);
  });

  test('keeps a fresh streak when it arrives before the owner stream update', () async {
    notifier.value = _status;
    StreakWidgetSync.start();
    await pumpEventQueue();
    ownerId = 'user-b';
    notifier.value = _nextStatus();
    await pumpEventQueue();
    owners.add('user-b');
    await pumpEventQueue();
    expect(fake.snapshots.map((StreakWidgetSnapshot? s) => s?.count).toList(), <int?>[12, null, 13]);
  });

  test('clears on an owner stream update before fresh streak data arrives', () async {
    notifier.value = _status;
    StreakWidgetSync.start();
    await pumpEventQueue();
    ownerId = 'user-b';
    owners.add('user-b');
    await pumpEventQueue();
    expect(fake.snapshots.map((StreakWidgetSnapshot? s) => s?.count).toList(), <int?>[12, null]);
    notifier.value = _nextStatus();
    await pumpEventQueue();
    expect(fake.snapshots.map((StreakWidgetSnapshot? s) => s?.count).toList(), <int?>[12, null, 13]);
  });

  test('retries a failed widget write on the next sync', () async {
    notifier.value = _status;
    fake.failNextSet = true;
    StreakWidgetSync.start();
    await pumpEventQueue();
    StreakWidgetSync.start();
    await pumpEventQueue();
    expect(fake.snapshots, <StreakWidgetSnapshot?>[_snapshotForStatus(_status)]);
  });

  test('retries a failed privacy clear without restoring the blocked account snapshot', () async {
    notifier.value = _status;
    StreakWidgetSync.start();
    await pumpEventQueue();
    fake.failNextSet = true;
    await StreakWidgetSync.clear();
    StreakWidgetSync.start();
    await pumpEventQueue();
    expect(fake.setAttempts, 3);
    expect(fake.snapshots, <StreakWidgetSnapshot?>[_snapshotForStatus(_status), null]);
  });

  test('a direct privacy clear blocks fresh snapshots until the account changes', () async {
    notifier.value = _status;
    StreakWidgetSync.start();
    await pumpEventQueue();
    await IosWidgetChannel.clearStreak();
    StreakWidgetSync.start();
    await pumpEventQueue();
    expect(fake.snapshots.last, isNull);
    notifier.value = _nextStatus();
    await pumpEventQueue();
    expect(fake.snapshots.whereType<StreakWidgetSnapshot>(), <StreakWidgetSnapshot>[_snapshotForStatus(_status)]);
    expect(fake.snapshots.last, isNull);
    ownerId = 'user-b';
    owners.add('user-b');
    await pumpEventQueue();
    notifier.value = _status.copyWith();
    await pumpEventQueue();
    expect(fake.snapshots.last?.count, 12);
  });

  test('a privacy clear blocks snapshot updates while sign-out is still pending', () async {
    notifier.value = _status;
    StreakWidgetSync.start();
    await pumpEventQueue();
    await StreakWidgetSync.clear();
    notifier.value = _nextStatus();
    StreakWidgetSync.start();
    await pumpEventQueue();
    expect(fake.snapshots, <StreakWidgetSnapshot?>[_snapshotForStatus(_status), null]);
  });

  test('retries a failed direct privacy clear without restoring the same account', () async {
    notifier.value = _status;
    StreakWidgetSync.start();
    await pumpEventQueue();
    fake.failNextSet = true;
    await IosWidgetChannel.clearStreak();
    StreakWidgetSync.start();
    notifier.value = _nextStatus();
    await pumpEventQueue();
    expect(fake.snapshots.last, isNull);
    expect(fake.snapshots.whereType<StreakWidgetSnapshot>().map((s) => s.count), <int>[12]);
  });

  test('a pending snapshot cannot land after sign-out clears the widget', () async {
    notifier.value = _status;
    fake.blockNextSet = true;
    fake.firstSetStarted = Completer<void>();
    fake.releaseFirstSet = Completer<void>();
    StreakWidgetSync.start();
    await fake.firstSetStarted!.future;
    signedIn = false;
    notifier.value = StreakStatus.empty;
    fake.releaseFirstSet!.complete();
    await pumpEventQueue();
    expect(fake.snapshots.last, isNull);
  });

  test('writes the latest state when an in-flight snapshot changes A to B to A', () async {
    notifier.value = _status;
    fake.blockNextSet = true;
    fake.firstSetStarted = Completer<void>();
    fake.releaseFirstSet = Completer<void>();
    StreakWidgetSync.start();
    await fake.firstSetStarted!.future;
    notifier.value = _nextStatus();
    notifier.value = _status.copyWith();
    fake.releaseFirstSet!.complete();
    await pumpEventQueue();
    expect(fake.snapshots.map((StreakWidgetSnapshot? s) => s?.count).toList(), <int?>[12, 13, 12]);
  });

  test('returns to an acknowledged snapshot after a newer write is queued', () async {
    notifier.value = _status;
    StreakWidgetSync.start();
    await pumpEventQueue();
    fake.blockNextSet = true;
    fake.firstSetStarted = Completer<void>();
    fake.releaseFirstSet = Completer<void>();
    notifier.value = _nextStatus();
    await fake.firstSetStarted!.future;
    notifier.value = _status.copyWith();
    fake.releaseFirstSet!.complete();
    await pumpEventQueue();
    expect(fake.snapshots.map((StreakWidgetSnapshot? s) => s?.count).toList(), <int?>[12, 13, 12]);
  });
}

StreakWidgetSnapshot _snapshotForStatus(StreakStatus status) => StreakWidgetSnapshot(
  count: status.count,
  lastKeptDay: status.lastClaimDate,
  utcOffsetMinutes: status.timezoneOffsetMinutes,
  freezes: status.freezes,
);
