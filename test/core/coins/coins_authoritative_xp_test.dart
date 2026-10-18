import 'dart:async';

import 'package:Prism/core/coins/coin_action.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_error.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:flutter_test/flutter_test.dart';

import '../../support/coins_test_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final CoinsService coins = CoinsService.instance;
  final CoinsTestBackend backend = CoinsTestBackend();
  late CoinsTestFirestore firestore;
  Map<String, dynamic> snapshot(int xp, int week, {String? weekKey}) => <String, dynamic>{
    'xpPolicyVersion': 1,
    'xp': xp,
    'xpAwarded': 9999,
    'xpWeek': <String, Object?>{'weekKey': weekKey ?? economyWeekKey(DateTime.now()), 'xp': week},
  };
  void apply(Map<String, dynamic> data) =>
      coins.applyRoutineXpReply(data, userId: backend.userId, session: coins.economySession);

  setUp(() async {
    await getIt.reset();
    await backend.install();
    coins.resetSession();
    firestore = CoinsTestFirestore()..userData = <String, dynamic>{'coins': 100};
    getIt.registerSingleton<FirestoreClient>(firestore);
    backend.onCall = (_, _) async => <String, Object?>{'success': false};
  });
  tearDown(() async {
    await coins.reconcileRankRewards();
    coins.resetSession();
    app_state.prismUser = app_constants.createGuestPrismUser();
    await getIt.reset();
  });

  test('absolute snapshots and replay receipts never add the awarded amount', () {
    apply(snapshot(110, 10));
    apply(snapshot(110, 10));
    apply(snapshot(105, 5));
    expect(coins.xpNotifier.value.xp, 110);
    expect(coins.xpNotifier.value.weekXp, 10);
  });

  test('award callers apply an unchanged server receipt without deriving XP from coins', () async {
    backend.onCall = (name, _) async => name == 'awardCoins'
        ? <String, Object?>{'success': true, 'changed': false, 'currentBalance': 120, ...snapshot(130, 30)}
        : <String, Object?>{'success': false};
    await coins.award(CoinEarnAction.rewardedAd);
    expect(coins.xpNotifier.value.xp, 130);
    expect(coins.xpNotifier.value.weekXp, 30);
  });

  test('missing and malformed old backend fields reconcile without inventing zero or coin XP', () async {
    apply(snapshot(110, 10));
    int reconciliations = 0;
    backend.onCall = (name, _) async {
      if (name == 'reconcileRankRewards') {
        reconciliations++;
        return <String, Object?>{'success': true, ...snapshot(115, 15)};
      }
      return <String, Object?>{'success': true, 'changed': false, 'currentBalance': 100};
    };
    await coins.award(CoinEarnAction.rewardedAd);
    await coins.reconcileRankRewards();
    expect(reconciliations, greaterThan(0));
    expect(coins.xpNotifier.value.xp, 115);
    apply(<String, dynamic>{...snapshot(0, 0), 'xpWeek': 'bad'});
    expect(coins.xpNotifier.value.xp, 115);
  });

  test('prior session and account responses cannot hydrate the current account', () {
    final int session = coins.economySession;
    coins.resetSession();
    coins.applyRoutineXpReply(snapshot(999, 99), userId: backend.userId, session: session);
    expect(coins.xpNotifier.value.xp, 0);
    app_state.prismUser.id = 'other';
    coins.applyRoutineXpReply(snapshot(999, 99), userId: backend.userId, session: coins.economySession);
    expect(coins.xpNotifier.value.xp, 0);
  });

  test('a prior week snapshot cannot masquerade as current week XP', () {
    apply(snapshot(110, 90, weekKey: '2000-W01'));
    expect(coins.xpNotifier.value.weekXp, 0);
    apply(snapshot(120, 5));
    apply(snapshot(115, 999, weekKey: '2000-W01'));
    expect(coins.xpNotifier.value.weekXp, 5);
  });

  test('legacy root XP without a weekly snapshot keeps historical lifetime progress', () async {
    firestore.userData = <String, dynamic>{'coins': 100, 'xp': 1234};
    await coins.refreshBalance();
    expect(coins.xpNotifier.value.xp, 1234);
    expect(coins.xpNotifier.value.weekXp, 0);
  });

  test('a fresh daily receipt and a replay both reconcile newly earned rank cosmetics', () async {
    int reconciliations = 0;
    backend.onCall = (name, _) async {
      if (name == 'claimDailyStreak') return <String, Object?>{...CoinsTestBackend.claimPayload, ...snapshot(500, 5)};
      reconciliations++;
      return <String, Object?>{
        'success': true,
        'rev': 1,
        'owned': <String>['glow_aurora'],
        ...snapshot(500, 5),
      };
    };
    await coins.claimDailyLoginAndStreakIfEligible();
    await coins.reconcileRankRewards();
    expect(coins.inventoryNotifier.value.owned, contains('glow_aurora'));
    final int beforeReplay = reconciliations;
    apply(<String, dynamic>{...snapshot(500, 5), 'xpAwarded': 0});
    await coins.reconcileRankRewards();
    expect(reconciliations, greaterThan(beforeReplay));
    expect(coins.xpNotifier.value.xp, 500);
  });

  test('activity defaults and config validation are independent of coin multipliers', () {
    final EconomyXp xp = EconomyXp.fromMap(<String, dynamic>{
      'perCoinEarned': 99,
      'activities': <String, Object?>{'dailyStreak': -1, 'streakWeek': 2.5, 'questChest': 0},
    });
    expect(xp.activities.dailyStreak, 5);
    expect(xp.activities.streakWeek, 25);
    expect(xp.activities.questChest, 0);
    expect(xp.activities.firstWallpaperUpload, 50);
    expect(xp.activities.profileCompletion, 25);
  });

  test('a stale root refresh cannot undo a fresh daily claim or its XP', () async {
    apply(snapshot(100, 0));
    final Completer<Map<String, dynamic>> root = Completer<Map<String, dynamic>>();
    firestore.userResponse = root.future;
    final Future<int> refresh = coins.refreshBalance();
    await firestore.privateEconomyReadStarted.future;
    backend.onCall = (name, _) async => name == 'claimDailyStreak'
        ? <String, Object?>{...CoinsTestBackend.claimPayload, ...snapshot(105, 5)}
        : <String, Object?>{'success': false};
    await coins.claimDailyLoginAndStreakIfEligible();
    root.complete(<String, dynamic>{
      'coins': 100,
      ...snapshot(100, 0),
      'coinState': <String, Object?>{'streakDay': 1, 'streakCount': 1, 'lastDailyClaimDate': '2000-01-01'},
    });
    await refresh;
    expect(coins.xpNotifier.value.xp, 105);
    expect(coins.streakNotifier.value.count, 3);
    expect(coins.streakNotifier.value.claimedToday, isTrue);
  });

  test('private creator reads preserve revision ordering and report stale offline data', () async {
    final Map<String, dynamic> creator = <String, dynamic>{
      'version': 1,
      'trackedSinceMs': DateTime.utc(2026, 10).millisecondsSinceEpoch,
      'approvedWalls': 0,
      'uniqueMembers': 0,
      'awardedIds': <String>[],
      'milestones': <Object?>[
        <String, Object?>{'id': 'approvedWalls_1', 'metric': 'approvedWalls', 'target': 1, 'xp': 50},
        <String, Object?>{'id': 'uniqueMembers_1', 'metric': 'uniqueMembers', 'target': 1, 'xp': 25},
      ],
      'weeks': <Object?>[],
    };
    firestore.docs['usersv2/${backend.userId}/private/economy'] = <String, dynamic>{
      'rev': 5,
      'creator': creator,
      'spinWheel': <String, Object>{'dayKey': economyDayKey(DateTime.now()), 'paid': 2, 'freeUsed': true},
    };
    await coins.refreshCreatorProgress();
    expect(coins.creatorNotifier.value.progress?.approvedWalls, 0);
    expect(coins.spinWheelNotifier.value.paidSpinsLeft, 3);
    firestore.docs['usersv2/${backend.userId}/private/economy'] = <String, dynamic>{
      'rev': 4,
      'creator': <String, dynamic>{...creator, 'approvedWalls': 99},
      'spinWheel': <String, Object>{'dayKey': economyDayKey(DateTime.now()), 'paid': 0, 'freeUsed': false},
    };
    await coins.refreshCreatorProgress();
    expect(coins.creatorNotifier.value.progress?.approvedWalls, 0);
    expect(coins.spinWheelNotifier.value.paidSpinsLeft, 3);
    firestore.privateEconomyError = FirestoreError(code: 'unavailable', message: 'offline');
    await coins.refreshCreatorProgress();
    expect(coins.creatorNotifier.value.status.name, 'unavailable');
    expect(coins.creatorNotifier.value.progress?.approvedWalls, 0);
    firestore.privateEconomyError = null;
    final Completer<Map<String, dynamic>> failedRoot = Completer<Map<String, dynamic>>();
    firestore.userResponse = failedRoot.future;
    final Future<void> refresh = coins.refreshCreatorProgress();
    await pumpEventQueue();
    failedRoot.completeError(StateError('offline root read'));
    await refresh;
    expect(coins.creatorNotifier.value.status.name, 'unavailable');
    expect(coins.creatorNotifier.value.progress?.approvedWalls, 0);
  });
}
