// Firebase platform-interface packages are transitive, but these fakes need them.
// ignore_for_file: depend_on_referenced_packages

import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/view_stats/view_stats_repository.dart';
import 'package:Prism/data/view_stats/firebase_view_stats_repository.dart';
import 'package:Prism/features/daily_flow/daily_moment_config.dart';
import 'package:cloud_functions_platform_interface/cloud_functions_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_firestore_client.dart';

class _FakeFunctions extends FirebaseFunctionsPlatform {
  _FakeFunctions(this.onCall) : super(null, 'us-central1');

  final Future<dynamic> Function(String name, dynamic parameters) onCall;

  @override
  FirebaseFunctionsPlatform delegateFor({FirebaseApp? app, required String region}) => this;

  @override
  HttpsCallablePlatform httpsCallable(String? origin, String name, HttpsCallableOptions options) =>
      _FakeCallable(this, origin, name, options);
}

class _FakeCallable extends HttpsCallablePlatform {
  _FakeCallable(_FakeFunctions functions, String? origin, String name, HttpsCallableOptions options)
    : super(functions, origin, name, options, null);

  @override
  Future<dynamic> call([dynamic parameters]) => (functions as _FakeFunctions).onCall(name!, parameters);
}

class _ThrowingFirestore extends FakeFirestoreClient {
  @override
  Future<T?> getById<T>(
    String collection,
    String id,
    T Function(Map<String, dynamic> data, String docId) map, {
    required String sourceTag,
    bool preferCacheFirst = false,
  }) async => throw StateError('permission-denied');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirestoreClient firestore;
  late FirebaseViewStatsRepository repository;
  late FirebaseFunctionsPlatform previous;
  final List<(String, dynamic)> calls = <(String, dynamic)>[];
  Object? failure;
  Future<dynamic> Function(String, dynamic)? actionReply;
  Map<String, Object?> response = <String, Object?>{'ok': true};

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    previous = FirebaseFunctionsPlatform.instance;
  });

  setUp(() {
    DailyMomentConfig.enabledOverride = true;
    calls.clear();
    failure = null;
    actionReply = null;
    response = <String, Object?>{'ok': true};
    FirebaseFunctionsPlatform.instance = _FakeFunctions((name, parameters) async {
      calls.add((name, parameters));
      if (actionReply case final reply?) return reply(name, parameters);
      final Object? error = failure;
      if (error != null) throw error;
      return response;
    });
    firestore = FakeFirestoreClient();
    repository = FirebaseViewStatsRepository(firestore);
  });

  tearDown(() => DailyMomentConfig.enabledOverride = null);

  tearDownAll(() => FirebaseFunctionsPlatform.instance = previous);

  group('recordWallpaperView', () {
    test('invalid ids never call the backend and a server rejection can be retried', () async {
      expect((await repository.recordWallpaperView(' ')).isFailure, isTrue);
      expect((await repository.fetchWallpaperSetCount(' ')).isFailure, isTrue);
      expect(calls, isEmpty);
      failure = FirebaseFunctionsException(code: 'permission-denied', message: 'Denied');
      expect((await repository.recordWallpaperView('abc')).failure!.message, contains('Denied'));
      failure = null;
      response = <String, Object?>{'views': 8};
      expect((await repository.recordWallpaperView('abc')).data, '8');
      for (final entry in <(Object, String)>[(4.9, '4'), ('12k', '12k'), (false, '0')]) {
        response = <String, Object?>{'views': entry.$1};
        expect((await repository.recordWallpaperView('abc-${entry.$2}')).data, entry.$2);
      }
      expect(calls, hasLength(5));
    });

    test('a different signed-in account records the same wall again', () async {
      final String previousId = app_state.prismUser.id;
      final bool previousLoggedIn = app_state.prismUser.loggedIn;
      addTearDown(() {
        app_state.prismUser
          ..id = previousId
          ..loggedIn = previousLoggedIn;
      });
      app_state.prismUser
        ..loggedIn = true
        ..id = 'user-a';
      response = <String, Object?>{'views': 42};
      await repository.recordWallpaperView('abc');
      app_state.prismUser.id = 'user-b';
      response = <String, Object?>{'views': 43};

      final result = await repository.recordWallpaperView('abc');

      expect(result.data, '43');
      expect(calls, hasLength(2));
    });

    test('counts a wall once per session and returns the known count for repeats', () async {
      response = <String, Object?>{'views': 42};

      final first = await repository.recordWallpaperView(' abc12 ');
      final repeat = await repository.recordWallpaperView('ABC12');
      final other = await repository.recordWallpaperView('xyz');

      expect(first.data, '42');
      expect(repeat.data, '42');
      expect(other.data, '42');
      expect(calls.map((c) => (c.$2 as Map)['wallId']), ['ABC12', 'XYZ']);
    });

    test('overlapping calls for one wall send one request and share the count', () async {
      response = <String, Object?>{'views': 5};

      final results = await Future.wait([repository.recordWallpaperView('abc'), repository.recordWallpaperView('abc')]);

      expect(results.map((r) => r.data), ['5', '5']);
      expect(calls, hasLength(1));
    });

    test('a failed record is retried on the next open', () async {
      failure = StateError('offline');
      final failed = await repository.recordWallpaperView('abc');
      failure = null;
      response = <String, Object?>{'views': 7};
      final retried = await repository.recordWallpaperView('abc');

      expect(failed.isFailure, isTrue);
      expect(retried.data, '7');
      expect(calls, hasLength(2));
    });
  });

  group('recordWallpaperAction', () {
    test('flag off keeps the legacy callable payload and ignores awards', () async {
      DailyMomentConfig.enabledOverride = false;
      response = <String, Object?>{'questCoins': 9, 'questReceiptComplete': true};
      final result = await repository.recordWallpaperAction('abc', WallpaperAction.set);

      expect(calls.single.$2, <String, Object?>{'wallId': 'ABC', 'action': 'set'});
      expect(result.data?.coins, 0);
      expect(result.data?.receiptId, isNull);
    });

    test('calls the callable with the upper-case wall id and the action', () async {
      final result = await repository.recordWallpaperAction(' abc12 ', WallpaperAction.set);

      expect(result.isSuccess, isTrue);
      expect(calls.single.$1, 'recordWallpaperAction');
      expect(calls.single.$2, containsPair('wallId', 'ABC12'));
      expect(calls.single.$2, containsPair('action', 'set'));
      expect((calls.single.$2 as Map)['requestId'], matches(RegExp(r'^[A-Za-z0-9_-]{8,64}$')));
    });

    test('retries an incomplete receipt with the same request id and reads the actual award', () async {
      actionReply = (name, parameters) async {
        return <String, Object?>{
          'counted': calls.length == 1,
          'questReceiptComplete': calls.length > 1,
          'questReceiptId': (parameters as Map)['requestId'],
          'questCoins': 9,
          'questAwards': <Object?>[
            <String, Object?>{'id': 'set', 'coins': 9, 'xp': 1},
          ],
        };
      };
      final result = await repository.recordWallpaperAction('abc', WallpaperAction.set);
      expect(calls, hasLength(2));
      expect(calls.first.$2, calls.last.$2);
      expect(result.data?.coins, 9);
    });

    test('an account change cancels an incomplete action instead of retrying for the new account', () async {
      final owner = app_state.prismUser.id;
      addTearDown(() => app_state.prismUser.id = owner);
      actionReply = (_, _) async {
        app_state.prismUser.id = 'another-account';
        return <String, Object?>{'questReceiptComplete': false};
      };
      final result = await repository.recordWallpaperAction('abc', WallpaperAction.set);
      expect(calls, hasLength(1));
      expect(result.isFailure, isTrue);
    });

    test('a receipt from before sign-out is rejected after the same account signs back in', () async {
      actionReply = (_, parameters) async {
        CoinsService.instance.resetSession();
        return <String, Object?>{
          'questReceiptComplete': true,
          'questReceiptId': (parameters as Map)['requestId'],
          'questCoins': 9,
          'questAwards': <Object?>[
            <String, Object?>{'id': 'set', 'coins': 9},
          ],
        };
      };
      final result = await repository.recordWallpaperAction('abc', WallpaperAction.set);
      expect(result.isFailure, isTrue);
      expect(result.failure?.message, contains('Account changed'));
      expect(calls, hasLength(1));
    });

    test('legacy responses never report an earned amount', () async {
      response = <String, Object?>{'counted': true, 'questCoins': 20};
      final result = await repository.recordWallpaperAction('abc', WallpaperAction.set);
      expect(result.data?.counted, isTrue);
      expect(result.data?.coins, 0);
      expect(result.data?.receiptId, isNull);
    });

    test('sends download and share as their own actions', () async {
      await repository.recordWallpaperAction('abc', WallpaperAction.download);
      await repository.recordWallpaperAction('abc', WallpaperAction.share);

      expect(calls.map((c) => (c.$2 as Map)['action']), ['download', 'share']);
    });

    test('an old backend without the callable counts as success', () async {
      for (final String code in <String>['not-found', 'unimplemented']) {
        failure = FirebaseFunctionsException(code: code, message: 'missing');
        expect((await repository.recordWallpaperAction('abc', WallpaperAction.set)).isSuccess, isTrue, reason: code);
      }
    });

    test('other server errors come back as a failure, never thrown', () async {
      failure = FirebaseFunctionsException(code: 'unauthenticated', message: 'Sign in');
      final result = await repository.recordWallpaperAction('abc', WallpaperAction.set);

      expect(result.isFailure, isTrue);
      expect(result.failure?.message, contains('Sign in'));
    });

    test('a network error comes back as a failure, never thrown', () async {
      failure = StateError('offline');

      expect((await repository.recordWallpaperAction('abc', WallpaperAction.set)).isFailure, isTrue);
    });

    test('an empty id is rejected without a call', () async {
      expect((await repository.recordWallpaperAction('  ', WallpaperAction.set)).isFailure, isTrue);
      expect(calls, isEmpty);
    });
  });

  group('fetchWallpaperSetCount', () {
    test('reads sets from wallpaper_stats by the upper-case id', () async {
      firestore.docs['wallpaper_stats'] = <String, Map<String, dynamic>>{
        'ABC12': <String, dynamic>{'views': 90, 'sets': 17},
      };

      final result = await repository.fetchWallpaperSetCount('abc12');

      expect(result.isSuccess, isTrue);
      expect(result.data, 17);
    });

    test('is null when the wall has no stats or no sets field', () async {
      firestore.docs['wallpaper_stats'] = <String, Map<String, dynamic>>{
        'NOSETS': <String, dynamic>{'views': 3},
      };

      expect((await repository.fetchWallpaperSetCount('missing')).data, isNull);
      expect((await repository.fetchWallpaperSetCount('nosets')).data, isNull);
    });

    test('a Firestore error is a failure, never thrown', () async {
      final result = await FirebaseViewStatsRepository(_ThrowingFirestore()).fetchWallpaperSetCount('abc');

      expect(result.isFailure, isTrue);
    });
  });
}
