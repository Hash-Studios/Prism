import 'package:Prism/core/constants/app_functions.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_error.dart';
import 'package:Prism/core/persistence/data_sources/feed_cache_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/wallpaper_upload/domain/entities/wall_metadata.dart';
import 'package:Prism/features/wallpaper_upload/domain/repositories/wall_metadata_repository.dart';
import 'package:cloud_functions/cloud_functions.dart' as cf;
import 'package:collection/collection.dart';

typedef WallMetadataCaller = Future<Object?> Function(String name, Map<String, Object?> data);
typedef WallMetadataOwner = ({String uid, String email});

class WallMetadataRepositoryImpl implements WallMetadataRepository {
  WallMetadataRepositoryImpl(
    this._client, {
    required WallMetadataOwner Function() owner,
    WallMetadataCaller? caller,
    Future<void> Function()? invalidateCaches,
  }) : _owner = owner,
       _call = caller ?? _callable,
       _invalidateCaches = invalidateCaches;

  factory WallMetadataRepositoryImpl.fromGetIt() => WallMetadataRepositoryImpl(
    getIt<FirestoreClient>(),
    owner: () => (uid: app_state.prismUser.loggedIn ? app_state.prismUser.id : '', email: app_state.prismUser.email),
    invalidateCaches: () async {
      getIt<FirestoreClient>().invalidateQueryCache();
      if (getIt.isRegistered<FeedCacheLocalDataSource>()) {
        await getIt<FeedCacheLocalDataSource>().clearAllFeedCaches();
      }
    },
  );

  final FirestoreClient _client;
  final WallMetadataOwner Function() _owner;
  final WallMetadataCaller _call;
  final Future<void> Function()? _invalidateCaches;

  static Future<Object?> _callable(String name, Map<String, Object?> data) async =>
      (await appFunctions
              .httpsCallable(name, options: cf.HttpsCallableOptions(timeout: const Duration(seconds: 30)))
              .call<Object?>(data))
          .data;

  @override
  Future<WallMetadataSnapshot> load(String wallDocId, {required bool approved}) async {
    if (approved) {
      return _snapshot(await _invoke('getWallMetadataForEdit', <String, Object?>{'wallDocId': wallDocId}));
    }
    try {
      final WallMetadataOwner owner = _requireOwner();
      final Map<String, dynamic>? data = await _client.getById<Map<String, dynamic>>(
        FirebaseCollections.walls,
        wallDocId,
        (data, _) => data,
        sourceTag: 'wall_metadata.load_pending',
      );
      _checkPending(data, owner);
      return WallMetadataSnapshot(
        metadata: PendingWallMetadata.fromMap(data!),
        approved: false,
        expectedPendingFields: WallMetadataSnapshot.pendingFields(data),
      );
    } catch (error) {
      throw _failure(error);
    }
  }

  WallMetadataOwner _requireOwner() {
    final WallMetadataOwner owner = _owner();
    if (owner.uid.isEmpty) throw const WallMetadataException(WallMetadataFailure.signedOut);
    return owner;
  }

  void _checkPending(Map<String, dynamic>? data, WallMetadataOwner owner) {
    if (_owner().uid != owner.uid) throw const WallMetadataException(WallMetadataFailure.signedOut);
    if (data == null) throw const WallMetadataException(WallMetadataFailure.missing);
    final Object? creatorUid = data['creatorUid'];
    if (creatorUid is String && creatorUid.isNotEmpty
        ? creatorUid != owner.uid
        : owner.email.isEmpty || data['email'] != owner.email) {
      throw const WallMetadataException(WallMetadataFailure.denied);
    }
    if (data['review'] != false) throw const WallMetadataException(WallMetadataFailure.statusChanged);
  }

  @override
  Future<WallMetadataSnapshot> updatePending(
    String wallDocId,
    PendingWallMetadata metadata, {
    required WallMetadataSnapshot expected,
  }) async {
    try {
      final WallMetadataOwner owner = _requireOwner();
      await _client.runTransaction<void>(
        (transaction) async {
          final Map<String, dynamic>? current = await transaction.getDoc(FirebaseCollections.walls, wallDocId);
          _checkPending(current, owner);
          if (!const DeepCollectionEquality().equals(
            WallMetadataSnapshot.pendingFields(current!),
            expected.expectedPendingFields,
          )) {
            throw const WallMetadataException(WallMetadataFailure.conflict);
          }
          transaction.updateDoc(FirebaseCollections.walls, wallDocId, metadata.toMap());
        },
        sourceTag: 'wall_metadata.update_pending',
        collection: FirebaseCollections.walls,
        docId: wallDocId,
      );
      await _afterSave();
      return WallMetadataSnapshot(metadata: metadata, approved: false, expectedPendingFields: metadata.toMap());
    } catch (error) {
      throw _failure(error);
    }
  }

