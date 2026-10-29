import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/coins/daily_chest.dart';
import 'package:Prism/core/coins/spin_wheel.dart';

enum DailyMomentStep { streak, chest, spin }

abstract class DailyMomentRepository {
  String get accountId;
  Stream<String> watchAccount();
  DateTime now();
  bool get streakAvailable;
  StreakClaimResult? get pendingReceipt;
  void consumeReceipt();
  Future<StreakClaimResult?> claimStreak();
  Future<void> refresh();
  DailyChestStatus? get chest;
  bool get freeSpinAvailable;
  int get balance;
  Future<DailyChestResult> openChest({required int maxCost});
  Future<SpinWheelResult> takeFreeSpin();
  bool shownOn(String accountId, DateTime day);
  Future<void> markShown(String accountId, DateTime day);
}
