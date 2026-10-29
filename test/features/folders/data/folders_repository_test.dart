import 'dart:async';

import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/folders/biz/bloc/folders_bloc.j.dart';
import 'package:Prism/features/folders/data/repositories/folders_repository_impl.dart';
import 'package:Prism/features/folders/domain/entities/folder_entity.dart';
import 'package:Prism/features/folders/domain/entities/public_folder_entity.dart';
import 'package:Prism/features/folders/domain/repositories/folders_repository.dart';
import 'package:Prism/features/folders/domain/repositories/public_folders_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_firestore_client.dart';

class _Batch implements FirestoreBatch {
  final List<({String op, String collection, String id, Map<String, dynamic>? data})> writes = [];

  @override
  void addDoc(String collection, Map<String, dynamic> data) => throw UnimplementedError();

  @override
  void setDoc(String collection, String id, Map<String, dynamic> data) =>
      writes.add((op: 'set', collection: collection, id: id, data: data));

  @override
  void updateDoc(String collection, String id, Map<String, dynamic> data) =>
      writes.add((op: 'update', collection: collection, id: id, data: data));

  @override
  void deleteDoc(String collection, String id) =>
      writes.add((op: 'delete', collection: collection, id: id, data: null));
}

class _Client extends FakeFirestoreClient {
  final List<({String tag, _Batch batch})> batches = [];
  Future<void> Function(int)? onCommit;
  Object? membershipError;
  Completer<void>? queryGate;

  @override
  Future<List<T>> query<T>(FirestoreQuerySpec spec, T Function(Map<String, dynamic> data, String docId) map) async {
    await queryGate?.future;
    return super.query(spec, map);
  }

  @override
  Future<void> runBatch(Future<void> Function(FirestoreBatch batch) action, {required String sourceTag}) async {
    final batch = _Batch();
    batches.add((tag: sourceTag, batch: batch));
    await action(batch);
    await onCommit?.call(batches.length);
  }

  @override
  Future<T?> getById<T>(
    String collection,
    String id,
    T Function(Map<String, dynamic> data, String docId) map, {
    required String sourceTag,
    bool preferCacheFirst = false,
  }) {
    if (membershipError case final error?) return Future.error(error);
    return super.getById(collection, id, map, sourceTag: sourceTag, preferCacheFirst: preferCacheFirst);
  }
}

FolderEntity _folder() => FolderEntity(
  id: 'a',
  ownerId: 'u1',
  name: 'A',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  itemCount: 0,
  covers: const [],
);

class _NoPublicFolders implements PublicFoldersRepository {
  @override
  Future<Result<PublicFolderEntity?>> fetchFolder(String folderId) async => Result.success<PublicFolderEntity?>(null);

  @override
  Future<Result<List<String>>> fetchWallIds(String folderId) async => Result.success(<String>[]);

  @override
  Future<Result<List<PublicFolderEntity>>> fetchOwnerFolders(String ownerId) async =>
      Result.success(<PublicFolderEntity>[]);

  @override
  Future<Result<List<PublicFolderEntity>>> fetchFollowedFolders(String userId) async =>
      Result.success(<PublicFolderEntity>[]);

  @override
  Future<Result<bool>> isFollowing(String folderId, String userId) async => Result.success(false);

  @override
  Future<Result<void>> setFollowing(String folderId, {required bool following}) async => Result.success<void>(null);

  @override
  Future<Result<bool>> setPublic(String folderId, {required bool isPublic}) async => Result.success(isPublic);
}

