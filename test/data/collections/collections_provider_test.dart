import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/data/collections/provider/collections_without_provider.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_firestore_client.dart';
import '../../support/fake_user_block_repository.dart';

Map<String, dynamic> _wall(String id) => <String, dynamic>{'id': id, 'email': '$id@example.com'};

void main() {
  late FakeFirestoreClient firestore;

  setUp(() {
    collections = <Map<String, dynamic>>[];
    anyCollectionWalls = <Map<String, dynamic>>[];
    firestore = FakeFirestoreClient();
    getIt.registerSingleton<FirestoreClient>(firestore);
    getIt.registerSingleton<UserBlockRepository>(FakeUserBlockRepository.pending()..completeInitial(<String>{}));
  });

  tearDown(() async {
    collections = <Map<String, dynamic>>[];
    anyCollectionWalls = <Map<String, dynamic>>[];
    await getIt.reset();
  });

  group('getCollections', () {
    test('replaces the list once the query succeeds', () async {
      firestore.onQuery = (_) => <FakeDocRow>[
        (id: 'c1', data: <String, dynamic>{'name': 'space'}),
      ];

      await getCollections();

      expect(collections.map((row) => row['name']), <String>['space']);
    });

    test('keeps the list on screen when the query throws', () async {
      collections = <Map<String, dynamic>>[
        <String, dynamic>{'name': 'old'},
      ];
      firestore.queryError = StateError('permission-denied');

      await expectLater(getCollections(), throwsA(isA<StateError>()));

      expect(collections.map((row) => row['name']), <String>['old']);
    });
  });

  group('refreshCollectionWithName', () {
    Future<void> openCollection() async {
      firestore.onQuery = (_) => <FakeDocRow>[(id: 'd1', data: _wall('one'))];
      await getCollectionWithName('space');
      expect(anyCollectionWalls.map((wall) => wall['id']), <String>['one']);
    }

    test('swaps in the fresh walls', () async {
      await openCollection();
      firestore.onQuery = (_) => <FakeDocRow>[(id: 'd2', data: _wall('two'))];

      await refreshCollectionWithName();

      expect(anyCollectionWalls.map((wall) => wall['id']), <String>['two']);
    });

    test('keeps the walls on screen when the reload fails', () async {
      await openCollection();
      firestore.queryError = StateError('offline');

      await expectLater(refreshCollectionWithName(), throwsA(isA<StateError>()));

      expect(anyCollectionWalls.map((wall) => wall['id']), <String>['one']);
    });
  });
}
