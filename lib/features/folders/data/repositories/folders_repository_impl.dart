import 'dart:async';
import 'dart:math' as math;

import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/firestore/dtos/wall_doc_dto.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_error.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/firestore/firestore_sentinels.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/parse_helpers.dart';
import 'package:Prism/features/favourite_walls/data/favourite_wall_doc_mapper.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/folders/domain/entities/folder_entity.dart';
import 'package:Prism/features/folders/domain/repositories/folders_repository.dart';
import 'package:Prism/logger/logger.dart';
import 'package:injectable/injectable.dart';

const int _maxBatchWrites = 400;

/// Offline, a write never completes. The SDK keeps it and sends it when the network returns, so the app stops
/// waiting after this long and treats the write as queued.
const Duration _writeTimeout = Duration(seconds: 8);

FolderEntity folderFromDoc(Map<String, dynamic> data, String id) {
  final DateTime now = DateTime.now().toUtc();
  final Object? covers = data['covers'];
  final Object? count = data['itemCount'];
  return FolderEntity(
    id: id,
    ownerId: parseString(data['ownerId']),
    name: parseString(data['name']),
    createdAt: parseDateTime(data['createdAt']) ?? now,
    updatedAt: parseDateTime(data['updatedAt']) ?? now,
    itemCount: count is num ? math.max(0, count.toInt()) : 0,
    covers: covers is List ? covers.whereType<String>().take(folderMaxCovers).toList() : const <String>[],
  );
}

@LazySingleton(as: FoldersRepository)
class FoldersRepositoryImpl implements FoldersRepository {
  FoldersRepositoryImpl(this._firestoreClient);

  final FirestoreClient _firestoreClient;
  final StreamController<FolderWriteFailure> _writeFailures = StreamController<FolderWriteFailure>.broadcast();
  int _writeRevision = 0;

  @override
  int get writeRevision => _writeRevision;

  @override
  Stream<FolderWriteFailure> get writeFailures => _writeFailures.stream;

  Future<void> _write(
    Future<void> Function(FirestoreBatch batch) action,
    String sourceTag, {
    required String ownerId,
  }) async {
    final int revision = ++_writeRevision;
    bool queued = false;
    final Future<void> pending = _firestoreClient.runBatch(action, sourceTag: sourceTag).onError((
      Object error,
      StackTrace stackTrace,
    ) {
      if (!queued) Error.throwWithStackTrace(error, stackTrace);
      logger.e('Queued folder write rejected: $sourceTag', tag: 'Folders', error: error, stackTrace: stackTrace);
      _writeFailures.add((
        ownerId: ownerId,
        revision: revision,
        failure: ServerFailure('Unable to save folders: $error'),
      ));
    });
    try {
      await pending.timeout(_writeTimeout);
    } on TimeoutException {
      queued = true;
      logger.w('Folder write queued offline: $sourceTag', tag: 'Folders');
    }
  }

  Future<Result<T>> _guard<T>(String what, Future<T> Function() body) async {
    try {
      return Result.success(await body());
    } catch (error) {
      return Result.error(ServerFailure('Unable to $what: $error'));
    }
  }

  @override
  Future<Result<List<FolderEntity>>> fetchFolders(String userId) => _guard('load folders', () async {
    if (userId.isEmpty) return const <FolderEntity>[];
    return _firestoreClient.query<FolderEntity>(
      FirestoreQuerySpec(
        collection: FirebaseCollections.folders,
        sourceTag: 'folders.fetch_folders',
        filters: <FirestoreFilter>[FirestoreFilter(field: 'ownerId', op: FirestoreFilterOp.isEqualTo, value: userId)],
        orderBy: const <FirestoreOrderBy>[FirestoreOrderBy(field: 'updatedAt', descending: true)],
      ),
      folderFromDoc,
    );
  });

