import 'dart:async';
import 'dart:math';

import 'package:Prism/core/user_blocks/blocked_creators.dart';
import 'package:Prism/features/wall_comments/data/wall_comments_repository.dart';
import 'package:Prism/features/wall_comments/domain/wall_comment.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum CommentsStatus { loading, ready, failed }

/// The signed-in viewer, or none for a guest. Used for the optimistic row and to keep own comments visible.
typedef CommentViewer = ({String uid, String name, String photo});

final class WallCommentsState {
  const WallCommentsState({
    this.status = CommentsStatus.loading,
    this.comments = const <WallComment>[],
    this.hasMore = false,
    this.loadingMore = false,
    this.sending = false,
    this.blocked = const UnknownBlockedCreators(),
    this.viewerUid = '',
  });

  final CommentsStatus status;
  final List<WallComment> comments;
  final bool hasMore;
  final bool loadingMore;
  final bool sending;
  final BlockedCreators blocked;
  final String viewerUid;

  /// What the sheet lists: no comment by a user the viewer blocked. A guest has no block list.
  List<WallComment> get shown => viewerUid.isEmpty
      ? comments
      : comments.where((c) => c.authorUid == viewerUid || !blocked.blocks(c.authorUid)).toList(growable: false);

  WallCommentsState copyWith({
    CommentsStatus? status,
    List<WallComment>? comments,
    bool? hasMore,
    bool? loadingMore,
    bool? sending,
    BlockedCreators? blocked,
  }) => WallCommentsState(
    status: status ?? this.status,
    comments: comments ?? this.comments,
    hasMore: hasMore ?? this.hasMore,
    loadingMore: loadingMore ?? this.loadingMore,
    sending: sending ?? this.sending,
    blocked: blocked ?? this.blocked,
    viewerUid: viewerUid,
  );
}

/// One wall's comments: pages newest first, an optimistic add with rollback, and delete.
class WallCommentsCubit extends Cubit<WallCommentsState> {
  WallCommentsCubit({
    required this.wallId,
    required WallCommentsRepository repository,
    required CommentViewer? viewer,
    Stream<BlockedCreators>? blockedCreators,
    BlockedCreators initialBlocked = const UnknownBlockedCreators(),
    String Function()? newRequestId,
  }) : _repository = repository,
       _viewer = viewer,
       _newRequestId = newRequestId ?? _randomRequestId,
       super(WallCommentsState(viewerUid: viewer?.uid ?? '', blocked: initialBlocked)) {
    _blockSub = blockedCreators?.listen((BlockedCreators b) {
      if (!isClosed) emit(state.copyWith(blocked: b));
    });
  }

  final String wallId;
  final WallCommentsRepository _repository;
  final CommentViewer? _viewer;
  final String Function() _newRequestId;
  StreamSubscription<BlockedCreators>? _blockSub;

  static String _randomRequestId() {
    final Random random = Random.secure();
    return '${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}'
        '${List<String>.generate(16, (_) => random.nextInt(36).toRadixString(36)).join()}';
  }

  Future<void> load() async {
    emit(state.copyWith(status: CommentsStatus.loading));
    try {
      final page = await _repository.fetchPage(wallId);
      if (isClosed) return;
      emit(state.copyWith(status: CommentsStatus.ready, comments: page.items, hasMore: page.hasMore));
    } catch (_) {
      if (!isClosed) emit(state.copyWith(status: CommentsStatus.failed));
    }
  }

  Future<void> loadMore() async {
    final String? afterId = state.comments.where((c) => !c.pending).lastOrNull?.id;
    if (state.status != CommentsStatus.ready || !state.hasMore || state.loadingMore || afterId == null) return;
    emit(state.copyWith(loadingMore: true));
    try {
      final page = await _repository.fetchPage(wallId, afterId: afterId);
      if (isClosed) return;
      final Set<String> have = state.comments.map((c) => c.id).toSet();
      emit(
        state.copyWith(
          comments: <WallComment>[...state.comments, ...page.items.where((c) => !have.contains(c.id))],
          hasMore: page.hasMore,
          loadingMore: false,
        ),
      );
    } catch (_) {
      if (!isClosed) emit(state.copyWith(loadingMore: false));
    }
  }

  /// Shows the comment at once and posts it. Returns null when it posted, or why the server refused it; the
  /// optimistic row is gone again in that case.
  Future<CommentRefusal?> send(String text) async {
    final CommentViewer? viewer = _viewer;
    if (state.sending || viewer == null) return null;
    final String requestId = _newRequestId();
    final WallComment pending = WallComment(
      id: 'pending_$requestId',
      authorUid: viewer.uid,
      authorName: viewer.name,
      authorPhoto: viewer.photo,
      text: text.trim(),
      createdAt: DateTime.now(),
      pending: true,
    );
    emit(state.copyWith(sending: true, comments: <WallComment>[pending, ...state.comments]));
    try {
      final WallComment posted = await _repository.add(wallId: wallId, text: text, requestId: requestId);
      if (isClosed) return null;
      emit(
        state.copyWith(
          sending: false,
          comments: <WallComment>[
            for (final WallComment c in state.comments)
              if (c.id == pending.id) posted else if (c.id != posted.id) c,
          ],
        ),
      );
      return null;
    } on CommentRefusedException catch (e) {
      _rollback(pending.id);
      return e.refusal;
    } catch (_) {
      _rollback(pending.id);
      return CommentRefusal.failed;
    }
  }

  void _rollback(String pendingId) {
    if (isClosed) return;
    emit(state.copyWith(sending: false, comments: state.comments.where((c) => c.id != pendingId).toList()));
  }

  /// Removes the row at once and puts it back if the delete fails. Returns whether it was deleted.
  Future<bool> delete(WallComment comment) async {
    final List<WallComment> before = state.comments;
    emit(state.copyWith(comments: before.where((c) => c.id != comment.id).toList()));
    try {
      await _repository.delete(wallId: wallId, commentId: comment.id);
      return true;
    } catch (_) {
      if (!isClosed) emit(state.copyWith(comments: before));
      return false;
    }
  }

  @override
  Future<void> close() {
    unawaited(_blockSub?.cancel());
    return super.close();
  }
}
