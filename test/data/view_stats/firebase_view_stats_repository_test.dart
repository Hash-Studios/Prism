// Firebase platform-interface packages are transitive, but these fakes need them.
// ignore_for_file: depend_on_referenced_packages

import 'package:Prism/core/view_stats/view_stats_repository.dart';
import 'package:Prism/data/view_stats/firebase_view_stats_repository.dart';
import 'package:cloud_functions_platform_interface/cloud_functions_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_firestore_client.dart';

class _FakeFunctions extends FirebaseFunctionsPlatform {
  _FakeFunctions(this.onCall) : super(null, 'asia-south1');

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

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    previous = FirebaseFunctionsPlatform.instance;
  });

  setUp(() {
    calls.clear();
    failure = null;
    FirebaseFunctionsPlatform.instance = _FakeFunctions((name, parameters) async {
      calls.add((name, parameters));
      final Object? error = failure;
      if (error != null) throw error;
      return <String, Object?>{'ok': true};
    });
    firestore = FakeFirestoreClient();
    repository = FirebaseViewStatsRepository(firestore);
  });

  tearDownAll(() => FirebaseFunctionsPlatform.instance = previous);

  group('recordWallpaperAction', () {
    test('calls the callable with the upper-case wall id and the action', () async {
      final result = await repository.recordWallpaperAction(' abc12 ', WallpaperAction.set);

      expect(result.isSuccess, isTrue);
      expect(calls.single.$1, 'recordWallpaperAction');
      expect(calls.single.$2, {'wallId': 'ABC12', 'action': 'set'});
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
