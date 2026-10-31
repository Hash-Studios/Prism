import 'dart:async';

import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/coins/daily_chest.dart';
import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/core/coins/spin_wheel.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/local_store.dart';
import 'package:Prism/core/persistence/persistence_runtime.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/daily_flow/domain/daily_moment_repository.dart';
import 'package:Prism/features/session/domain/repositories/session_repository.dart';
import 'package:flutter/foundation.dart';

class CoinsDailyMomentRepository implements DailyMomentRepository {
  CoinsDailyMomentRepository({CoinsService? coins, LocalStore? store})
    : _coins = coins ?? CoinsService.instance,
      _storeOverride = store;
  final LocalStore? _storeOverride;
  LocalStore get _store => _storeOverride ?? PersistenceRuntime.store;
  static final Map<String, String> _shown = <String, String>{};
  final CoinsService _coins;

  @override
  String get accountId => app_state.prismUser.loggedIn ? app_state.prismUser.id : '';
  @override
  Stream<String> watchAccount() => getIt.isRegistered<SessionRepository>()
      ? getIt<SessionRepository>().watchCurrentUser().map((user) => user.loggedIn ? user.id : '')
      : Stream<String>.value(accountId);
  @override
  DateTime now() => DateTime.now();
  @override
  bool get streakAvailable {
    final status = _coins.streakNotifier.value;
    final day = now().toUtc().add(Duration(minutes: status.timezoneOffsetMinutes)).toIso8601String().substring(0, 10);
    return status.lastClaimDate != day;
  }

  @override
  StreakClaimResult? get pendingReceipt => _coins.pendingClaimForCurrentUser;
  @override
  void consumeReceipt() => _coins.consumeLastClaim();
  @override
  Future<StreakClaimResult?> claimStreak() async {
    final result = await _coins.claimDailyLoginAndStreakIfEligible();
    if (!result.success) throw StateError(result.reason);
    return _coins.pendingClaimForCurrentUser;
  }

  @override
  Future<void> refresh() async {
    await _coins.progressQuest(null);
    _coins.refreshSpinWheelStatus();
  }

  @override
  DailyChestStatus? get chest => DailyChestStatus.fromQuests(
    _coins.questsNotifier.value,
    today: economyDayKey(now()),
    price: CoinPolicy.dailyChestPrice,
  );
  @override
  bool get freeSpinAvailable {
    _coins.refreshSpinWheelStatus();
    return _coins.spinWheelNotifier.value.freeSpinAvailable;
  }

  @override
  int get balance => _coins.balanceNotifier.value;
  @override
  Stream<int> watchBalance() {
    late final StreamController<int> controller;
    void changed() => controller.add(balance);
    controller = StreamController<int>(
      onListen: () => _coins.balanceNotifier.addListener(changed),
      onCancel: () => _coins.balanceNotifier.removeListener(changed),
    );
    return controller.stream;
  }

  @override
  Future<DailyChestResult> openChest({required int maxCost}) => _coins.openDailyChest(maxCost: maxCost);
  @override
  Future<SpinWheelResult> takeFreeSpin() => _coins.spinWheel(maxCost: 0);

  String _day(DateTime date) => '${date.year}-${date.month}-${date.day}';
  String _key(String id) => 'dailyMoment.shown.$id';
  @override
  bool shownOn(String accountId, DateTime day) => (_shown[_key(accountId)] ?? _store.get(_key(accountId))) == _day(day);
  @override
  Future<void> markShown(String accountId, DateTime day) async {
    _shown[_key(accountId)] = _day(day);
    try {
      await _store.set(_key(accountId), _day(day));
    } catch (_) {
      debugPrint('Daily moment shown marker could not be saved.');
    }
  }
}
