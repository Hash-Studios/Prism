import 'dart:async';

import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/coins_test_backend.dart';

class _ReminderFirestore extends CoinsTestFirestore {
  final Map<String, dynamic> updates = <String, dynamic>{};

  @override
  Future<T> runTransaction<T>(
    Future<T> Function(FirestoreTransaction) action, {
    required String sourceTag,
    required String collection,
    String? docId,
  }) => action(_ReminderTransaction(userData, updates));
}

class _ReminderTransaction extends Fake implements FirestoreTransaction {
  _ReminderTransaction(this.data, this.updates);

  final Map<String, dynamic> data;
  final Map<String, dynamic> updates;

  @override
  Future<Map<String, dynamic>?> getDoc(String collection, String id) async => data;

  @override
  void updateDoc(String collection, String id, Map<String, dynamic> data) => updates.addAll(data);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final backend = CoinsTestBackend();
  final service = CoinsService.instance;

  setUp(() async {
    await backend.install();
    backend.onCall = (_, _) async => CoinsTestBackend.claimPayload;
    service.consumeLastClaim();
    service.balanceNotifier.value = 100;
    service.streakNotifier.value = StreakStatus.empty;
  });
  tearDown(() async {
    service.consumeLastClaim();
    app_state.prismUser = app_constants.createGuestPrismUser();
    await getIt.reset();
  });

  test('a claim completed after sign-out cannot change the guest balance or queue a sheet', () async {
    final response = Completer<dynamic>();
    backend.onCall = (_, _) => response.future;
    final claim = service.claimDailyLoginAndStreakIfEligible();
    app_state.prismUser = app_constants.createGuestPrismUser();
    response.complete(CoinsTestBackend.claimPayload);
    await claim;
    expect(app_state.prismUser.coins, 0);
    expect(service.lastClaimNotifier.value, isNull);
    expect(service.streakNotifier.value.active, isFalse);
  });

  test('freeze retries replay the same request after a lost response', () async {
    final requestIds = <String>[];
    backend.onCall = (_, parameters) async {
      requestIds.add(parameters['requestId'] as String);
      if (requestIds.length == 1) throw FirebaseFunctionsException(code: 'deadline-exceeded', message: 'lost reply');
      return <String, Object>{'success': true, 'changed': true, 'currentBalance': 50, 'delta': -50, 'streakFreezes': 1};
    };
    expect((await service.buyStreakFreeze()).outcome, StreakFreezeOutcome.failed);
    expect((await service.buyStreakFreeze()).outcome, StreakFreezeOutcome.success);
    expect(requestIds[1], requestIds[0]);
    await service.buyStreakFreeze();
    expect(requestIds[2], isNot(requestIds[0]));
  });

  test('freeze completed for a previous user cannot change the next user balance', () async {
    final response = Completer<dynamic>();
    backend.onCall = (_, _) => response.future;
    final purchase = service.buyStreakFreeze();
    await Future<void>.delayed(Duration.zero);
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'user-2'
      ..loggedIn = true
      ..coins = 9;
    response.complete(<String, Object>{'success': true, 'currentBalance': 50, 'delta': -50, 'streakFreezes': 1});
    await purchase;
    expect(app_state.prismUser.coins, 9);
    expect(service.streakNotifier.value.freezes, 0);
  });

  test('zero-count legacy documents preserve their cycle streak', () async {
    final now = DateTime.now().toUtc();
    final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final firestore = CoinsTestFirestore()
      ..userData = <String, dynamic>{
        'coins': 100,
        'coinState': <String, Object>{
          'streakCount': 0,
          'streakDay': 4,
          'lastDailyClaimDate': today,
          'streakTimezoneOffsetMinutes': 0,
        },
      };
    getIt.registerSingleton<FirestoreClient>(firestore);
    final status = await service.refreshStreakStatus();
    expect(status.active, isTrue);
    expect(status.count, 4);
  });

  test('an old backend without freeze callable preserves current state', () async {
    backend.onCall = (_, _) async => throw FirebaseFunctionsException(code: 'not-found', message: 'missing');
    expect((await service.buyStreakFreeze()).outcome, StreakFreezeOutcome.unavailable);
    expect(app_state.prismUser.coins, 100);
    expect(service.streakNotifier.value.freezes, 0);
  });

  test('pending freeze request survives switching users and is removed after replay', () async {
    String? firstRequest;
    backend.onCall = (_, parameters) {
      firstRequest ??= parameters['requestId'] as String;
      return Future<dynamic>.error(FirebaseFunctionsException(code: 'unavailable', message: 'lost reply'));
    };
    await service.buyStreakFreeze();
    final settings = getIt<SettingsLocalDataSource>();
    expect(settings.get<String>('pendingStreakFreezeRequest.user-1'), firstRequest);
    app_state.prismUser.id = 'user-2';
    backend.onCall = (_, _) async => throw FirebaseFunctionsException(code: 'not-found', message: 'missing');
    await service.buyStreakFreeze();
    app_state.prismUser.id = 'user-1';
    backend.onCall = (_, parameters) async {
      expect(parameters['requestId'], firstRequest);
      return <String, Object>{'success': true, 'changed': false, 'currentBalance': 50, 'delta': 0, 'streakFreezes': 1};
    };
    await service.buyStreakFreeze();
    expect(settings.get<String>('pendingStreakFreezeRequest.user-1', defaultValue: ''), isEmpty);
  });

