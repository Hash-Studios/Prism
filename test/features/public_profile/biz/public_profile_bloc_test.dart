import 'dart:async';

import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/public_profile/biz/bloc/public_profile_bloc.j.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_wall_entity.dart';
import 'package:Prism/features/public_profile/domain/entities/user_relation_kind.dart';
import 'package:Prism/features/public_profile/domain/entities/user_summary_entity.dart';
import 'package:Prism/features/public_profile/domain/usecases/public_profile_usecases.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/profile_user_fixture.dart';

class _MockWalls extends Mock implements FetchPublicProfileWallsUseCase {}

class _MockFollow extends Mock implements FollowUserUseCase {}

class _MockUnfollow extends Mock implements UnfollowUserUseCase {}

class _MockSummaries extends Mock implements FetchUserSummariesPageUseCase {}

class _MockSearch extends Mock implements SearchUsersByUsernameUseCase {}

PublicProfileWallEntity _wall(String id) => PublicProfileWallEntity(id: id, wallpaperUrl: 'https://x/$id');

UserSummaryEntity _user(String email, {bool followed = false}) => UserSummaryEntity(
  id: email,
  email: email,
  name: '',
  username: email,
  profilePhoto: '',
  isFollowedByCurrentUser: followed,
);

typedef _Summaries = ({List<UserSummaryEntity> items, bool hasMore});
typedef _Walls = ({List<PublicProfileWallEntity> items, bool hasMore});

