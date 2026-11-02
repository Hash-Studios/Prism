import 'package:Prism/core/user_blocks/blocked_creators.dart';
import 'package:Prism/features/wall_comments/biz/wall_comments_cubit.dart';
import 'package:Prism/features/wall_comments/data/wall_comments_repository.dart';
import 'package:Prism/features/wall_comments/domain/wall_comment.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_wall_comments_repository.dart';

const CommentViewer _me = (uid: 'me', name: 'Me', photo: '');

WallCommentsCubit _cubit(FakeWallCommentsRepository repo, {CommentViewer? viewer = _me, BlockedCreators? blocked}) {
  final WallCommentsCubit cubit = WallCommentsCubit(
    wallId: 'w1',
    repository: repo,
    viewer: viewer,
    initialBlocked: blocked ?? KnownBlockedCreators(const <String>{}),
    newRequestId: () => 'req-1',
  );
  addTearDown(cubit.close);
  return cubit;
}

List<WallComment> _twenty() =>
    List<WallComment>.generate(WallCommentsRepository.pageSize, (i) => commentFor('c${i + 1}'));

void main() {
  group('load and paging', () {
    test('a full first page sets hasMore and requests the first page', () async {
      final FakeWallCommentsRepository repo = FakeWallCommentsRepository()
        ..onFetch = (String wallId, String? afterId) async => pageOf(_twenty());
      final WallCommentsCubit cubit = _cubit(repo);

      await cubit.load();

      expect(cubit.state.status, CommentsStatus.ready);
      expect(cubit.state.comments, hasLength(20));
      expect(cubit.state.hasMore, isTrue);
      expect(repo.fetchAfterIds, <String?>[null]);
    });

    test('loadMore appends the next page and passes the last id as afterId', () async {
      final List<WallComment> second = <WallComment>[commentFor('c21'), commentFor('c22'), commentFor('c23')];
      final FakeWallCommentsRepository repo = FakeWallCommentsRepository()
        ..onFetch = (String wallId, String? afterId) async => afterId == null ? pageOf(_twenty()) : pageOf(second);
      final WallCommentsCubit cubit = _cubit(repo);
      await cubit.load();

      await cubit.loadMore();

      expect(repo.fetchAfterIds, <String?>[null, 'c20']);
      expect(cubit.state.comments, hasLength(23));
      expect(cubit.state.comments.last.id, 'c23');
      expect(cubit.state.hasMore, isFalse);
      expect(cubit.state.loadingMore, isFalse);
    });

    test('a short page sets hasMore false', () async {
      final FakeWallCommentsRepository repo = FakeWallCommentsRepository()
        ..onFetch = (String wallId, String? afterId) async =>
            pageOf(<WallComment>[for (int i = 1; i <= 5; i++) commentFor('s$i')]);
      final WallCommentsCubit cubit = _cubit(repo);

      await cubit.load();

      expect(cubit.state.comments, hasLength(5));
      expect(cubit.state.hasMore, isFalse);
    });

    test('a failed load sets status failed', () async {
      final FakeWallCommentsRepository repo = FakeWallCommentsRepository()
        ..onFetch = (String wallId, String? afterId) async => throw StateError('offline');
      final WallCommentsCubit cubit = _cubit(repo);

      await cubit.load();

      expect(cubit.state.status, CommentsStatus.failed);
      expect(cubit.state.comments, isEmpty);
    });
  });

  group('send', () {
    test('shows a pending row and sending while the add is pending', () async {
      final FakeWallCommentsRepository repo = FakeWallCommentsRepository();
      final WallCommentsCubit cubit = _cubit(repo);

      final Future<CommentRefusal?> sending = cubit.send('Hello');

      expect(cubit.state.comments.first.pending, isTrue);
      expect(cubit.state.comments.first.text, 'Hello');
      expect(cubit.state.sending, isTrue);
      expect(repo.adds, hasLength(1));

      repo.adds.single.result.complete(
        WallComment(
          id: 'srv1',
          authorUid: 'me',
          authorName: 'Me',
          authorPhoto: '',
          text: 'Hello',
          createdAt: DateTime.now(),
        ),
      );
      expect(await sending, isNull);
    });

    test('a success replaces the pending row with the server comment', () async {
      final FakeWallCommentsRepository repo = FakeWallCommentsRepository();
      final WallCommentsCubit cubit = _cubit(repo);

      final Future<CommentRefusal?> sending = cubit.send('Hello');
      repo.adds.single.result.complete(
        WallComment(
          id: 'srv1',
          authorUid: 'me',
          authorName: 'Me',
          authorPhoto: '',
          text: 'Hello',
          createdAt: DateTime.now(),
        ),
      );
      await sending;

      expect(cubit.state.comments, hasLength(1));
      expect(cubit.state.comments.first.id, 'srv1');
      expect(cubit.state.comments.first.pending, isFalse);
      expect(cubit.state.sending, isFalse);
    });

    test('a blocked-word refusal removes the pending row and returns the refusal', () async {
      final FakeWallCommentsRepository repo = FakeWallCommentsRepository();
      final WallCommentsCubit cubit = _cubit(repo);

      final Future<CommentRefusal?> sending = cubit.send('Hello');
      repo.adds.single.result.completeError(const CommentRefusedException(CommentRefusal.blockedWord));

      expect(await sending, CommentRefusal.blockedWord);
      expect(cubit.state.comments, isEmpty);
      expect(cubit.state.sending, isFalse);
    });

    test('a second send while sending returns null and does not call add', () async {
      final FakeWallCommentsRepository repo = FakeWallCommentsRepository();
      final WallCommentsCubit cubit = _cubit(repo);

      final Future<CommentRefusal?> first = cubit.send('first');
      final CommentRefusal? second = await cubit.send('second');

      expect(second, isNull);
      expect(repo.adds, hasLength(1));
      expect(repo.adds.single.text, 'first');

      repo.adds.single.result.completeError(const CommentRefusedException(CommentRefusal.tooFast));
      await first;
    });
  });

  group('delete', () {
    test('removes the row at once and keeps it removed when the delete succeeds', () async {
      final FakeWallCommentsRepository repo = FakeWallCommentsRepository()
        ..onFetch = (String wallId, String? afterId) async => pageOf(<WallComment>[commentFor('c1'), commentFor('c2')]);
      final WallCommentsCubit cubit = _cubit(repo);
      await cubit.load();

      final Future<bool> deleting = cubit.delete(cubit.state.comments.first);

      expect(cubit.state.comments.map((WallComment c) => c.id), <String>['c2']);
      repo.deletes.single.result.complete();
      expect(await deleting, isTrue);
      expect(cubit.state.comments.map((WallComment c) => c.id), <String>['c2']);
    });

    test('a failed delete puts the row back and returns false', () async {
      final FakeWallCommentsRepository repo = FakeWallCommentsRepository()
        ..onFetch = (String wallId, String? afterId) async => pageOf(<WallComment>[commentFor('c1'), commentFor('c2')]);
      final WallCommentsCubit cubit = _cubit(repo);
      await cubit.load();

      final Future<bool> deleting = cubit.delete(cubit.state.comments.first);
      repo.deletes.single.result.completeError(StateError('denied'));

      expect(await deleting, isFalse);
      expect(cubit.state.comments.map((WallComment c) => c.id), <String>['c1', 'c2']);
    });
  });

  group('shown', () {
    final List<WallComment> mixed = <WallComment>[
      commentFor('c1', uid: 'bad'),
      commentFor('c2', uid: 'me'),
      commentFor('c3', uid: 'ok'),
    ];

    test('hides comments by a blocked creator and keeps the viewer own', () async {
      final FakeWallCommentsRepository repo = FakeWallCommentsRepository()
        ..onFetch = (String wallId, String? afterId) async => pageOf(mixed);
      final WallCommentsCubit cubit = _cubit(repo, blocked: KnownBlockedCreators(const <String>{'bad'}));

      await cubit.load();

      expect(cubit.state.shown.map((WallComment c) => c.id), <String>['c2', 'c3']);
    });

    test('keeps the viewer own comment even when the viewer uid is in the block list', () async {
      final FakeWallCommentsRepository repo = FakeWallCommentsRepository()
        ..onFetch = (String wallId, String? afterId) async => pageOf(mixed);
      final WallCommentsCubit cubit = _cubit(repo, blocked: KnownBlockedCreators(const <String>{'bad', 'me'}));

      await cubit.load();

      expect(cubit.state.shown.map((WallComment c) => c.id), <String>['c2', 'c3']);
    });

    test('a guest sees every comment', () async {
      final FakeWallCommentsRepository repo = FakeWallCommentsRepository()
        ..onFetch = (String wallId, String? afterId) async => pageOf(mixed);
      final WallCommentsCubit cubit = _cubit(repo, viewer: null, blocked: KnownBlockedCreators(const <String>{'bad'}));

      await cubit.load();

      expect(cubit.state.shown.map((WallComment c) => c.id), <String>['c1', 'c2', 'c3']);
    });
  });
}
