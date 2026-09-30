import 'dart:convert';

import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/persistence/data_sources/feed_cache_local_data_source.dart';
import 'package:Prism/features/setups/data/repositories/setups_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_firestore_client.dart';
import '../../../../support/fake_user_block_repository.dart';

class _MemoryFeedCache extends Fake implements FeedCacheLocalDataSource {
  Object? payload;

  @override
  Future<void> write({
    required String source,
    required String scope,
    required Object? payload,
    required int ttlHours,
  }) async {
    this.payload = jsonDecode(jsonEncode(payload));
  }

  @override
  Future<FeedSnapshot?> read({required String source, required String scope}) async {
    final Object? stored = payload;
    return stored == null ? null : FeedSnapshot(payload: stored, cachedAtUtc: DateTime.now().toUtc(), ttlHours: 3);
  }
}

FakeDocRow _row(String docId, {String id = '', String email = 'creator@example.com', String name = 'BLOODLAND'}) => (
  id: docId,
  data: <String, dynamic>{'id': id, 'email': email, 'name': name, 'image': 'https://example.com/$docId.jpg'},
);

void main() {
  late FakeFirestoreClient client;
  late _MemoryFeedCache cache;
  late FakeUserBlockRepository blocks;
  late SetupsRepositoryImpl repository;

  setUp(() {
    client = FakeFirestoreClient();
    cache = _MemoryFeedCache();
    blocks = FakeUserBlockRepository.pending()..completeInitial(<String>{});
    repository = SetupsRepositoryImpl(client, cache, blocks);
  });

  group('fetchSetupByName', () {
    test('only asks for reviewed setups, which the rules allow', () async {
      await repository.fetchSetupByName('BLOODLAND');

      final filters = client.querySpecs.single.filters.map((f) => '${f.field} ${f.op.name} ${f.value}').toList();
      expect(filters, containsAll(<String>['name isEqualTo BLOODLAND', 'review isEqualTo true']));
    });

    test('maps the document and falls back to the document id when the id field is empty', () async {
      client.onQuery = (_) => <FakeDocRow>[_row('doc-1')];

      final result = await repository.fetchSetupByName('BLOODLAND');

      expect(result.data?.id, 'doc-1');
      expect(result.data?.firestoreDocumentId, 'doc-1');
      expect(result.data?.name, 'BLOODLAND');
    });

    test('returns no setup when the name is unknown', () async {
      final result = await repository.fetchSetupByName('MISSING');

      expect(result.isSuccess, isTrue);
      expect(result.data, isNull);
    });

    test('reports a network failure instead of a missing setup', () async {
      client.queryError = StateError('offline');

      final result = await repository.fetchSetupByName('BLOODLAND');

      expect(result.failure, isA<ServerFailure>());
    });
  });

  group('fetchSetups', () {
    test('hides setups of blocked creators', () async {
      blocks.completeInitial(<String>{'blocked@example.com'});
      client.onQuery = (_) => <FakeDocRow>[_row('1', email: 'blocked@example.com'), _row('2')];

      final result = await repository.fetchSetups(refresh: true);

      expect(result.data?.items.map((s) => s.id), <String>['2']);
    });

    test('falls back to the cached page when the query fails', () async {
      client.onQuery = (_) => <FakeDocRow>[_row('1'), _row('2')];
      await repository.fetchSetups(refresh: true);
      client.queryError = StateError('offline');

      final result = await repository.fetchSetups(refresh: true);

      expect(result.data?.items.map((s) => s.id), <String>['1', '2']);
    });

    test('fails when the query fails and nothing is cached', () async {
      client.queryError = StateError('offline');

      final result = await repository.fetchSetups(refresh: true);

      expect(result.failure, isA<ServerFailure>());
    });
  });
}
