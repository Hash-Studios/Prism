import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_error.dart';
import 'package:Prism/features/wallpaper_upload/data/repositories/wall_metadata_repository.dart';
import 'package:Prism/features/wallpaper_upload/domain/entities/wall_metadata.dart';
import 'package:cloud_functions/cloud_functions.dart' as cf;
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_firestore_client.dart';

class _Client extends FakeFirestoreClient {
  _Client(this.wall);

  Map<String, dynamic>? wall;
  final List<Map<String, dynamic>> patches = [];
  Future<void> Function()? beforeRead;
  bool wrapTransactionErrors = false;

  @override
  Future<T?> getById<T>(
    String collection,
    String id,
    T Function(Map<String, dynamic>, String) map, {
    required String sourceTag,
    bool preferCacheFirst = false,
  }) async => wall == null ? null : map(wall!, id);

  @override
  Future<T> runTransaction<T>(
    Future<T> Function(FirestoreTransaction) action, {
    required String sourceTag,
    required String collection,
    String? docId,
  }) async {
    expect(sourceTag, 'wall_metadata.update_pending');
    final transaction = _Transaction(this);
    try {
      final T result = await action(transaction);
      patches.addAll(transaction.patches);
      return result;
    } catch (error) {
      if (wrapTransactionErrors) throw mapFirestoreError(error);
      rethrow;
    }
  }
}

class _Transaction implements FirestoreTransaction {
  _Transaction(this.client);

  final _Client client;
  final List<Map<String, dynamic>> patches = [];

  @override
  Future<Map<String, dynamic>?> getDoc(String collection, String id) async {
    await client.beforeRead?.call();
    return client.wall;
  }

  @override
  void updateDoc(String collection, String id, Map<String, dynamic> data) => patches.add(data);

  @override
  void setDoc(String collection, String id, Map<String, dynamic> data, {bool merge = false}) =>
      fail('Metadata must never replace or recreate a document');

  @override
  void deleteDoc(String collection, String id) => fail('Metadata must never delete a document');
}

