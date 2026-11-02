import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/features/wall_comments/data/wall_comments_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_firestore_client.dart';
import 'fake_wall_comments_repository.dart';

class _Client extends FakeFirestoreClient {
  FirestoreQuerySpec? spec;

  @override
  Future<List<T>> query<T>(FirestoreQuerySpec spec, T Function(Map<String, dynamic>, String) map) async {
    this.spec = spec;
    return <T>[];
  }
}

void main() {
  test('comment reads cannot fall back to a stale disk copy after moderation', () async {
    final _Client client = _Client();
    await WallCommentsRepository(client).fetchPage('wall');
    expect(client.spec!.cachePolicy, FirestoreCachePolicy.serverOnly);
  });

  test('paging does not read a potentially hidden or deleted cursor document', () async {
    final _Client client = _Client();
    await WallCommentsRepository(client).fetchPage('wall', after: commentFor('hidden'));
    expect(client.spec!.startAfterDocId, isNull);
    expect(client.spec!.startAfterFieldValues!.last, 'hidden');
  });
}