  test('claim status keeps the server locked timezone', () async {
    backend.onCall = (_, _) async => <String, Object>{...CoinsTestBackend.claimPayload, 'timezoneOffsetMinutes': -720};
    await service.claimDailyLoginAndStreakIfEligible();
    expect(service.streakNotifier.value.timezoneOffsetMinutes, -720);
  });

  test('duplicate old-backend claim responses publish once per user and day', () async {
    backend.onCall = (_, _) async => <String, Object>{
      'claimed': true,
      'streakDay': 3,
      'dailyReward': 8,
      'totalReward': 8,
      'newBalance': 108,
      'todayLocalKey': '2026-09-30',
    };
    await service.claimDailyLoginAndStreakIfEligible();
    expect(service.lastClaimNotifier.value, isNotNull);
    service.consumeLastClaim();
    await service.claimDailyLoginAndStreakIfEligible();
    expect(service.lastClaimNotifier.value, isNull);
    backend.onCall = (_, _) async => <String, Object>{...CoinsTestBackend.claimPayload, 'todayLocalKey': '2026-10-01'};
    await service.claimDailyLoginAndStreakIfEligible();
    expect(service.lastClaimNotifier.value, isNotNull);
  });

  test('reminder preference schedules against the protected streak timezone', () async {
    const offset = -720;
    final localNow = DateTime.now().toUtc().add(const Duration(minutes: offset));
    final today =
        '${localNow.year}-${localNow.month.toString().padLeft(2, '0')}-${localNow.day.toString().padLeft(2, '0')}';
    final firestore = _ReminderFirestore()
      ..userData = <String, dynamic>{
        'coins': 100,
        'coinState': <String, Object>{
          'lastDailyClaimDate': today,
          'streakDay': 4,
          'streakCount': 4,
          'streakClaimTimezoneOffsetMinutes': offset,
        },
      };
    getIt.registerSingleton<FirestoreClient>(firestore);
    await service.setStreakReminderPreference(true);
    final expected = DateTime.utc(
      localNow.year,
      localNow.month,
      localNow.day + 1,
      20,
    ).subtract(const Duration(minutes: offset));
    expect(firestore.updates['coinState.streakReminderNextAtUtc'], expected);
  });

  test('delayed profile refreshes cannot write streak or earn flags to another account', () async {
    final firestore = CoinsTestFirestore();
    getIt.registerSingleton<FirestoreClient>(firestore);
    for (final refresh in <Future<Object?> Function()>[
      service.bootstrapForCurrentUser,
      service.refreshBalance,
      service.refreshStreakStatus,
    ]) {
      final response = Completer<Map<String, dynamic>>();
      firestore.userResponse = response.future;
      app_state.prismUser = app_constants.createGuestPrismUser()
        ..id = 'user-1'
        ..loggedIn = true
        ..coins = 100;
      final pending = refresh();
      app_state.prismUser = app_constants.createGuestPrismUser()
        ..id = 'user-2'
        ..loggedIn = true
        ..coins = 9;
      response.complete(<String, dynamic>{
        'coins': 500,
        'coinState': <String, Object>{'streakDay': 5, 'profileCompletionRewarded': true},
      });
      await pending;
      expect(app_state.prismUser.coins, 9);
      expect(service.earnFlagsNotifier.value, CoinEarnFlags.empty);
      expect(service.streakNotifier.value.count, 0);
    }
  });

  test('late duplicate freeze response preserves a newer pending purchase', () async {
    final responses = <Completer<dynamic>>[];
    final requestIds = <String>[];
    backend.onCall = (_, parameters) {
      requestIds.add(parameters['requestId'] as String);
      final response = Completer<dynamic>();
      responses.add(response);
      return response.future;
    };
    final first = service.buyStreakFreeze();
    final duplicate = service.buyStreakFreeze();
    await Future<void>.delayed(Duration.zero);
    expect(requestIds[0], requestIds[1]);
    const result = <String, Object>{
      'success': true,
      'changed': false,
      'currentBalance': 50,
      'delta': 0,
      'streakFreezes': 1,
    };
    responses[1].complete(result);
    await duplicate;
    final next = service.buyStreakFreeze();
    await Future<void>.delayed(Duration.zero);
    responses[2].completeError(FirebaseFunctionsException(code: 'unavailable', message: 'lost reply'));
    await next;
    responses[0].complete(result);
    await first;
    expect(getIt<SettingsLocalDataSource>().get<String>('pendingStreakFreezeRequest.user-1'), requestIds[2]);
  });
}