void main() {
  const owner = (uid: 'creator', email: 'creator@example.com');
  const next = PendingWallMetadata(
    text: WallTextMetadata(title: 'Rain', description: 'A quiet evening', tags: ['rain']),
    category: 'Nature',
  );
  late _Client client;
  late WallMetadataRepositoryImpl repository;
  late List<String> calls;
  late List<Map<String, Object?>> envelopes;
  late Object? response;
  late WallMetadataOwner activeOwner;
  late int cacheInvalidations;

  setUp(() {
    client = _Client(<String, dynamic>{
      'review': false,
      'creatorUid': owner.uid,
      'email': owner.email,
      'title': 'Old',
      'desc': '',
      'tags': <String>[],
      'category': 'General',
      'coins': 500,
      'originalProtected': true,
    });
    calls = [];
    envelopes = [];
    activeOwner = owner;
    cacheInvalidations = 0;
    response = <String, Object?>{'status': 'approved', 'revision': 'server-revision', 'metadata': next.text.toMap()};
    repository = WallMetadataRepositoryImpl(
      client,
      owner: () => activeOwner,
      invalidateCaches: () async => cacheInvalidations++,
      caller: (name, data) async {
        calls.add(name);
        envelopes.add(data);
        return response;
      },
    );
  });

  Matcher failure(WallMetadataFailure value) => isA<WallMetadataException>().having((e) => e.failure, 'failure', value);

  test('pending compare-and-set writes exactly four metadata fields and invalidates caches', () async {
    final expected = await repository.load('wall_1.jpg', approved: false);
    final saved = await repository.updatePending('wall_1.jpg', next, expected: expected);

    expect(client.patches.single, next.toMap());
    expect(client.patches.single.keys.toSet(), {'title', 'desc', 'tags', 'category'});
    expect(client.wall!['coins'], 500);
    expect(client.wall!['review'], false);
    expect(saved.metadata, next);
    expect(cacheInvalidations, 1);
    expect(calls, isEmpty);
  });

  test('pending save refuses concurrent metadata edits, preserving the other edit', () async {
    final expected = await repository.load('doc', approved: false);
    client.wall!['desc'] = 'Changed on another device';
    await expectLater(
      repository.updatePending('doc', next, expected: expected),
      throwsA(failure(WallMetadataFailure.conflict)),
    );
    expect(client.patches, isEmpty);
  });

  test('absent versus empty metadata also conflicts', () async {
    client.wall!.remove('desc');
    final expected = await repository.load('doc', approved: false);
    client.wall!['desc'] = '';
    await expectLater(
      repository.updatePending('doc', next, expected: expected),
      throwsA(failure(WallMetadataFailure.conflict)),
    );
  });

  test('tracked Firestore wrapping preserves pending conflict and status guards', () async {
    client.wrapTransactionErrors = true;
    final expected = await repository.load('doc', approved: false);
    client.wall!['title'] = 'Newer title';
    await expectLater(
      repository.updatePending('doc', next, expected: expected),
      throwsA(failure(WallMetadataFailure.conflict)),
    );
    client.wall!['review'] = true;
    await expectLater(
      repository.updatePending('doc', next, expected: expected),
      throwsA(failure(WallMetadataFailure.statusChanged)),
    );
    expect(client.patches, isEmpty);
  });

  test('approval between load and save fails without invoking the approved API', () async {
    final expected = await repository.load('doc', approved: false);
    client.wall!['review'] = true;
    await expectLater(
      repository.updatePending('doc', next, expected: expected),
      throwsA(failure(WallMetadataFailure.statusChanged)),
    );
    expect(client.patches, isEmpty);
    expect(calls, isEmpty);
  });

  test('rejection or withdrawal cannot recreate a wall', () async {
    final expected = await repository.load('doc', approved: false);
    client.wall = null;
    await expectLater(
      repository.updatePending('doc', next, expected: expected),
      throwsA(failure(WallMetadataFailure.missing)),
    );
    expect(client.patches, isEmpty);
  });

  test('a conflicting creator UID never falls back to a matching email', () async {
    client.wall!['creatorUid'] = 'someone-else';
    await expectLater(repository.load('doc', approved: false), throwsA(failure(WallMetadataFailure.denied)));
  });

  test('legacy pending owner email is accepted while missing identity is denied', () async {
    client.wall!.remove('creatorUid');
    expect((await repository.load('doc', approved: false)).approved, isFalse);
    client.wall!.remove('email');
    await expectLater(repository.load('doc', approved: false), throwsA(failure(WallMetadataFailure.denied)));
  });

  test('an empty legacy email cannot establish ownership', () async {
    activeOwner = (uid: owner.uid, email: '');
    client.wall!
      ..remove('creatorUid')
      ..['email'] = '';
    await expectLater(repository.load('doc', approved: false), throwsA(failure(WallMetadataFailure.denied)));
  });

  test('account change during transaction refuses the write', () async {
    final expected = await repository.load('doc', approved: false);
    client.beforeRead = () async => activeOwner = (uid: 'other', email: 'other@example.com');
    await expectLater(
      repository.updatePending('doc', next, expected: expected),
      throwsA(failure(WallMetadataFailure.signedOut)),
    );
    expect(client.patches, isEmpty);
  });

  test('approved load obtains a server revision and save sends only the strict text envelope', () async {
    final snapshot = await repository.load('wall_file.jpg', approved: true);
    expect(snapshot.revision, 'server-revision');
    await repository.editApproved('wall_file.jpg', next.text, expectedRevision: snapshot.revision, operationId: 'op');
    expect(calls, ['getWallMetadataForEdit', 'editWallMetadata']);
    expect(envelopes.last, {
      'wallDocId': 'wall_file.jpg',
      'operationId': 'op',
      'expectedRevision': 'server-revision',
      'metadata': {
        'title': 'Rain',
        'desc': 'A quiet evening',
        'tags': ['rain'],
      },
    });
    expect(client.patches, isEmpty);
  });

  test('admin revert references the audit and revision without supplying old values', () async {
    await repository.revert('doc', 'audit', expectedRevision: 'rev', operationId: 'op');
    expect(calls.single, 'revertWallMetadata');
    expect(envelopes.single, {'wallDocId': 'doc', 'auditId': 'audit', 'operationId': 'op', 'expectedRevision': 'rev'});
  });

  test('cache failure after confirmed save does not report the save as failed', () async {
    final repo = WallMetadataRepositoryImpl(
      client,
      owner: () => owner,
      caller: (_, _) async => response,
      invalidateCaches: () async => throw StateError('disk full'),
    );
    expect(
      (await repo.editApproved('doc', next.text, expectedRevision: 'rev', operationId: 'op')).metadata.text,
      next.text,
    );
  });

  test('unverified queue pointers never produce a verified context', () async {
    response = {
      'contexts': {
        'good': {'verified': true, 'attempt': 2, 'previousReason': 'Wrong crop'},
        'fake': {'attempt': 1, 'previousReason': 'Client supplied'},
        'overflow': {'verified': true, 'attempt': 4},
      },
    };
    final contexts = await repository.resubmissionContexts(['good', 'fake', 'overflow']);
    expect(contexts.keys, ['good']);
    expect(contexts['good']!.previousReason, 'Wrong crop');
  });

  test('queue context requests are bounded batches, not per-tile calls', () async {
    response = {'contexts': <String, Object?>{}};
    await repository.resubmissionContexts(List.generate(103, (i) => 'doc-$i'));
    expect(calls, List.filled(3, 'getWallResubmissionContext'));
    expect(envelopes.map((data) => (data['wallDocIds']! as List).length), [50, 50, 3]);
  });

  test('callable failures retain typed conflict rather than falling back to Firestore', () async {
    final repo = WallMetadataRepositoryImpl(
      client,
      owner: () => owner,
      caller: (_, _) async => throw cf.FirebaseFunctionsException(code: 'aborted', message: 'metadata-conflict'),
    );
    await expectLater(
      repo.editApproved('doc', next.text, expectedRevision: 'rev', operationId: 'op'),
      throwsA(failure(WallMetadataFailure.conflict)),
    );
    expect(client.patches, isEmpty);
  });
}
