import 'dart:async';

import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/coins/daily_chest.dart';
import 'package:Prism/core/coins/spin_wheel.dart';
import 'package:Prism/features/daily_flow/domain/daily_moment_repository.dart';

class FakeDailyMomentRepository implements DailyMomentRepository {
  @override
  String get accountId => _accountId;
  String _accountId = 'account';
  final _accounts = StreamController<String>.broadcast();
  set accountId(String value) {
    _accountId = value;
    _accounts.add(value);
  }

  @override
  Stream<String> watchAccount() => _accounts.stream;
  @override
  bool streakAvailable = true;
  DateTime clock = DateTime(2026, 10, 29, 23, 59);
  @override
  DateTime now() => clock;
  @override
  StreakClaimResult? pendingReceipt = StreakClaimResult.fromPayload(<String, dynamic>{
    'claimed': true,
    'totalReward': 7,
    'streakCount': 3,
  });
  @override
  void consumeReceipt() => pendingReceipt = null;
  @override
  Future<StreakClaimResult?> claimStreak() async {
    calls.add('streak');
    return pendingReceipt;
  }

  @override
  DailyChestStatus? chest = const DailyChestStatus(opened: false, questsLeft: 2, price: 20);
  @override
  bool freeSpinAvailable = true;
  @override
  int balance = 100;
  final List<String> calls = <String>[];
  Completer<DailyChestResult>? pendingChest;
  @override
  Future<void> refresh() async => calls.add('refresh');
  @override
  Future<DailyChestResult> openChest({required int maxCost}) async {
    calls.add('chest:$maxCost');
    return pendingChest?.future ??
        const ChestWon(win: ChestWin(slot: 0, coins: 12), cost: 20, doubled: false, slots: defaultChest);
  }

  @override
  Future<SpinWheelResult> takeFreeSpin() async {
    calls.add('spin:0');
    return const SpinWon(
      win: WheelWin(segment: 0, coins: 10),
      cost: 0,
      balance: 102,
      segments: defaultWheel,
      status: SpinWheelStatus(freeSpinAvailable: false, paidSpinsLeft: 3, price: 10),
    );
  }

  final Map<String, String> shown = <String, String>{};
  String _day(DateTime day) => '${day.year}-${day.month}-${day.day}';
  @override
  bool shownOn(String accountId, DateTime day) => shown[accountId] == _day(day);
  @override
  Future<void> markShown(String accountId, DateTime day) async => shown[accountId] = _day(day);
}
