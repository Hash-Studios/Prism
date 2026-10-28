import 'dart:math' as math;

import 'package:Prism/core/constants/app_functions.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_error.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/parse_helpers.dart';
import 'package:Prism/features/folders/domain/entities/folder_entity.dart';
import 'package:Prism/features/folders/domain/entities/public_folder_entity.dart';
import 'package:Prism/features/folders/domain/repositories/public_folders_repository.dart';
import 'package:Prism/logger/logger.dart';
import 'package:cloud_functions/cloud_functions.dart' show FirebaseFunctionsException;
import 'package:injectable/injectable.dart';

typedef PublicFolderCallable = Future<Object?> Function(String name, Map<String, Object?> data);

PublicFolderEntity publicFolderFromDoc(Map<String, dynamic> data, String id) {
  final Object? covers = data['covers'];
  int count(Object? value) => value is num ? math.max(0, value.toInt()) : 0;
  return PublicFolderEntity(
    id: id,
    ownerId: parseString(data['ownerId']),
    name: parseString(data['name']),
    itemCount: count(data['itemCount']),
    covers: covers is List ? covers.whereType<String>().take(folderMaxCovers).toList() : const <String>[],
    followerCount: count(data['followerCount']),
    shareImage: parseString(data['shareImage']),
  );
}

/// Maps a callable error to the refusal the UI explains. The server sends the reason in the message.
PublicFolderFailure publicFolderFailure(Object error) {
  if (error is! FirebaseFunctionsException) return PublicFolderFailure('$error');
  final String message = error.message ?? '';
  final PublicFolderRefusal? refusal = switch (error.code) {
    'resource-exhausted' => PublicFolderRefusal.limit,
    'failed-precondition' when message == 'name' => PublicFolderRefusal.name,
    'failed-precondition' when message == 'hidden' => PublicFolderRefusal.hidden,
    'failed-precondition' || 'not-found' => PublicFolderRefusal.unavailable,
    _ => null,
  };
  return PublicFolderFailure(message.isEmpty ? error.code : message, refusal: refusal, code: error.code);
}

@LazySingleton(as: PublicFoldersRepository)
class PublicFoldersRepositoryImpl implements PublicFoldersRepository {
  PublicFoldersRepositoryImpl(this._firestoreClient, {@ignoreParam PublicFolderCallable? callFunction})
    : _call = callFunction ?? _callFunction;

  final FirestoreClient _firestoreClient;
  final PublicFolderCallable _call;

  static Future<Object?> _callFunction(String name, Map<String, Object?> data) async =>
      (await appFunctions.httpsCallable(name).call<Object?>(data)).data;

  Future<Result<T>> _guard<T>(String what, Future<T> Function() body) async {
    try {
      return Result.success(await body());
    } catch (error, stackTrace) {
      logger.w('Public folders: could not $what', tag: 'Folders', error: error, stackTrace: stackTrace);
      return Result.error(publicFolderFailure(error));
    }
  }

  @override
  Future<Result<PublicFolderEntity?>> fetchFolder(String folderId) async {
    try {
      return Result.success(
        await _firestoreClient.getById<PublicFolderEntity>(
          FirebaseCollections.publicFolders,
          folderId,
          publicFolderFromDoc,
          sourceTag: 'public_folders.fetch_folder',
        ),
      );
    } catch (error) {
      // The rules refuse a private folder and a folder hidden by a block. Both look like a missing folder.
      if (mapFirestoreError(error).code == 'permission-denied') return Result.success(null);
      return Result.error(publicFolderFailure(error));
    }
  }

  @override
  Future<Result<List<String>>> fetchWallIds(String folderId) async {
    try {
      return Result.success(
        await _firestoreClient.query<String>(
          FirestoreQuerySpec(
            collection: FirebaseCollections.publicFolderItems(folderId),
            sourceTag: 'public_folders.fetch_items',
            orderBy: const <FirestoreOrderBy>[FirestoreOrderBy(field: 'addedAt', descending: true)],
          ),
          (data, docId) => parseString(data['id']),
        ),
      );
    } catch (error) {
      // The folder can become private or blocked after its header was read. Rules deny the item query in that case.
      final FirestoreError firestoreError = mapFirestoreError(error);
      if (firestoreError.code == 'permission-denied') {
        return Result.error(
          PublicFolderFailure(
            'The folder is private or no longer available.',
            refusal: PublicFolderRefusal.unavailable,
            code: firestoreError.code,
          ),
        );
      }
      return Result.error(publicFolderFailure(error));
    }
  }

  @override
  Future<Result<List<PublicFolderEntity>>> fetchOwnerFolders(String ownerId) => _guard(
    'load public folders',
    () => _firestoreClient.query<PublicFolderEntity>(
      FirestoreQuerySpec(
        collection: FirebaseCollections.publicFolders,
        sourceTag: 'public_folders.fetch_owner_folders',
        filters: <FirestoreFilter>[FirestoreFilter(field: 'ownerId', op: FirestoreFilterOp.isEqualTo, value: ownerId)],
        orderBy: const <FirestoreOrderBy>[FirestoreOrderBy(field: 'updatedAt', descending: true)],
      ),
      publicFolderFromDoc,
    ),
  );

  @override
  Future<Result<List<PublicFolderEntity>>> fetchFollowedFolders(String userId) =>
      _guard('load followed folders', () async {
        final List<String> ids = await _firestoreClient.query<String>(
          FirestoreQuerySpec(
            collection: FirebaseCollections.followedFolders(userId),
            sourceTag: 'public_folders.fetch_followed',
            orderBy: const <FirestoreOrderBy>[FirestoreOrderBy(field: 'createdAt', descending: true)],
          ),
          (data, docId) => docId,
        );
        final List<Result<PublicFolderEntity?>> folders = await Future.wait(ids.map(fetchFolder));
        // A private, deleted or blocked folder reads as null and is left out. A failed read fails the whole list.
        final Object? failure = folders.where((folder) => folder.isFailure).firstOrNull?.failure;
        if (failure != null) throw failure;
        return <PublicFolderEntity>[
          for (final Result<PublicFolderEntity?> folder in folders)
            if (folder.data != null) folder.data!,
        ];
      });

  @override
  Future<Result<bool>> isFollowing(String folderId, String userId) => _guard(
    'load follow state',
    () async =>
        await _firestoreClient.getById<bool>(
          FirebaseCollections.followedFolders(userId),
          folderId,
          (data, docId) => true,
          sourceTag: 'public_folders.is_following',
        ) ??
        false,
  );

  @override
  Future<Result<void>> setFollowing(String folderId, {required bool following}) => _guard(
    following ? 'follow folder' : 'unfollow folder',
    () => _call('setFolderFollow', <String, Object?>{'folderId': folderId, 'following': following}),
  );

  @override
  Future<Result<bool>> setPublic(String folderId, {required bool isPublic}) => _guard(
    'change folder visibility',
    () async {
      final Object? data = await _call('setFolderPublic', <String, Object?>{'folderId': folderId, 'public': isPublic});
      return data is Map && data['public'] is bool ? data['public'] as bool : isPublic;
    },
  );
}