void main() {
  for (final holdQuery in <bool>[true, false]) {
    test('sign-out stops delete after the pending ${holdQuery ? 'query' : 'chunk'}', () async {
      final gate = Completer<void>();
      final client = _Client()
        ..onQuery = ((spec) => spec.collection == FirebaseCollections.folders
            ? <FakeDocRow>[
                (id: 'a', data: <String, dynamic>{'ownerId': 'u1', 'name': 'A', 'itemCount': 401}),
              ]
            : List.generate(401, (index) => (id: 'prism_$index', data: <String, dynamic>{})));
      final bloc = FoldersBloc(FoldersRepositoryImpl(client), _NoPublicFolders());
      addTearDown(bloc.close);
      await bloc.run((id) => FoldersEvent.started(userId: 'u1', operationId: id));
      if (holdQuery) {
        client.queryGate = gate;
      } else {
        client.onCommit = (_) => gate.future;
      }
      final deleting = bloc.run((id) => FoldersEvent.deleteRequested(folderId: 'a', operationId: id));
      await pumpEventQueue();
      expect(client.batches.length, holdQuery ? 0 : 1);

      bloc.add(const FoldersEvent.cleared());
      await pumpEventQueue();
      gate.complete();
      expect(await deleting, isFalse);
      await pumpEventQueue();
      expect(client.batches.length, holdQuery ? 0 : 1);
      expect(bloc.state, FoldersState.initial());
    });
  }

  test('folder item mapping preserves the source wallpaper document id', () async {
    final client = _Client()
      ..onQuery = (_) => <FakeDocRow>[
        (id: 'prism_wall', data: {'id': 'wall', 'provider': 'Prism', 'wallpaperDocumentId': 'source-document'}),
      ];
    final repository = FoldersRepositoryImpl(client);
    final result = await repository.fetchItems('a', userId: 'u1');
    expect((result.data!.single as PrismFavouriteWall).wallpaper.firestoreDocumentId, 'source-document');
    await repository.createFolder(_folder(), firstWall: result.data!.single);
    final item = client.batches.single.batch.writes.last;
    expect(item.id, 'prism_wall');
    expect(item.data?['wallpaperDocumentId'], 'source-document');
  });

  test('item reads filter on item ownership and preserve newest-first limit', () async {
    final client = _Client()
      ..onQuery = (_) => <FakeDocRow>[
        (id: 'prism_old', data: {'id': 'old', 'provider': 'Prism', 'addedAt': DateTime.utc(2026)}),
        (id: 'prism_new', data: {'id': 'new', 'provider': 'Prism', 'addedAt': DateTime.utc(2026, 2)}),
      ];
    final result = await FoldersRepositoryImpl(client).fetchItems('a', userId: 'u1', limit: 1);

    expect(client.querySpecs.single.filters.single.field, 'ownerId');
    expect(client.querySpecs.single.filters.single.value, 'u1');
    expect(result.data?.map((wall) => wall.id), <String>['new']);
    expect(client.querySpecs.single.sourceTag, 'folders.fetch_items');
  });

  test('delete lists only items owned by this user and stops before parent on chunk failure', () async {
    final client = _Client()
      ..onQuery = ((_) => List.generate(401, (index) => (id: 'prism_$index', data: <String, dynamic>{})))
      ..onCommit = (number) async {
        if (number == 2) throw StateError('chunk rejected');
      };
    final result = await FoldersRepositoryImpl(client).deleteFolder('a', userId: 'u1');

    expect(result.isFailure, isTrue);
    expect(client.querySpecs.single.filters.single.field, 'ownerId');
    expect(client.querySpecs.single.filters.single.value, 'u1');
    expect(client.batches.map((entry) => entry.tag), <String>['folders.delete.items', 'folders.delete.items']);
    expect(client.batches.first.batch.writes, hasLength(400));
    expect(client.batches.last.batch.writes, hasLength(1));
    expect(
      client.batches
          .expand((entry) => entry.batch.writes)
          .where((write) => write.collection == FirebaseCollections.folders),
      isEmpty,
    );
  });

  test('denied orphan membership is absent while other read failures still fail', () async {
    final client = _Client()..membershipError = FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied');
    final repository = FoldersRepositoryImpl(client);
    final denied = await repository.foldersContaining(<String>['a'], 'prism_old');
    expect(denied.isSuccess, isTrue);
    expect(denied.data, isEmpty);

    client.membershipError = FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
    expect((await repository.foldersContaining(<String>['a'], 'prism_old')).isFailure, isTrue);
  });

  testWidgets('a write is queued only after eight seconds and a late rejection is handled', (tester) async {
    final commit = Completer<void>();
    final client = _Client()..onCommit = (_) => commit.future;
    final repository = FoldersRepositoryImpl(client);
    final failures = <FolderWriteFailure>[];
    final subscription = repository.writeFailures.listen(failures.add);
    addTearDown(subscription.cancel);
    bool? succeeded;
    final write = repository.renameFolder(_folder()).then((result) => succeeded = result.isSuccess);
    await tester.pump();
    await tester.pump(const Duration(seconds: 7));
    expect(succeeded, isNull);
    await tester.pump(const Duration(seconds: 1));
    expect(succeeded, isTrue);
    expect(client.batches.single.tag, 'folders.rename');

    commit.completeError(FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'));
    await tester.pump();
    await write;
    expect(tester.takeException(), isNull);
    expect(client.batches, hasLength(1));
    expect(failures, hasLength(1));
    expect(failures.single.ownerId, 'u1');
    expect(failures.single.revision, 1);
    expect(failures.single.failure.message, contains('permission-denied'));
  });

  testWidgets('a rejection before the queue timeout is returned as a failure', (tester) async {
    final commit = Completer<void>();
    final client = _Client()..onCommit = (_) => commit.future;
    final write = FoldersRepositoryImpl(client).renameFolder(_folder());
    await tester.pump();
    commit.completeError(FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'));
    await tester.pump();
    expect((await write).isFailure, isTrue);
  });
}