void main() {
  setUpAll(() {
    registerFallbackValue(const FetchPublicProfileWallsParams(email: '', refresh: false));
    registerFallbackValue(const FetchUserSummariesPageParams(allEmails: <String>[], page: 0));
    registerFallbackValue(const SearchUsersByUsernameParams(query: '', scopeEmails: <String>[]));
    registerFallbackValue(
      const UnfollowUserParams(currentUserId: '', currentUserEmail: '', targetUserId: '', targetUserEmail: ''),
    );
    registerFallbackValue(
      const FollowUserParams(currentUserId: '', currentUserEmail: '', targetUserId: '', targetUserEmail: ''),
    );
  });

  late _MockWalls walls;
  late _MockFollow follow;
  late _MockUnfollow unfollow;
  late _MockSummaries summaries;
  late _MockSearch search;

  setUp(() {
    walls = _MockWalls();
    follow = _MockFollow();
    unfollow = _MockUnfollow();
    summaries = _MockSummaries();
    search = _MockSearch();
  });

  PublicProfileBloc buildBloc() => PublicProfileBloc(walls, follow, unfollow, summaries, search);

  final loading = PublicProfileState.initial().copyWith(email: 'a@x.com', status: LoadStatus.loading);

  blocTest<PublicProfileBloc, PublicProfileState>(
    'started clears the grid, then shows the first page of walls',
    build: () {
      when(() => walls(any())).thenAnswer((_) async => Result.success<_Walls>((items: [_wall('w1')], hasMore: true)));
      return buildBloc();
    },
    act: (bloc) => bloc.add(const PublicProfileEvent.started(email: 'a@x.com')),
    expect: () => <Matcher>[
      equals(loading),
      isA<PublicProfileState>()
          .having((s) => s.status, 'status', LoadStatus.success)
          .having((s) => s.walls.map((w) => w.id), 'walls', <String>['w1'])
          .having((s) => s.hasMoreWalls, 'hasMoreWalls', isTrue),
    ],
    verify: (_) => verify(
      () => walls(
        any(
          that: isA<FetchPublicProfileWallsParams>().having((p) => (p.email, p.refresh), 'email, refresh', (
            'a@x.com',
            true,
          )),
        ),
      ),
    ).called(1),
  );

  blocTest<PublicProfileBloc, PublicProfileState>(
    'a failed wall load with nothing to show ends in failure so the page can offer Retry',
    build: () {
      when(() => walls(any())).thenAnswer((_) async => Result.error<_Walls>(const ServerFailure('boom')));
      return buildBloc();
    },
    act: (bloc) => bloc.add(const PublicProfileEvent.started(email: 'a@x.com')),
    expect: () => <Matcher>[
      equals(loading),
      isA<PublicProfileState>()
          .having((s) => s.status, 'status', LoadStatus.failure)
          .having((s) => s.walls, 'walls', isEmpty),
    ],
  );

  blocTest<PublicProfileBloc, PublicProfileState>(
    'a failed refresh keeps the walls already on screen',
    build: () {
      when(() => walls(any())).thenAnswer((_) async => Result.error<_Walls>(const ServerFailure('boom')));
      return buildBloc();
    },
    seed: () => loading.copyWith(status: LoadStatus.success, walls: [_wall('w1')]),
    act: (bloc) => bloc.add(const PublicProfileEvent.refreshRequested()),
    verify: (bloc) {
      expect(bloc.state.status, LoadStatus.success);
      expect(bloc.state.walls.map((w) => w.id), <String>['w1']);
    },
  );

  blocTest<PublicProfileBloc, PublicProfileState>(
    'an empty email fails without fetching',
    build: buildBloc,
    act: (bloc) => bloc.add(const PublicProfileEvent.refreshRequested()),
    expect: () => <Matcher>[isA<PublicProfileState>().having((s) => s.status, 'status', LoadStatus.failure)],
    verify: (_) => verifyNever(() => walls(any())),
  );

  blocTest<PublicProfileBloc, PublicProfileState>(
    'fetchMoreWalls appends the next page without repeating a wall',
    build: () {
      when(
        () => walls(any()),
      ).thenAnswer((_) async => Result.success<_Walls>((items: [_wall('w2'), _wall('w3')], hasMore: false)));
      return buildBloc();
    },
    seed: () => loading.copyWith(status: LoadStatus.success, walls: [_wall('w1'), _wall('w2')]),
    act: (bloc) => bloc.add(const PublicProfileEvent.fetchMoreWallsRequested()),
    expect: () => <Matcher>[
      isA<PublicProfileState>().having((s) => s.isFetchingMoreWalls, 'isFetchingMoreWalls', isTrue),
      isA<PublicProfileState>()
          .having((s) => s.walls.map((w) => w.id), 'walls', <String>['w1', 'w2', 'w3'])
          .having((s) => s.hasMoreWalls, 'hasMoreWalls', isFalse)
          .having((s) => s.isFetchingMoreWalls, 'isFetchingMoreWalls', isFalse),
    ],
  );

  blocTest<PublicProfileBloc, PublicProfileState>(
    'fetchMoreWalls does nothing once the last page is in',
    build: buildBloc,
    seed: () => loading.copyWith(hasMoreWalls: false),
    act: (bloc) => bloc.add(const PublicProfileEvent.fetchMoreWallsRequested()),
    expect: () => <PublicProfileState>[],
    verify: (_) => verifyNever(() => walls(any())),
  );

  group('relation lists', () {
    blocTest<PublicProfileBloc, PublicProfileState>(
      'the first page replaces the list and a later page merges without repeats',
      build: () {
        final pages = <_Summaries>[
          (items: [_user('a@x.com'), _user('b@x.com')], hasMore: true),
          (items: [_user('B@x.com'), _user('c@x.com')], hasMore: false),
        ];
        when(() => summaries(any())).thenAnswer((_) async => Result.success<_Summaries>(pages.removeAt(0)));
        return buildBloc();
      },
      act: (bloc) async {
        bloc.add(
          const PublicProfileEvent.relationPageRequested(kind: UserRelationKind.followers, allEmails: ['x'], page: 0),
        );
        await pumpEventQueue();
        bloc.add(
          const PublicProfileEvent.relationPageRequested(kind: UserRelationKind.followers, allEmails: ['x'], page: 1),
        );
      },
      verify: (bloc) {
        expect(bloc.state.followers.summaries.map((u) => u.email), <String>['a@x.com', 'B@x.com', 'c@x.com']);
        expect(bloc.state.followers.page, 1);
        expect(bloc.state.followers.hasMore, isFalse);
        expect(bloc.state.followers.isFetching, isFalse);
        expect(bloc.state.following.summaries, isEmpty);
      },
    );

    blocTest<PublicProfileBloc, PublicProfileState>(
      'a page after the last one is not requested',
      build: buildBloc,
      act: (bloc) => bloc.add(
        const PublicProfileEvent.relationPageRequested(kind: UserRelationKind.following, allEmails: ['x'], page: 1),
      ),
      expect: () => <PublicProfileState>[],
      verify: (_) => verifyNever(() => summaries(any())),
    );

    test('only the newest search writes its results', () async {
      final first = Completer<Result<List<UserSummaryEntity>>>();
      final second = Completer<Result<List<UserSummaryEntity>>>();
      final answers = <Completer<Result<List<UserSummaryEntity>>>>[first, second];
      when(() => search(any())).thenAnswer((_) => answers.removeAt(0).future);
      final bloc = buildBloc();

      bloc
        ..add(
          const PublicProfileEvent.relationSearchRequested(
            kind: UserRelationKind.following,
            query: 'ke',
            allEmails: ['x'],
          ),
        )
        ..add(
          const PublicProfileEvent.relationSearchRequested(
            kind: UserRelationKind.following,
            query: 'kev',
            allEmails: ['x'],
          ),
        );
      await Future<void>.delayed(Duration.zero);
      second.complete(Result.success(<UserSummaryEntity>[_user('kevin@x.com')]));
      await Future<void>.delayed(Duration.zero);
      first.complete(Result.success(<UserSummaryEntity>[_user('kelly@x.com')]));
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.following.searchResults!.map((u) => u.email), <String>['kevin@x.com']);
      expect(bloc.state.following.isSearching, isFalse);
      expect(bloc.state.followers.searchResults, isNull);
      await bloc.close();
    });

    blocTest<PublicProfileBloc, PublicProfileState>(
      'a failed search shows no results, and clearing returns to the list',
      build: () {
        when(
          () => search(any()),
        ).thenAnswer((_) async => Result.error<List<UserSummaryEntity>>(const ServerFailure('x')));
        return buildBloc();
      },
      act: (bloc) async {
        bloc.add(
          const PublicProfileEvent.relationSearchRequested(
            kind: UserRelationKind.followers,
            query: 'ke',
            allEmails: ['x'],
          ),
        );
        await Future<void>.delayed(Duration.zero);
        expect(bloc.state.followers.searchResults, isEmpty);
        bloc.add(const PublicProfileEvent.relationSearchCleared(kind: UserRelationKind.followers));
      },
      verify: (bloc) {
        expect(bloc.state.followers.searchResults, isNull);
        expect(bloc.state.followers.isSearching, isFalse);
      },
    );
  });

  const followEvent = PublicProfileEvent.followChangeRequested(
    follow: true,
    currentUserId: 'me',
    currentUserEmail: 'me@x.com',
    targetUserId: 'a-id',
    targetUserEmail: 'A@x.com',
    targetName: 'Ann',
  );

  blocTest<PublicProfileBloc, PublicProfileState>(
    'follow flips the button first, then reports success and records it on the session',
    setUp: () => app_state.prismUser = profileUser(),
    build: () {
      when(() => follow(any())).thenAnswer((_) async => Result.success<void>(null));
      return buildBloc();
    },
    seed: () => loading.copyWith(followers: loading.followers.copyWith(summaries: [_user('a@x.com')])),
    act: (bloc) => bloc.add(followEvent),
    expect: () => <Matcher>[
      isA<PublicProfileState>()
          .having((s) => s.followOverrides, 'overrides', <String, bool>{'a@x.com': true})
          .having((s) => s.followers.summaries.single.isFollowedByCurrentUser, 'row', isTrue)
          .having((s) => s.followOutcome, 'outcome', isNull),
      isA<PublicProfileState>().having(
        (s) => s.followOutcome,
        'outcome',
        const FollowOutcome(id: 1, follow: true, success: true, targetName: 'Ann'),
      ),
    ],
    verify: (_) {
      expect(app_state.prismUser.following, contains('A@x.com'));
      verify(
        () => follow(
          any(
            that: isA<FollowUserParams>().having((p) => (p.currentUserId, p.targetUserEmail), 'ids', ('me', 'A@x.com')),
          ),
        ),
      ).called(1);
    },
  );

  blocTest<PublicProfileBloc, PublicProfileState>(
    'unfollow removes the creator from the session whatever the email case',
    setUp: () => app_state.prismUser = profileUser()..following = <String>['a@X.com', 'b@x.com'],
    build: () {
      when(() => unfollow(any())).thenAnswer((_) async => Result.success<void>(null));
      return buildBloc();
    },
    act: (bloc) => bloc.add(
      const PublicProfileEvent.followChangeRequested(
        follow: false,
        currentUserId: 'me',
        currentUserEmail: 'me@x.com',
        targetUserId: 'a-id',
        targetUserEmail: 'A@x.com',
      ),
    ),
    verify: (bloc) {
      expect(app_state.prismUser.following, <String>['b@x.com']);
      expect(bloc.state.followOutcome?.success, isTrue);
    },
  );

  blocTest<PublicProfileBloc, PublicProfileState>(
    'a failed follow rolls the button back, keeps the session as it was and reports the failure',
    setUp: () => app_state.prismUser = profileUser(),
    build: () {
      when(() => follow(any())).thenAnswer((_) async => Result.error<void>(const ServerFailure('offline')));
      return buildBloc();
    },
    seed: () => loading.copyWith(followers: loading.followers.copyWith(summaries: [_user('a@x.com')])),
    act: (bloc) => bloc.add(followEvent),
    expect: () => <Matcher>[
      isA<PublicProfileState>().having((s) => s.followers.summaries.single.isFollowedByCurrentUser, 'row', isTrue),
      isA<PublicProfileState>()
          .having((s) => s.followers.summaries.single.isFollowedByCurrentUser, 'row', isFalse)
          .having((s) => s.followOverrides, 'overrides', isEmpty)
          .having((s) => s.followOutcome?.success, 'success', isFalse)
          .having((s) => s.followOutcome?.follow, 'follow', isTrue),
    ],
    verify: (_) {
      expect(app_state.prismUser.following, isEmpty);
      verifyNever(() => unfollow(any()));
    },
  );

  test('withFollowState flips one user, matching the email in any case, in the list and its search results', () {
    final list = RelationList(summaries: [_user('a@x.com'), _user('b@x.com')], searchResults: [_user('A@x.com')]);

    final next = list.withFollowState('a@X.com', isFollowed: true);

    expect(next.summaries.map((u) => u.isFollowedByCurrentUser), <bool>[true, false]);
    expect(next.searchResults!.single.isFollowedByCurrentUser, isTrue);
    expect(list.summaries.first.isFollowedByCurrentUser, isFalse);
  });
}
