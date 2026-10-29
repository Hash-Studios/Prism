import 'dart:async';

import 'package:Prism/core/coins/daily_chest.dart';
import 'package:Prism/features/daily_flow/biz/daily_moment_cubit.dart';
import 'package:Prism/features/daily_flow/domain/daily_moment_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_daily_moment_repository.dart';

void main() {
  test('shows actual streak receipt before chest and only a free spin', () async {
    final repository = FakeDailyMomentRepository();
    final cubit = DailyMomentCubit(repository);
    addTearDown(cubit.close);
    await cubit.start();
    expect(cubit.state.step, DailyMomentStep.streak);
    expect(cubit.state.receipt?.totalReward, 7);
    expect(repository.pendingReceipt, isNull);
    expect(repository.calls, isEmpty);
    await cubit.primary();
    expect(cubit.state.step, DailyMomentStep.chest);
    expect(cubit.state.chestCost, 20);
    await cubit.primary();
    expect(cubit.state.coins, 12);
    await cubit.primary();
    expect(cubit.state.step, DailyMomentStep.spin);
    await cubit.primary();
    expect(cubit.state.coins, 10);
    await cubit.primary();
    expect(cubit.state.done, isTrue);
    expect(repository.calls, <String>['refresh', 'chest:20', 'refresh', 'spin:0']);
  });

  test('fast taps issue one mutation and closing stops progression', () async {
    final repository = FakeDailyMomentRepository()..pendingChest = Completer<DailyChestResult>();
    final cubit = DailyMomentCubit(repository, requestedStep: DailyMomentStep.chest);
    addTearDown(cubit.close);
    await cubit.start();
    final first = cubit.primary();
    await cubit.primary();
    expect(repository.calls.where((call) => call.startsWith('chest:')), hasLength(1));
    cubit.stop();
    repository.pendingChest!.complete(const ChestFailed('offline'));
    await first;
    await cubit.primary();
    expect(repository.calls, <String>['refresh', 'chest:20']);
  });

  test('explicit unavailable spin stays on spin and never opens chest', () async {
    final repository = FakeDailyMomentRepository()..freeSpinAvailable = false;
    final cubit = DailyMomentCubit(repository, requestedStep: DailyMomentStep.spin);
    addTearDown(cubit.close);
    await cubit.start();
    expect(cubit.state.step, DailyMomentStep.spin);
    expect(cubit.state.unavailable, isTrue);
    await cubit.primary();
    expect(repository.calls, <String>['refresh']);
  });

  test('normal flow ends after chest without a free Pro spin', () async {
    final repository = FakeDailyMomentRepository()..freeSpinAvailable = false;
    final cubit = DailyMomentCubit(repository, requestedStep: DailyMomentStep.chest);
    addTearDown(cubit.close);
    await cubit.start();
    await cubit.primary();
    await cubit.primary();
    expect(cubit.state.done, isTrue);
    expect(repository.calls, isNot(contains('spin:0')));
  });

  test('account changes discard a late result', () async {
    final repository = FakeDailyMomentRepository()..pendingChest = Completer<DailyChestResult>();
    final cubit = DailyMomentCubit(repository, requestedStep: DailyMomentStep.chest);
    addTearDown(cubit.close);
    await cubit.start();
    final request = cubit.primary();
    repository.accountId = 'other';
    repository.pendingChest!.complete(
      const ChestWon(win: ChestWin(slot: 0, coins: 12), cost: 20, doubled: false, slots: defaultChest),
    );
    await request;
    expect(cubit.state.coins, isNull);
  });
  test('account changes clear a displayed receipt and never resume for the previous account', () async {
    final repository = FakeDailyMomentRepository();
    final cubit = DailyMomentCubit(repository);
    addTearDown(cubit.close);
    await cubit.start();
    expect(cubit.state.hasReceipt, isTrue);
    repository.accountId = 'other';
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.hasReceipt, isFalse);
    expect(cubit.state.unavailable, isTrue);
    repository.accountId = 'account';
    await cubit.primary();
    expect(repository.calls, isEmpty);
  });

  test('a manual moment with no pending receipt checks the daily streak first', () async {
    final repository = FakeDailyMomentRepository()..pendingReceipt = null;
    final cubit = DailyMomentCubit(repository);
    addTearDown(cubit.close);
    await cubit.start();
    expect(repository.calls, <String>['streak', 'refresh']);
    expect(cubit.state.step, DailyMomentStep.chest);
  });

  test('UTC rollover refreshes the visible price before any chest charge', () async {
    final repository = FakeDailyMomentRepository()..clock = DateTime.utc(2026, 10, 29, 23, 59);
    final cubit = DailyMomentCubit(repository, requestedStep: DailyMomentStep.chest);
    addTearDown(cubit.close);
    await cubit.start();
    repository.clock = DateTime.utc(2026, 10, 30);
    repository.chest = const DailyChestStatus(opened: false, questsLeft: 0, price: 30);
    await cubit.primary();
    expect(repository.calls, <String>['refresh', 'refresh']);
    expect(cubit.state.chestCost, 0);
    await cubit.primary();
    expect(repository.calls.last, 'chest:0');
  });
}
