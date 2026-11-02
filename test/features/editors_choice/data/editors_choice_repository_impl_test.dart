import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/features/editors_choice/data/editors_choice_repository_impl.dart';
import 'package:Prism/features/editors_choice/domain/editors_choice_repository.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_firestore_client.dart';
import '../../../support/fake_user_block_repository.dart';
import '../../../support/in_memory_local_store.dart';

Map<String, dynamic> _wall(
  String id, {
  List<String> collections = const <String>[],
  bool protected = true,
  bool withPickTime = true,
}) => <String, dynamic>{
  'id': id,
  'wallpaper_url': 'https://example.com/$id.jpg',
  'wallpaper_thumb': 'https://example.com/$id-thumb.jpg',
  'wallpaper_provider': 'Prism',
  'by': 'Ana',
  'creatorUid': 'creator-id',
  'review': true,
  'originalProtected': protected,
  'collections': collections,
  'is_streak_exclusive': false,
  'dropReserved': false,
  'dropWeek': null,
  'editorsChoiceAt': withPickTime ? '2026-10-30T10:00:00Z' : null,
};

void main() {
  late FakeFirestoreClient client;
  late FakeUserBlockRepository blocks;
  late SettingsLocalDataSource settings;
  late List<({String name, Map<String, Object?> data})> calls;
  Future<Object?> Function(String, Map<String, Object?>)? callerError;

  EditorsChoiceRepositoryImpl repository() => EditorsChoiceRepositoryImpl(
    client,
    blocks,
    settings,
    caller: (name, data) async {
      calls.add((name: name, data: data));
      final Future<Object?> Function(String, Map<String, Object?>)? error = callerError;
      if (error != null) return error(name, data);
      return <String, Object?>{'ok': true};
    },
  );

  setUp(() {
    client = FakeFirestoreClient();
    blocks = FakeUserBlockRepository.pending()..completeInitial(<String>{});
    settings = SettingsLocalDataSource(InMemoryLocalStore());
    calls = <({String name, Map<String, Object?> data})>[];
    callerError = null;
  });

  group('fetchPicks', () {
    test('drops ineligible picks and keeps the server order', () async {
      final Map<String, Map<String, dynamic>> walls = <String, Map<String, dynamic>>{
        'NEWEST': _wall('NEWEST'),
        'PREMIUM': _wall('PREMIUM', collections: <String>['space']),
        'UNPROTECTED': _wall('UNPROTECTED', protected: false),
        'NOT_PICKED': _wall('NOT_PICKED', withPickTime: false),
        'OLDEST': _wall('OLDEST'),
      };
      client.onQuery = (spec) => <FakeDocRow>[for (final String id in walls.keys) (id: id, data: walls[id]!)];

      final List<String> ids = (await repository().fetchPicks(limit: 30)).map((wall) => wall.id).toList();

      expect(ids, <String>['NEWEST', 'OLDEST']);
      final FirestoreQuerySpec spec = client.querySpecs.single;
      expect(spec.collection, FirebaseCollections.walls);
      expect(spec.limit, 30);
      expect(spec.filters.single, const FirestoreFilter(field: 'review', op: FirestoreFilterOp.isEqualTo, value: true));
      expect(spec.orderBy.single, const FirestoreOrderBy(field: 'editorsChoiceAt', descending: true));
    });
  });

  group('setPick', () {
    test('sends the wall id, the flag and a 32-character request id to setEditorsChoice', () async {
      await repository().setPick(wallDocId: 'wall-1', picked: true);

      expect(calls.single.name, 'setEditorsChoice');
      expect(calls.single.data['wallId'], 'wall-1');
      expect(calls.single.data['picked'], true);
      expect(calls.single.data['requestId'], isA<String>().having((id) => id.length, 'length', 32));
    });

    test('turns failed-precondition into EditorsChoiceNotEligible', () async {
      callerError = (_, _) async =>
          throw FirebaseFunctionsException(code: 'failed-precondition', message: 'not eligible');

      await expectLater(
        repository().setPick(wallDocId: 'wall-1', picked: true),
        throwsA(isA<EditorsChoiceNotEligible>()),
      );
    });

    test('rethrows other callable errors', () async {
      callerError = (_, _) async => throw FirebaseFunctionsException(code: 'permission-denied', message: 'no');

      await expectLater(
        repository().setPick(wallDocId: 'wall-1', picked: true),
        throwsA(isA<FirebaseFunctionsException>()),
      );
    });
  });
}