  @override
  Future<Result<List<FavouriteWallEntity>?>> fetchItems(String folderId, {required String userId, int? limit}) =>
      _guard('load folder items', () async {
        if (userId.isEmpty) return null;
        try {
          final rows = await _firestoreClient.query<({FavouriteWallEntity wall, DateTime addedAt})>(
            FirestoreQuerySpec(
              collection: FirebaseCollections.folderItems(folderId),
              sourceTag: 'folders.fetch_items',
              filters: <FirestoreFilter>[
                FirestoreFilter(field: 'ownerId', op: FirestoreFilterOp.isEqualTo, value: userId),
              ],
            ),
            (data, docId) => (
              wall: mapFavouriteWallDoc(
                FavouriteWallDocDto.fromJson(data),
                parseString(data['wallpaperDocumentId'], fallback: parseString(data['id'], fallback: docId)),
              ),
              addedAt: parseDateTime(data['addedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
            ),
          );
          // The owner filter is required by the item rules. Sorting here avoids an extra composite index.
          rows.sort((a, b) => b.addedAt.compareTo(a.addedAt));
          final items = rows.map((row) => row.wall);
          return (limit == null ? items : items.take(limit)).toList();
        } catch (error) {
          // The rules refuse reads of a folder that is gone or belongs to someone else.
          if (mapFirestoreError(error).code == 'permission-denied') return null;
          rethrow;
        }
      });

  @override
  Future<Result<Set<String>>> foldersContaining(List<String> folderIds, String itemKey) =>
      _guard('read folder membership', () async {
        final List<bool> found = await Future.wait(<Future<bool>>[
          for (final String folderId in folderIds)
            _firestoreClient
                .getById<bool>(
                  FirebaseCollections.folderItems(folderId),
                  itemKey,
                  (_, _) => true,
                  sourceTag: 'folders.membership',
                )
                .then((value) => value ?? false)
                .onError((Object error, StackTrace stackTrace) {
                  // A recreated folder can still contain a former owner's item with this key.
                  if (mapFirestoreError(error).code == 'permission-denied') return false;
                  Error.throwWithStackTrace(error, stackTrace);
                }),
        ]);
        return <String>{
          for (int i = 0; i < folderIds.length; i++)
            if (found[i]) folderIds[i],
        };
      });

  Map<String, dynamic> _itemDoc(FolderEntity folder, FavouriteWallEntity wall) => <String, dynamic>{
    ...favouriteWallToDoc(wall),
    'ownerId': folder.ownerId,
    'addedAt': FirestoreSentinels.serverTimestamp(),
    if (wall case PrismFavouriteWall(:final wallpaper)) 'wallpaperDocumentId': wallpaper.firestoreDocumentId ?? wall.id,
  };

  @override
  Future<Result<void>> createFolder(FolderEntity folder, {FavouriteWallEntity? firstWall}) =>
      _guard('create folder', () async {
        await _write(
          (batch) async {
            batch.setDoc(FirebaseCollections.folders, folder.id, <String, dynamic>{
              'ownerId': folder.ownerId,
              'name': folder.name,
              'createdAt': FirestoreSentinels.serverTimestamp(),
              'updatedAt': FirestoreSentinels.serverTimestamp(),
              'itemCount': folder.itemCount,
              'covers': folder.covers,
            });
            if (firstWall != null) {
              batch.setDoc(
                FirebaseCollections.folderItems(folder.id),
                folderItemKey(firstWall),
                _itemDoc(folder, firstWall),
              );
            }
          },
          'folders.create',
          ownerId: folder.ownerId,
        );
      });

  @override
  Future<Result<void>> renameFolder(FolderEntity folder) => _guard('rename folder', () async {
    await _write(
      (batch) async {
        batch.updateDoc(FirebaseCollections.folders, folder.id, <String, dynamic>{
          'name': folder.name,
          'updatedAt': FirestoreSentinels.serverTimestamp(),
        });
      },
      'folders.rename',
      ownerId: folder.ownerId,
    );
  });

  @override
  Future<Result<void>> deleteFolder(String folderId, {required String userId, bool Function()? isCancelled}) => _guard(
    'delete folder',
    () async {
      if (userId.isEmpty) throw StateError('Sign in to delete folders.');
      void ensureActive() {
        if (isCancelled?.call() ?? false) throw StateError('Folder operation cancelled.');
      }

      ensureActive();
      final List<String> keys = await _firestoreClient.query<String>(
        FirestoreQuerySpec(
          collection: FirebaseCollections.folderItems(folderId),
          sourceTag: 'folders.delete.list',
          filters: <FirestoreFilter>[FirestoreFilter(field: 'ownerId', op: FirestoreFilterOp.isEqualTo, value: userId)],
        ),
        (_, docId) => docId,
      );
      ensureActive();
      for (int start = 0; start < keys.length; start += _maxBatchWrites) {
        ensureActive();
        final List<String> chunk = keys.sublist(start, math.min(start + _maxBatchWrites, keys.length));
        await _write(
          (batch) async {
            ensureActive();
            for (final String key in chunk) {
              batch.deleteDoc(FirebaseCollections.folderItems(folderId), key);
            }
          },
          'folders.delete.items',
          ownerId: userId,
        );
      }
      // The folder goes last, so a failed run leaves it in place and deleteAccount still finds its items.
      ensureActive();
      await _write(
        (batch) async {
          ensureActive();
          batch.deleteDoc(FirebaseCollections.folders, folderId);
        },
        'folders.delete.folder',
        ownerId: userId,
      );
    },
  );

  Map<String, dynamic> _folderCounts(FolderEntity folder, int delta) => <String, dynamic>{
    'itemCount': FirestoreSentinels.increment(delta),
    'covers': folder.covers,
    'updatedAt': FirestoreSentinels.serverTimestamp(),
  };

  @override
  Future<Result<void>> addItem(FolderEntity folder, FavouriteWallEntity wall) => _guard('add to folder', () async {
    await _write(
      (batch) async {
        batch.setDoc(FirebaseCollections.folderItems(folder.id), folderItemKey(wall), _itemDoc(folder, wall));
        batch.updateDoc(FirebaseCollections.folders, folder.id, _folderCounts(folder, 1));
      },
      'folders.add_item',
      ownerId: folder.ownerId,
    );
  });

  @override
  Future<Result<void>> removeItem(FolderEntity folder, FavouriteWallEntity wall) =>
      _guard('remove from folder', () async {
        await _write(
          (batch) async {
            batch.deleteDoc(FirebaseCollections.folderItems(folder.id), folderItemKey(wall));
            batch.updateDoc(FirebaseCollections.folders, folder.id, _folderCounts(folder, -1));
          },
          'folders.remove_item',
          ownerId: folder.ownerId,
        );
      });
}
