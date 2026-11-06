import 'dart:math' as math;

import 'package:Prism/core/constants/app_functions.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/parse_helpers.dart';
import 'package:Prism/features/folders/domain/entities/folder_entity.dart';
import 'package:Prism/features/folders/domain/entities/folder_invite.dart';
import 'package:Prism/features/folders/domain/repositories/shared_folders_repository.dart';
import 'package:Prism/logger/logger.dart';
import 'package:cloud_functions/cloud_functions.dart' show FirebaseFunctionsException;
import 'package:injectable/injectable.dart';

typedef SharedFolderCallable = Future<Object?> Function(String name, Map<String, Object?> data);

/// The server sends the refusal reason as the message of a failed-precondition error.
SharedFolderFailure sharedFolderFailure(Object error) {
  if (error is! FirebaseFunctionsException) return SharedFolderFailure('$error');
  final String message = error.message ?? '';
  final FolderJoinRefusal? refusal = error.code == 'failed-precondition' ? FolderJoinRefusal.fromWire(message) : null;
  return SharedFolderFailure(message.isEmpty ? error.code : message, refusal: refusal, code: error.code);
}

FolderInvitePreview folderInvitePreviewFrom(Object? data) {
  final Map<Object?, Object?> map = data is Map ? data : const <Object?, Object?>{};
  final String status = parseString(map['status']);
  if (status == 'join' || status == 'member' || status == 'owner') {
    final Object? covers = map['covers'];
    final Object? items = map['itemCount'];
    final Object? members = map['memberCount'];
    return FolderInviteOpen(
      folderId: parseString(map['folderId']),
      name: parseString(map['name']),
      ownerId: parseString(map['ownerId']),
      itemCount: items is num ? math.max(0, items.toInt()) : 0,
      covers: covers is List ? covers.whereType<String>().take(folderMaxCovers).toList() : const <String>[],
      memberCount: members is num ? math.max(1, members.toInt()) : 1,
      isMember: status != 'join',
    );
  }
  return FolderInviteRefused(FolderJoinRefusal.fromWire(status) ?? FolderJoinRefusal.notFound);
}

@LazySingleton(as: SharedFoldersRepository)
class SharedFoldersRepositoryImpl implements SharedFoldersRepository {
  SharedFoldersRepositoryImpl(this._firestoreClient, {@ignoreParam SharedFolderCallable? callFunction})
    : _call = callFunction ?? _callFunction;

  final FirestoreClient _firestoreClient;
  final SharedFolderCallable _call;

  static Future<Object?> _callFunction(String name, Map<String, Object?> data) async =>
      (await appFunctions.httpsCallable(name).call<Object?>(data)).data;

  Future<Result<T>> _guard<T>(String what, Future<T> Function() body) async {
    try {
      return Result.success(await body());
    } catch (error, stackTrace) {
      logger.w('Shared folders: could not $what', tag: 'Folders', error: error, stackTrace: stackTrace);
      return Result.error(sharedFolderFailure(error));
    }
  }

  @override
  Future<Result<FolderInvite>> createInvite(String folderId) => _guard('create an invite', () async {
    final Object? data = await _call('createFolderInvite', <String, Object?>{'folderId': folderId});
    final Map<Object?, Object?> map = data is Map ? data : const <Object?, Object?>{};
    final String code = parseString(map['code']);
    final Object? expires = map['expiresAtMs'];
    if (code.isEmpty || expires is! num) throw StateError('createFolderInvite returned no code.');
    return FolderInvite(
      code: code,
      folderId: folderId,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(expires.toInt(), isUtc: true),
    );
  });

  @override
  Future<Result<FolderInvitePreview>> previewInvite(String code) => _guard(
    'load an invite',
    () async => folderInvitePreviewFrom(await _call('getFolderInvite', <String, Object?>{'code': code})),
  );

  @override
  Future<Result<String>> join(String code) => _guard('join a folder', () async {
    final Object? data = await _call('joinFolder', <String, Object?>{'code': code});
    final String folderId = data is Map ? parseString(data['folderId']) : '';
    if (folderId.isEmpty) throw StateError('joinFolder returned no folder.');
    return folderId;
  });

  @override
  Future<Result<void>> removeMember(String folderId, String uid) =>
      _guard('remove a member', () => _call('removeFolderMember', <String, Object?>{'folderId': folderId, 'uid': uid}));

  @override
  Future<Result<void>> leave(String folderId) =>
      _guard('leave a folder', () => _call('leaveFolder', <String, Object?>{'folderId': folderId}));

  @override
  Future<Result<String?>> addedBy(String folderId, String itemKey) => _guard(
    'read who added a wall',
    () => _firestoreClient.getById<String>(
      FirebaseCollections.folderItems(folderId),
      itemKey,
      (data, _) => parseString(data['addedBy'], fallback: parseString(data['ownerId'])),
      sourceTag: 'shared_folders.added_by',
    ),
  );
}
