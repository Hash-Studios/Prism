import 'dart:async';

import 'package:Prism/features/favourite_walls/domain/repositories/favourite_counts_repository.dart';
import 'package:Prism/features/wall_comments/data/wall_comments_repository.dart';
import 'package:Prism/features/wall_comments/domain/wall_comment.dart';

typedef CommentPage = ({List<WallComment> items, bool hasMore});

typedef PendingAdd = ({String text, String requestId, Completer<WallComment> result});

typedef PendingDelete = ({String commentId, Completer<void> result});

/// A page built the way the real repository builds it: a full page may have more behind it.
CommentPage pageOf(List<WallComment> items) => (items: items, hasMore: items.length == WallCommentsRepository.pageSize);

/// A comment written now, so its relative time reads "now".
WallComment commentFor(String id, {String uid = 'bob', String name = 'Bob', String text = 'Nice wall'}) =>
    WallComment(id: id, authorUid: uid, authorName: name, authorPhoto: '', text: text, createdAt: DateTime.now());

/// Stands in for the Firestore reads and the comment callables. Each add and delete waits on a Completer the test
/// completes, so the test controls when the server answers.
class FakeWallCommentsRepository implements WallCommentsRepository {
  /// The afterId of each fetchPage call, in order. Null is the first page.
  final List<String?> fetchAfterIds = <String?>[];

  /// Answers each page request. The default is an empty first page.
  Future<CommentPage> Function(String wallId, String? afterId) onFetch = (String wallId, String? afterId) async =>
      pageOf(const <WallComment>[]);

  final List<PendingAdd> adds = <PendingAdd>[];
  final List<PendingDelete> deletes = <PendingDelete>[];

  @override
  Future<CommentPage> fetchPage(String wallId, {String? afterId}) {
    fetchAfterIds.add(afterId);
    return onFetch(wallId, afterId);
  }

  @override
  Future<WallComment> add({required String wallId, required String text, required String requestId}) {
    final Completer<WallComment> result = Completer<WallComment>();
    adds.add((text: text, requestId: requestId, result: result));
    return result.future;
  }

  @override
  Future<void> delete({required String wallId, required String commentId}) {
    final Completer<void> result = Completer<void>();
    deletes.add((commentId: commentId, result: result));
    return result.future;
  }

  @override
  Future<void> setHidden({required String wallId, required String commentId, required bool hidden}) async {}
}

/// Answers every requested stats id with zero favourites and no comments, so the count cubit has a state to hold.
class FakeFavouriteCountsRepository implements FavouriteCountsRepository {
  @override
  Future<Map<String, PrismWallpaperStats>> fetch(Set<String> ids) async => <String, PrismWallpaperStats>{
    for (final String id in ids) id: const PrismWallpaperStats(favourites: 0),
  };
}