  @override
  Future<WallMetadataSnapshot> editApproved(
    String wallDocId,
    WallTextMetadata metadata, {
    required String expectedRevision,
    required String operationId,
  }) async {
    final WallMetadataSnapshot result = _snapshot(
      await _invoke('editWallMetadata', <String, Object?>{
        'wallDocId': wallDocId,
        'operationId': operationId,
        'expectedRevision': expectedRevision,
        'metadata': metadata.toMap(),
      }),
    );
    await _afterSave();
    return result;
  }

  @override
  Future<WallMetadataSnapshot> revert(
    String wallDocId,
    String auditId, {
    required String expectedRevision,
    required String operationId,
  }) async {
    final WallMetadataSnapshot result = _snapshot(
      await _invoke('revertWallMetadata', <String, Object?>{
        'wallDocId': wallDocId,
        'auditId': auditId,
        'operationId': operationId,
        'expectedRevision': expectedRevision,
      }),
    );
    await _afterSave();
    return result;
  }

  @override
  Future<WallMetadataAuditPage> listEdits(String wallDocId, {String? cursor}) async {
    final Map<String, dynamic> body = await _invoke('listWallMetadataEdits', <String, Object?>{
      'wallDocId': wallDocId,
      'limit': 20,
      if (cursor != null) 'cursor': cursor,
    });
    final Object? edits = body['edits'];
    if (edits is! List) throw const WallMetadataException(WallMetadataFailure.unavailable);
    return WallMetadataAuditPage(
      edits: edits
          .map((value) {
            final Map<String, dynamic> row = _map(value);
            return WallMetadataAudit(
              id: row['auditId'] as String,
              before: _map(row['before']),
              after: _map(row['after']),
              actorUid: row['actorUid'] as String? ?? '',
              createdAt: DateTime.tryParse(row['createdAt']?.toString() ?? ''),
              canRevert: row['canRevert'] == true,
            );
          })
          .toList(growable: false),
      cursor: body['cursor'] as String?,
    );
  }

  @override
  Future<Map<String, WallResubmissionContext>> resubmissionContexts(List<String> wallDocIds) async {
    final Map<String, WallResubmissionContext> result = <String, WallResubmissionContext>{};
    for (int start = 0; start < wallDocIds.length; start += 50) {
      final List<String> ids = wallDocIds.skip(start).take(50).toList(growable: false);
      final Map<String, dynamic> body = await _invoke('getWallResubmissionContext', <String, Object?>{
        'wallDocIds': ids,
      });
      final Map<String, dynamic> contexts = _map(body['contexts']);
      for (final String id in ids) {
        final Object? value = contexts[id];
        if (value == null) continue;
        final Map<String, dynamic> row = _map(value);
        final Object? attempt = row['attempt'];
        if (row['verified'] == true && attempt is int && attempt >= 1 && attempt <= 3) {
          result[id] = WallResubmissionContext(
            attempt: attempt,
            previousReason: row['previousReason'] as String? ?? '',
          );
        }
      }
    }
    return result;
  }

  Future<void> _afterSave() async {
    try {
      await _invalidateCaches?.call();
    } catch (_) {}
  }

  Future<Map<String, dynamic>> _invoke(String name, Map<String, Object?> data) async {
    try {
      return _map(await _call(name, data));
    } catch (error) {
      throw _failure(error);
    }
  }

  static Map<String, dynamic> _map(Object? value) {
    if (value is! Map) throw const WallMetadataException(WallMetadataFailure.unavailable);
    return Map<String, dynamic>.from(value);
  }

  static WallMetadataSnapshot _snapshot(Map<String, dynamic> body) {
    final Map<String, dynamic> metadata = _map(body['metadata']);
    final Object? revision = body['revision'];
    if (revision is! String || revision.isEmpty) {
      throw const WallMetadataException(WallMetadataFailure.unavailable);
    }
    final bool approved = body['status'] == 'approved';
    if (!approved) throw const WallMetadataException(WallMetadataFailure.statusChanged);
    return WallMetadataSnapshot(
      metadata: PendingWallMetadata(text: WallTextMetadata.fromMap(metadata)),
      approved: true,
      revision: revision,
    );
  }

  static WallMetadataException _failure(Object error) {
    if (error is WallMetadataException) return error;
    if (error is FirestoreError && error.original is WallMetadataException) {
      return error.original! as WallMetadataException;
    }
    final String? code = switch (error) {
      cf.FirebaseFunctionsException() => error.code,
      FirestoreError() => error.code,
      _ => null,
    };
    return WallMetadataException(switch (code) {
      'aborted' || 'already-exists' => WallMetadataFailure.conflict,
      'failed-precondition' => WallMetadataFailure.statusChanged,
      'not-found' => WallMetadataFailure.missing,
      'unauthenticated' => WallMetadataFailure.signedOut,
      'permission-denied' => WallMetadataFailure.denied,
      'invalid-argument' => WallMetadataFailure.invalid,
      'resource-exhausted' => WallMetadataFailure.dailyLimit,
      _ => WallMetadataFailure.unavailable,
    });
  }
}
