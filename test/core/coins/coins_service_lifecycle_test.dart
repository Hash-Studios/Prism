import 'dart:async';

import 'package:Prism/core/coins/coin_action.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_quality_tier.dart';
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
    service.earnFlagsNotifier.value = CoinEarnFlags.empty;
  });
  tearDown(() async {
    service.consumeLastClaim();
    service.earnFlagsNotifier.value = CoinEarnFlags.empty;
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

  test('server balance sync repairs a stale notifier without emitting a coin delta', () {
    app_state.prismUser.coins = 100;
    service.balanceNotifier.value = 40;
    service.deltaNotifier.value = 0;

    service.applyServerBalance(100);

    expect(app_state.prismUser.coins, 100);
    expect(service.balanceNotifier.value, 100);
    expect(service.deltaNotifier.value, 0);
  });

  test('claim response is rejected when the captured user object changes account in place', () async {
    final response = Completer<dynamic>();
    backend.onCall = (_, _) => response.future;
    final user = app_state.prismUser;
    final claim = service.claimDailyLoginAndStreakIfEligible();
    user.id = '${backend.userId}-other';
    user.coins = 9;
    response.complete(CoinsTestBackend.claimPayload);
    await claim;
    expect(user.coins, 9);
    expect(service.lastClaimNotifier.value, isNull);
  });

  test('claim response survives a profile replacement for the same account', () async {
    final response = Completer<dynamic>();
    backend.onCall = (_, _) => response.future;
    final claim = service.claimDailyLoginAndStreakIfEligible();
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = backend.userId
      ..loggedIn = true;
    response.complete(CoinsTestBackend.claimPayload);
    await claim;
    expect(service.pendingClaimForCurrentUser, isNotNull);
  });

  test('claim failure does not refresh streak after the account changes in place', () async {
    final firestore = CoinsTestFirestore()
      ..userData = <String, dynamic>{
        'coinState': <String, Object>{'streakDay': 5, 'streakCount': 5, 'lastDailyClaimDate': '2026-09-30'},
      };
    getIt.registerSingleton<FirestoreClient>(firestore);
    backend.onCall = (_, _) async => throw FirebaseFunctionsException(code: 'unavailable', message: 'offline');
    final user = app_state.prismUser;
    final claim = service.claimDailyLoginAndStreakIfEligible();
    user.id = '${backend.userId}-other';
    user.coins = 9;
    await claim;
    expect(service.streakNotifier.value.count, 0);
    expect(user.coins, 9);
    expect(firestore.getByIdCalls, 0);
  });

  test('pending claim getter clears claims for an empty guest id', () async {
    await service.claimDailyLoginAndStreakIfEligible();
    expect(service.pendingClaimForCurrentUser, isNotNull);
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = '${backend.userId}-other'
      ..loggedIn = true;
    expect(service.pendingClaimForCurrentUser, isNull);
    app_state.prismUser = app_constants.createGuestPrismUser()..loggedIn = true;
    expect(service.pendingClaimForCurrentUser, isNull);
  });

  test('claim sheet dedupe is retained per user and day when accounts alternate', () async {
    backend.onCall = (_, _) async => <String, Object>{
      'claimed': true,
      'streakDay': 3,
      'dailyReward': 8,
      'totalReward': 8,
      'newBalance': 108,
      'todayLocalKey': '2026-09-30',
    };
    await service.claimDailyLoginAndStreakIfEligible();
    service.consumeLastClaim();
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = '${backend.userId}-other'
      ..loggedIn = true;
    await service.claimDailyLoginAndStreakIfEligible();
    service.consumeLastClaim();
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = backend.userId
      ..loggedIn = true;
    await service.claimDailyLoginAndStreakIfEligible();
    expect(service.lastClaimNotifier.value, isNull);
  });

  test('pending claim survives sign-out and sign-in to the same account', () async {
    await service.claimDailyLoginAndStreakIfEligible();
    expect(service.lastClaimNotifier.value, isNotNull);
    app_state.prismUser = app_constants.createGuestPrismUser();
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = backend.userId
      ..loggedIn = true;
    expect(service.pendingClaimForCurrentUser, isNotNull);
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
      ..id = '${backend.userId}-other'
      ..loggedIn = true
      ..coins = 9;
    response.complete(<String, Object>{'success': true, 'currentBalance': 50, 'delta': -50, 'streakFreezes': 1});
    await purchase;
    expect(app_state.prismUser.coins, 9);
    expect(service.streakNotifier.value.freezes, 0);
  });

  test('freeze response is rejected when the captured user object changes account in place', () async {
    final response = Completer<dynamic>();
    backend.onCall = (_, _) => response.future;
    final user = app_state.prismUser;
    final purchase = service.buyStreakFreeze();
    await Future<void>.delayed(Duration.zero);
    user.id = '${backend.userId}-other';
    user.coins = 9;
    response.complete(<String, Object>{'success': true, 'currentBalance': 50, 'delta': -50, 'streakFreezes': 1});
    await purchase;
    expect(user.coins, 9);
    expect(service.streakNotifier.value.freezes, 0);
  });

  test('freeze response survives a profile replacement for the same account', () async {
    final response = Completer<dynamic>();
    backend.onCall = (_, _) => response.future;
    final purchase = service.buyStreakFreeze();
    await Future<void>.delayed(Duration.zero);
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = backend.userId
      ..loggedIn = true
      ..coins = 100;
    response.complete(<String, Object>{'success': true, 'currentBalance': 50, 'delta': -50, 'streakFreezes': 1});
    await purchase;
    expect(app_state.prismUser.coins, 50);
    expect(service.streakNotifier.value.freezes, 1);
  });

  test('freeze request persisted during an account switch is not sent', () async {
    var calls = 0;
    backend.onCall = (_, _) async {
      calls++;
      return <String, Object>{'success': true, 'currentBalance': 50, 'delta': -50, 'streakFreezes': 1};
    };
    final user = app_state.prismUser;
    final purchase = service.buyStreakFreeze();
    user.id = '${backend.userId}-other';
    user.coins = 9;
    final result = await purchase;
    expect(result.message, 'session_changed');
    expect(calls, 0);
    expect(app_state.prismUser.coins, 9);
  });

  test('freeze pending request is not replayed for a different account', () async {
    final settings = getIt<SettingsLocalDataSource>();
    final requestIds = <String>[];
    backend.onCall = (_, parameters) async {
      requestIds.add(parameters['requestId'] as String);
      if (requestIds.length == 1) {
        throw FirebaseFunctionsException(code: 'unavailable', message: 'lost reply');
      }
      return <String, Object>{'success': true, 'currentBalance': 50, 'delta': -50, 'streakFreezes': 1};
    };
    await service.buyStreakFreeze();
    expect(settings.get<String>('pendingStreakFreezeRequest.${backend.userId}'), requestIds.single);
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = '${backend.userId}-other'
      ..loggedIn = true
      ..coins = 9;
    await service.buyStreakFreeze();
    expect(requestIds, hasLength(2));
    expect(requestIds[1], isNot(requestIds[0]));
    expect(settings.get<String>('pendingStreakFreezeRequest.${backend.userId}'), requestIds[0]);
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
    expect(settings.get<String>('pendingStreakFreezeRequest.${backend.userId}'), firstRequest);
    app_state.prismUser.id = '${backend.userId}-other';
    backend.onCall = (_, _) async => throw FirebaseFunctionsException(code: 'not-found', message: 'missing');
    await service.buyStreakFreeze();
    app_state.prismUser.id = backend.userId;
    backend.onCall = (_, parameters) async {
      expect(parameters['requestId'], firstRequest);
      return <String, Object>{'success': true, 'changed': false, 'currentBalance': 50, 'delta': 0, 'streakFreezes': 1};
    };
    await service.buyStreakFreeze();
    expect(settings.get<String>('pendingStreakFreezeRequest.${backend.userId}', defaultValue: ''), isEmpty);
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
        ..id = '${backend.userId}-source'
        ..loggedIn = true
        ..coins = 100;
      final pending = refresh();
      app_state.prismUser = app_constants.createGuestPrismUser()
        ..id = '${backend.userId}-other'
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

  test('delayed refreshes reject an account change made on the captured user object', () async {
    final firestore = CoinsTestFirestore();
    getIt.registerSingleton<FirestoreClient>(firestore);
    for (final refresh in <Future<Object?> Function()>[
      service.bootstrapForCurrentUser,
      service.refreshBalance,
      service.refreshStreakStatus,
    ]) {
      final response = Completer<Map<String, dynamic>>();
      firestore.userResponse = response.future;
      final user = app_state.prismUser;
      user.id = backend.userId;
      user.loggedIn = true;
      user.coins = 100;
      service.streakNotifier.value = StreakStatus.empty;
      service.earnFlagsNotifier.value = CoinEarnFlags.empty;
      final pending = refresh();
      user.id = '${backend.userId}-other';
      user.coins = 9;
      response.complete(<String, dynamic>{
        'coins': 500,
        'coinState': <String, Object>{'streakDay': 5, 'profileCompletionRewarded': true},
      });
      await pending;
      expect(user.coins, 9);
      expect(service.earnFlagsNotifier.value, CoinEarnFlags.empty);
      expect(service.streakNotifier.value.count, 0);
    }
  });

  test('all profile refreshes survive replacement by the same account', () async {
    final firestore = CoinsTestFirestore();
    getIt.registerSingleton<FirestoreClient>(firestore);
    final now = DateTime.now().toUtc();
    final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    var refreshIndex = 0;
    for (final refresh in <Future<Object?> Function()>[
      service.bootstrapForCurrentUser,
      service.refreshBalance,
      service.refreshStreakStatus,
    ]) {
      final response = Completer<Map<String, dynamic>>();
      firestore.userResponse = response.future;
      app_state.prismUser = app_constants.createGuestPrismUser()
        ..id = backend.userId
        ..loggedIn = true
        ..coins = 100;
      service.streakNotifier.value = StreakStatus.empty;
      final pending = refresh();
      app_state.prismUser = app_constants.createGuestPrismUser()
        ..id = backend.userId
        ..loggedIn = true
        ..coins = 100;
      response.complete(<String, dynamic>{
        'coins': 500,
        'coinState': <String, Object>{
          'streakDay': 5,
          'streakCount': 5,
          'lastDailyClaimDate': today,
          'streakTimezoneOffsetMinutes': 0,
          'firstWallpaperUploadRewarded': true,
        },
      });
      await pending;
      expect(app_state.prismUser.coins, refreshIndex < 2 ? 500 : 100);
      expect(service.streakNotifier.value.count, 5);
      expect(service.earnFlagsNotifier.value.firstUploadRewarded, isTrue);
      refreshIndex++;
    }
  });

  test('empty guest ids block every account-scoped coin request', () async {
    final firestore = CoinsTestFirestore();
    getIt.registerSingleton<FirestoreClient>(firestore);
    var callableCount = 0;
    backend.onCall = (_, _) async {
      callableCount++;
      return <String, Object>{'success': true, 'changed': true, 'currentBalance': 500, 'delta': 400};
    };
    app_state.prismUser = app_constants.createGuestPrismUser()..loggedIn = true;
    final calls = <Future<dynamic> Function()>[
      service.bootstrapForCurrentUser,
      service.refreshBalance,
      service.refreshStreakStatus,
      service.claimDailyLoginAndStreakIfEligible,
      service.buyStreakFreeze,
      () => service.award(CoinEarnAction.dailyLogin),
      () => service.spend(CoinSpendAction.wallpaperDownload),
      service.maybeAwardFirstWallpaperUpload,
    ];
    for (final call in calls) {
      await call();
    }
    expect(firestore.getByIdCalls, 0);
    expect(callableCount, 0);
    expect(app_state.prismUser.coins, 0);
  });

  test('award response is rejected after sign-out or account switch', () async {
    for (final nextUser in <bool>[false, true]) {
      final response = Completer<dynamic>();
      backend.onCall = (_, _) => response.future;
      app_state.prismUser = app_constants.createGuestPrismUser()
        ..id = backend.userId
        ..loggedIn = true
        ..coins = 100;
      final award = service.award(CoinEarnAction.dailyLogin);
      if (nextUser) {
        app_state.prismUser = app_constants.createGuestPrismUser()
          ..id = '${backend.userId}-other'
          ..loggedIn = true
          ..coins = 9;
      } else {
        app_state.prismUser = app_constants.createGuestPrismUser();
      }
      response.complete(<String, Object>{
        'success': true,
        'changed': true,
        'previousBalance': 100,
        'currentBalance': 500,
        'delta': 400,
      });
      await award;
      expect(app_state.prismUser.coins, nextUser ? 9 : 0);
    }
  });

  test('award response survives a profile replacement for the same account', () async {
    final response = Completer<dynamic>();
    backend.onCall = (_, _) => response.future;
    final award = service.award(CoinEarnAction.dailyLogin);
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = backend.userId
      ..loggedIn = true
      ..coins = 100;
    response.complete(<String, Object>{
      'success': true,
      'changed': true,
      'previousBalance': 100,
      'currentBalance': 108,
      'delta': 8,
    });
    await award;
    expect(app_state.prismUser.coins, 108);
  });

  test('fixed award response cannot set earn flags after an account switch', () async {
    final response = Completer<dynamic>();
    backend.onCall = (_, _) => response.future;
    final user = app_state.prismUser;
    final award = service.maybeAwardFirstWallpaperUpload();
    user.id = '${backend.userId}-other';
    user.coins = 9;
    response.complete(<String, Object>{
      'success': true,
      'changed': true,
      'previousBalance': 100,
      'currentBalance': 500,
      'delta': 400,
    });
    await award;
    expect(user.coins, 9);
    expect(service.earnFlagsNotifier.value.firstUploadRewarded, isFalse);
  });

  test('fresh backend installs use distinct ids for claim dedupe isolation', () async {
    final firstUserId = backend.userId;
    await service.claimDailyLoginAndStreakIfEligible();
    service.consumeLastClaim();
    await backend.install();
    expect(backend.userId, isNot(firstUserId));
    await service.claimDailyLoginAndStreakIfEligible();
    expect(service.lastClaimNotifier.value, isNotNull);
  });

  test('spend and refund responses are rejected after an account switch', () async {
    for (final mutate in <Future<dynamic> Function()>[
      () => service.spend(CoinSpendAction.wallpaperDownload),
      () => service.reserveForAiGeneration(qualityTier: AiQualityTier.fast),
      () => service.refundSpend(
        CoinSpendAction.wallpaperDownload,
        sourceTag: 'test.refund',
        transactionId: 'prior-transaction',
      ),
    ]) {
      final response = Completer<dynamic>();
      backend.onCall = (_, _) => response.future;
      app_state.prismUser = app_constants.createGuestPrismUser()
        ..id = backend.userId
        ..loggedIn = true
        ..coins = 100;
      final mutation = mutate();
      app_state.prismUser = app_constants.createGuestPrismUser()
        ..id = '${backend.userId}-other'
        ..loggedIn = true
        ..coins = 9;
      response.complete(<String, Object>{
        'success': true,
        'changed': true,
        'previousBalance': 100,
        'currentBalance': 500,
        'delta': 400,
      });
      await mutation;
      expect(app_state.prismUser.coins, 9);
    }
  });

  test('premium preview unlock stops if the account changes during its access check', () async {
    final firestore = CoinsTestFirestore();
    getIt.registerSingleton<FirestoreClient>(firestore);
    final response = Completer<Map<String, dynamic>>();
    firestore.userResponse = response.future;
    var callableCount = 0;
    backend.onCall = (_, _) async {
      callableCount++;
      return <String, Object>{'success': true, 'changed': false, 'currentBalance': 500, 'delta': 0};
    };
    final unlock = service.unlockPremiumPreview24hForCollection(collectionKey: 'featured');
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = '${backend.userId}-other'
      ..loggedIn = true
      ..coins = 9;
    response.complete(<String, dynamic>{'coins': 100, 'coinState': <String, Object>{}});
    await unlock;
    expect(callableCount, 0);
    expect(app_state.prismUser.coins, 9);
  });

  test('premium preview unlock continues after a same-account profile replacement', () async {
    final firestore = CoinsTestFirestore();
    getIt.registerSingleton<FirestoreClient>(firestore);
    final response = Completer<Map<String, dynamic>>();
    firestore.userResponse = response.future;
    var callableCount = 0;
    backend.onCall = (_, _) async {
      callableCount++;
      return <String, Object>{'success': false, 'changed': false, 'currentBalance': 100, 'delta': 0};
    };
    final unlock = service.unlockPremiumPreview24hForCollection(collectionKey: 'featured');
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = backend.userId
      ..loggedIn = true
      ..coins = 100;
    response.complete(<String, dynamic>{'coins': 100, 'coinState': <String, Object>{}});
    await unlock;
    expect(callableCount, 1);
    expect(app_state.prismUser.coins, 100);
  });

  test('a profile reload for the same account keeps the refresh', () async {
    final firestore = CoinsTestFirestore();
    getIt.registerSingleton<FirestoreClient>(firestore);
    final response = Completer<Map<String, dynamic>>();
    firestore.userResponse = response.future;
    final pending = service.bootstrapForCurrentUser();
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = backend.userId
      ..loggedIn = true
      ..coins = 100;
    response.complete(<String, dynamic>{
      'coins': 500,
      'coinState': <String, Object>{'streakDay': 5, 'firstWallpaperUploadRewarded': true},
    });
    await pending;
    expect(service.earnFlagsNotifier.value.firstUploadRewarded, isTrue);
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
    expect(getIt<SettingsLocalDataSource>().get<String>('pendingStreakFreezeRequest.${backend.userId}'), requestIds[2]);
  });
}
