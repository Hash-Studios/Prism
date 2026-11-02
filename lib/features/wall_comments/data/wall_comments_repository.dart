import 'package:Prism/core/constants/app_functions.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/features/wall_comments/domain/wall_comment.dart';
import 'package:cloud_functions/cloud_functions.dart' as cf;
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

typedef CommentCaller = Future<Object?> Function(String name, Map<String, Object?> data);

/// A refusal from the add call, or a failed call.
final class CommentRefusedException implements Exception {
  const CommentRefusedException(this.refusal);

  final CommentRefusal refusal;
}

/// Reads visible comments from Firestore. Every write goes through the comment callables.
@lazySingleton
class WallCommentsRepository {
  WallCommentsRepository(this._client) : _call = _callable;

  @visibleForTesting
  WallCommentsRepository.withCaller(this._client, this._call);

  static const int pageSize = 20;

  final FirestoreClient _client;
  final CommentCaller _call;

  static Future<Object?> _callable(String name, Map<String, Object?> data) async =>
      (await appFunctions
              .httpsCallable(name, options: cf.HttpsCallableOptions(timeout: const Duration(seconds: 20)))
              .call<Object?>(data))
          .data;

  /// Newest first. [after] is the last comment of the previous page.
  Future<({List<WallComment> items, bool hasMore})> fetchPage(String wallId, {WallComment? after}) async {
    final List<WallComment> items = await _client.query<WallComment>(
      FirestoreQuerySpec(
        collection: FirebaseCollections.wallComments(wallId),
        sourceTag: 'wall_comments.page',
        filters: const <FirestoreFilter>[
          FirestoreFilter(field: 'state', op: FirestoreFilterOp.isEqualTo, value: 'visible'),
        ],
        orderBy: const <FirestoreOrderBy>[
          FirestoreOrderBy(field: 'createdAt', descending: true),
          FirestoreOrderBy(field: firestoreDocumentIdField, descending: true),
        ],
        limit: pageSize,
        startAfterFieldValues: after == null ? null : <Object?>[after.createdAt, after.id],
        cachePolicy: FirestoreCachePolicy.serverOnly,
      ),
      WallComment.fromMap,
    );
    return (items: items, hasMore: items.length == pageSize);
  }

  /// Posts a comment. Throws [CommentRefusedException] when the server refuses it or the call fails.
  Future<WallComment> add({required String wallId, required String text, required String requestId}) async {
    final Object? raw;
    try {
      raw = await _call('addComment', <String, Object?>{'wallId': wallId, 'text': text, 'requestId': requestId});
    } on cf.FirebaseFunctionsException catch (e) {
      throw CommentRefusedException(e.code == 'unauthenticated' ? CommentRefusal.guest : CommentRefusal.failed);
    } catch (_) {
      throw const CommentRefusedException(CommentRefusal.failed);
    }
    if (raw is! Map) throw const CommentRefusedException(CommentRefusal.failed);
    final Object? comment = raw['comment'];
    if (raw['ok'] == true && comment is Map) {
      final Map<String, dynamic> data = Map<String, dynamic>.from(comment);
      return WallComment.fromMap(data, data['id'] is String ? data['id'] as String : '');
    }
    throw CommentRefusedException(CommentRefusal.fromWire(raw['reason']));
  }

  /// Deletes a comment as its author, the wall's creator or an admin. Throws when the server refuses.
  Future<void> delete({required String wallId, required String commentId}) =>
      _call('deleteComment', <String, Object?>{'wallId': wallId, 'commentId': commentId});

  /// Admin only: shows a comment that reports hid, or hides one.
  Future<void> setHidden({required String wallId, required String commentId, required bool hidden}) =>
      _call('setCommentHidden', <String, Object?>{'wallId': wallId, 'commentId': commentId, 'hidden': hidden});
}
