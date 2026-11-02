import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/public_profile/biz/bloc/public_profile_bloc.j.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_wall_entity.dart';
import 'package:Prism/features/public_profile/domain/entities/user_relation_kind.dart';
import 'package:Prism/features/public_profile/domain/entities/user_summary_entity.dart';
import 'package:Prism/features/public_profile/domain/usecases/public_profile_usecases.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/coins_test_backend.dart';
import '../../../support/fake_app_analytics.dart';
import '../../../support/in_memory_local_store.dart';
import '../../../support/profile_user_fixture.dart';

class _MockWalls extends Mock implements FetchPublicProfileWallsUseCase {}

class _MockFollow extends Mock implements FollowUserUseCase {}

class _MockUnfollow extends Mock implements UnfollowUserUseCase {}

class _MockSummaries extends Mock implements FetchUserSummariesPageUseCase {}

class _MockSearch extends Mock implements SearchUsersByUsernameUseCase {}

class _Messaging {
  final List<(bool, String)> calls = <(bool, String)>[];
  final Set<String> subscriptions = <String>{};
  Completer<void>? subscribeGate;
  Completer<void>? subscribeStarted;

  Future<Object?> handle(MethodCall call) async {
    if (call.method == 'Messaging#getAPNSToken') {
      return <String, String>{'token': 'test-apns-token'};
    }
    final arguments = call.arguments as Map<Object?, Object?>;
    final topic = arguments['topic']! as String;
    switch (call.method) {
      case 'Messaging#subscribeToTopic':
        calls.add((true, topic));
        if (!(subscribeStarted?.isCompleted ?? true)) subscribeStarted!.complete();
        await subscribeGate?.future;
        subscriptions.add(topic);
      case 'Messaging#unsubscribeFromTopic':
        calls.add((false, topic));
        if (!(subscribeStarted?.isCompleted ?? true)) subscribeStarted!.complete();
        await subscribeGate?.future;
        subscriptions.remove(topic);
      default:
        throw StateError('Unexpected messaging call: ${call.method}');
    }
    return <String, Object?>{};
  }
}

PublicProfileWallEntity _wall(String id) => PublicProfileWallEntity(id: id, wallpaperUrl: 'https://x/$id');

UserSummaryEntity _user(String email, {String? id, bool followed = false}) => UserSummaryEntity(
  id: id ?? email,
  email: email,
  name: '',
  username: email,
  profilePhoto: '',
  isFollowedByCurrentUser: followed,
);

typedef _Summaries = ({List<UserSummaryEntity> items, bool hasMore});
typedef _Walls = ({List<PublicProfileWallEntity> items, bool hasMore});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messaging = _Messaging();
  setUpAll(() async {
    await CoinsTestBackend().install();
    await getIt.reset();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/firebase_messaging'),
      messaging.handle,
    );
    registerFallbackValue(profileUser());
    registerFallbackValue(const FetchPublicProfileWallsParams(userId: '', refresh: false));
    registerFallbackValue(const FetchUserSummariesPageParams(userIds: <String>[], page: 0));
    registerFallbackValue(const SearchUsersByUsernameParams(query: '', scopeUserIds: <String>[]));
    registerFallbackValue(
      const UnfollowUserParams(currentUserId: '', currentUserEmail: '', targetUserId: '', targetUserEmail: ''),
    );
    registerFallbackValue(
      const FollowUserParams(currentUserId: '', currentUserEmail: '', targetUserId: '', targetUserEmail: ''),
    );
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/firebase_messaging'),
      null,
    );
  });

  late _MockWalls walls;
  late _MockFollow follow;
  late _MockUnfollow unfollow;
  late _MockSummaries summaries;
  late _MockSearch search;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    AnalyticsRuntime.reset();
    walls = _MockWalls();
    follow = _MockFollow();
    unfollow = _MockUnfollow();
    summaries = _MockSummaries();
    search = _MockSearch();
    app_state.prismUser = profileUser(id: 'me')..email = 'me@x.com';
    getIt.registerSingleton<SettingsLocalDataSource>(SettingsLocalDataSource(InMemoryLocalStore()));
    messaging.calls.clear();
    messaging.subscriptions.clear();
    messaging.subscribeGate = null;
    messaging.subscribeStarted = null;
  });

  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    AnalyticsRuntime.reset();
    await getIt.reset();
    app_state.prismUser = profileUser(id: '', loggedIn: false);
  });

  PublicProfileBloc buildBloc() => PublicProfileBloc(walls, follow, unfollow, summaries, search);

  final loading = PublicProfileState.initial().copyWith(profileId: 'a@x.com', status: LoadStatus.loading);

  for (final bool failOld in <bool>[false, true]) {
    test('A → B → A ignores the old load ${failOld ? 'failure' : 'success'}', () async {
      final requests = <Completer<Result<_Walls>>>[];
      when(() => walls(any())).thenAnswer((_) {
        final request = Completer<Result<_Walls>>();
        requests.add(request);
        return request.future;
      });
      final bloc = buildBloc();
      addTearDown(bloc.close);
      for (final email in <String>['a@x.com', 'b@x.com', 'a@x.com']) {
        bloc.add(PublicProfileEvent.started(identifier: email));
        await pumpEventQueue();
      }
      requests[2].complete(Result.success<_Walls>((items: [_wall('new-a')], hasMore: true)));
      await pumpEventQueue();
      requests[1].complete(Result.success<_Walls>((items: [_wall('old-b')], hasMore: false)));
      requests[0].complete(
        failOld
            ? Result.error<_Walls>(const ServerFailure('old failure'))
            : Result.success<_Walls>((items: [_wall('old-a')], hasMore: false)),
      );
      await pumpEventQueue();
      expect(bloc.state.profileId, 'a@x.com');
      expect(bloc.state.status, LoadStatus.success);
      expect(bloc.state.walls.map((w) => w.id), ['new-a']);
      expect(bloc.state.hasMoreWalls, isTrue);
    });
  }

  test('refresh rejects paging while loading and invalidates an older page', () async {
    final page = Completer<Result<_Walls>>();
    final refreshed = Completer<Result<_Walls>>();
    var calls = 0;
    when(() => walls(any())).thenAnswer((_) {
      calls++;
      return switch (calls) {
        1 => Future.value(Result.success<_Walls>((items: [_wall('first')], hasMore: true))),
        2 => page.future,
        _ => refreshed.future,
      };
    });
    final bloc = buildBloc();
    addTearDown(bloc.close);
    bloc.add(const PublicProfileEvent.started(identifier: 'a@x.com'));
    await pumpEventQueue();
    bloc.add(const PublicProfileEvent.fetchMoreWallsRequested());
    await pumpEventQueue();
    bloc.add(const PublicProfileEvent.refreshRequested());
    await pumpEventQueue();
    bloc.add(const PublicProfileEvent.fetchMoreWallsRequested());
    await pumpEventQueue();
    expect(calls, 3);
    refreshed.complete(Result.success<_Walls>((items: [_wall('fresh')], hasMore: true)));
    await pumpEventQueue();
    page.complete(Result.success<_Walls>((items: [_wall('stale-page')], hasMore: false)));
    await pumpEventQueue();
    expect(bloc.state.walls.map((w) => w.id), ['fresh']);
    expect(bloc.state.hasMoreWalls, isTrue);
    expect(bloc.state.isFetchingMoreWalls, isFalse);
  });

  test('fetch more cannot duplicate a pending first page', () async {
    final initial = Completer<Result<_Walls>>();
    when(() => walls(any())).thenAnswer((_) => initial.future);
    final bloc = buildBloc();
    addTearDown(bloc.close);
    bloc.add(const PublicProfileEvent.started(identifier: 'a@x.com'));
    await pumpEventQueue();
    bloc.add(const PublicProfileEvent.fetchMoreWallsRequested());
    await pumpEventQueue();
    verify(() => walls(any())).called(1);
    initial.complete(Result.success<_Walls>((items: [_wall('first')], hasMore: true)));
    await pumpEventQueue();
    expect(bloc.state.walls.map((w) => w.id), ['first']);
  });

  blocTest<PublicProfileBloc, PublicProfileState>(
    'started clears the grid, then shows the first page of walls',
    build: () {
      when(() => walls(any())).thenAnswer((_) async => Result.success<_Walls>((items: [_wall('w1')], hasMore: true)));
      return buildBloc();
    },
    act: (bloc) => bloc.add(const PublicProfileEvent.started(identifier: 'a@x.com')),
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
          that: isA<FetchPublicProfileWallsParams>().having((p) => (p.userId, p.refresh), 'email, refresh', (
            'a@x.com',
            true,
          )),
        ),
      ),
    ).called(1),
  );

  blocTest<PublicProfileBloc, PublicProfileState>(
    'a failed first refresh keeps cached walls and a retry loads new walls',
    build: () {
      final results = <Result<_Walls>>[
        Result.error<_Walls>(const ServerFailure('boom')),
        Result.success<_Walls>((items: [_wall('w2')], hasMore: false)),
      ];
      when(() => walls(any())).thenAnswer((_) async => results.removeAt(0));
      return buildBloc();
    },
    seed: () => loading.copyWith(status: LoadStatus.success, walls: [_wall('cached')]),
    act: (bloc) async {
      bloc.add(const PublicProfileEvent.refreshRequested());
      await pumpEventQueue();
      bloc.add(const PublicProfileEvent.refreshRequested());
    },
    expect: () => <Matcher>[
      isA<PublicProfileState>().having((s) => s.status, 'status', LoadStatus.loading).having(
        (s) => s.walls.map((w) => w.id),
        'cached walls while loading',
        <String>['cached'],
      ),
      isA<PublicProfileState>().having((s) => s.status, 'status', LoadStatus.failure).having(
        (s) => s.walls.map((w) => w.id),
        'cached walls after failure',
        <String>['cached'],
      ),
      isA<PublicProfileState>().having((s) => s.status, 'status', LoadStatus.loading).having(
        (s) => s.walls.map((w) => w.id),
        'cached walls during retry',
        <String>['cached'],
      ),
      isA<PublicProfileState>().having((s) => s.status, 'status', LoadStatus.success).having(
        (s) => s.walls.map((w) => w.id),
        'retried walls',
        <String>['w2'],
      ),
    ],
  );

  blocTest<PublicProfileBloc, PublicProfileState>(
    'a failed initial wall load reports failure, then retry succeeds',
    build: () {
      final results = <Result<_Walls>>[
        Result.error<_Walls>(const ServerFailure('boom')),
        Result.success<_Walls>((items: [_wall('w1')], hasMore: false)),
      ];
      when(() => walls(any())).thenAnswer((_) async => results.removeAt(0));
      return buildBloc();
    },
    act: (bloc) async {
      bloc.add(const PublicProfileEvent.started(identifier: 'a@x.com'));
      await pumpEventQueue();
      bloc.add(const PublicProfileEvent.refreshRequested());
    },
    expect: () => <Matcher>[
      equals(loading),
      isA<PublicProfileState>().having((s) => s.status, 'status', LoadStatus.failure),
      equals(loading),
      isA<PublicProfileState>().having((s) => s.status, 'status', LoadStatus.success).having(
        (s) => s.walls.map((w) => w.id),
        'retried walls',
        <String>['w1'],
      ),
    ],
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
    'a failed next page exposes an error instead of silently retrying an empty filtered profile',
    build: () {
      when(() => walls(any())).thenAnswer((_) async => Result.error<_Walls>(const UnknownFailure('offline')));
      return buildBloc();
    },
    seed: () => loading.copyWith(status: LoadStatus.success, walls: [_wall('ai')], hasMoreWalls: true),
    act: (bloc) => bloc.add(const PublicProfileEvent.fetchMoreWallsRequested()),
    expect: () => <Matcher>[
      isA<PublicProfileState>().having((s) => s.isFetchingMoreWalls, 'isFetchingMoreWalls', isTrue),
      isA<PublicProfileState>()
          .having((s) => s.status, 'status', LoadStatus.failure)
          .having((s) => s.isFetchingMoreWalls, 'isFetchingMoreWalls', isFalse)
          .having((s) => s.walls.map((w) => w.id), 'walls', <String>['ai'])
          .having((s) => s.hasMoreWalls, 'hasMoreWalls', isTrue),
    ],
  );

  blocTest<PublicProfileBloc, PublicProfileState>(
    'a successful next-page retry clears the prior page failure',
    build: () {
      var calls = 0;
      when(() => walls(any())).thenAnswer((_) async {
        calls++;
        return calls == 1
            ? Result.error<_Walls>(const UnknownFailure('offline'))
            : Result.success<_Walls>((items: <PublicProfileWallEntity>[_wall('next')], hasMore: false));
      });
      return buildBloc();
    },
    seed: () =>
        loading.copyWith(status: LoadStatus.success, profileId: 'user', walls: [_wall('ai')], hasMoreWalls: true),
    act: (bloc) async {
      bloc.add(const PublicProfileEvent.fetchMoreWallsRequested());
      await Future<void>.delayed(const Duration(milliseconds: 10));
      bloc.add(const PublicProfileEvent.fetchMoreWallsRequested());
    },
    expect: () => <Matcher>[
      isA<PublicProfileState>().having((s) => s.isFetchingMoreWalls, 'fetching first page', isTrue),
      isA<PublicProfileState>()
          .having((s) => s.status, 'failed page status', LoadStatus.failure)
          .having((s) => s.isFetchingMoreWalls, 'first page complete', isFalse),
      isA<PublicProfileState>().having((s) => s.isFetchingMoreWalls, 'fetching retry', isTrue),
      isA<PublicProfileState>()
          .having((s) => s.status, 'retry status', LoadStatus.success)
          .having((s) => s.isFetchingMoreWalls, 'retry complete', isFalse)
          .having((s) => s.walls.map((wall) => wall.id), 'walls', <String>['ai', 'next']),
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
          (
            items: [
              _user('B@x.com', id: 'b@x.com'),
              _user('c@x.com'),
            ],
            hasMore: false,
          ),
        ];
        when(() => summaries(any())).thenAnswer((_) async => Result.success<_Summaries>(pages.removeAt(0)));
        return buildBloc();
      },
      act: (bloc) async {
        bloc.add(
          const PublicProfileEvent.relationPageRequested(kind: UserRelationKind.followers, userIds: ['x'], page: 0),
        );
        await pumpEventQueue();
        bloc.add(
          const PublicProfileEvent.relationPageRequested(kind: UserRelationKind.followers, userIds: ['x'], page: 1),
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
        const PublicProfileEvent.relationPageRequested(kind: UserRelationKind.following, userIds: ['x'], page: 1),
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
            userIds: ['x'],
          ),
        )
        ..add(
          const PublicProfileEvent.relationSearchRequested(
            kind: UserRelationKind.following,
            query: 'kev',
            userIds: ['x'],
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
            userIds: ['x'],
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

  const unfollowEvent = PublicProfileEvent.followChangeRequested(
    follow: false,
    currentUserId: 'me',
    currentUserEmail: 'me@x.com',
    targetUserId: 'a-id',
    targetUserEmail: 'A@x.com',
  );

  for (final bool failFirst in <bool>[false, true]) {
    for (final bool failLast in <bool>[false, true]) {
      test('follow then unfollow are ordered; first fails=$failFirst, last fails=$failLast', () async {
        final first = Completer<Result<void>>();
        final last = Completer<Result<void>>();
        when(() => follow(any())).thenAnswer((_) => first.future);
        when(() => unfollow(any())).thenAnswer((_) => last.future);
        when(
          () => summaries(any()),
        ).thenAnswer((_) async => Result.success<_Summaries>((items: [_user('A@x.com', id: 'a-id')], hasMore: false)));
        final bloc = buildBloc();
        addTearDown(bloc.close);
        bloc.add(
          const PublicProfileEvent.relationPageRequested(kind: UserRelationKind.followers, userIds: ['a-id'], page: 0),
        );
        await pumpEventQueue();
        bloc.add(followEvent);
        await pumpEventQueue();
        bloc.add(unfollowEvent);
        await pumpEventQueue();
        expect(bloc.state.followOverrides['a-id'], isFalse);
        verifyNever(() => unfollow(any()));
        first.complete(failFirst ? Result.error<void>(const ServerFailure('first')) : Result.success<void>(null));
        await pumpEventQueue();
        verify(() => unfollow(any())).called(1);
        expect(bloc.state.followOverrides['a-id'], isFalse);
        expect(bloc.state.followOutcome, isNull);
        last.complete(failLast ? Result.error<void>(const ServerFailure('last')) : Result.success<void>(null));
        await pumpEventQueue();
        final bool expectedFollow = failLast && !failFirst;
        expect(app_state.prismUser.following, isEmpty);
        expect(bloc.state.followOverrides['a-id'] ?? false, expectedFollow);
        expect(bloc.state.followers.summaries.single.isFollowedByCurrentUser, expectedFollow);
        expect(bloc.state.followOutcome?.follow, isFalse);
        expect(bloc.state.followOutcome?.success, !failLast);
        // New posts arrive in the follow digest, so a follow never joins the creator's posts topic.
        expect(messaging.subscriptions.contains('posts_a-id_loc_v1'), isFalse);
      });
    }
  }

  for (final bool returnToA in <bool>[false, true]) {
    test('follow completion cannot mutate a replacement session; return to A=$returnToA', () async {
      final pending = Completer<Result<void>>();
      when(() => follow(any())).thenAnswer((_) => pending.future);
      final bloc = buildBloc();
      addTearDown(bloc.close);
      bloc.add(followEvent);
      await pumpEventQueue();
      bloc.add(unfollowEvent);
      await pumpEventQueue();
      app_state.prismUser = profileUser(id: 'other');
      CoinsService.instance.resetSession();
      if (returnToA) {
        app_state.prismUser = profileUser(id: 'me')..email = 'me@x.com';
        CoinsService.instance.resetSession();
      }
      pending.complete(Result.success<void>(null));
      await pumpEventQueue();
      expect(app_state.prismUser.following, isEmpty);
      expect(bloc.state.followOutcome, isNull);
      expect(messaging.calls, isEmpty);
      verifyNever(() => unfollow(any()));
    });
  }

  for (final bool failFirst in <bool>[false, true]) {
    for (final bool failLast in <bool>[false, true]) {
      test('unfollow then follow are ordered; first fails=$failFirst, last fails=$failLast', () async {
        app_state.prismUser.following = ['A@x.com'];
        final first = Completer<Result<void>>();
        final last = Completer<Result<void>>();
        when(() => unfollow(any())).thenAnswer((_) => first.future);
        when(() => follow(any())).thenAnswer((_) => last.future);
        when(() => summaries(any())).thenAnswer(
          (_) async =>
              Result.success<_Summaries>((items: [_user('A@x.com', id: 'a-id', followed: true)], hasMore: false)),
        );
        final bloc = buildBloc();
        addTearDown(bloc.close);
        bloc.add(
          const PublicProfileEvent.relationPageRequested(kind: UserRelationKind.followers, userIds: ['a-id'], page: 0),
        );
        await pumpEventQueue();
        bloc.add(unfollowEvent);
        await pumpEventQueue();
        bloc.add(followEvent);
        await pumpEventQueue();
        verifyNever(() => follow(any()));
        first.complete(failFirst ? Result.error<void>(const ServerFailure('first')) : Result.success<void>(null));
        await pumpEventQueue();
        expect(bloc.state.followOverrides['a-id'], isTrue);
        expect(bloc.state.followOutcome, isNull);
        last.complete(failLast ? Result.error<void>(const ServerFailure('last')) : Result.success<void>(null));
        await pumpEventQueue();
        final bool expectedFollow = !failLast || failFirst;
        expect(app_state.prismUser.following, ['A@x.com']);
        expect(bloc.state.followOverrides['a-id'] ?? expectedFollow, expectedFollow);
        expect(bloc.state.followers.summaries.single.isFollowedByCurrentUser, expectedFollow);
        expect(bloc.state.followOutcome?.follow, isTrue);
        expect(bloc.state.followOutcome?.success, !failLast);
      });
    }
  }

  test('a rejected duplicate follow restores the actual followed state, not the inverse intent', () async {
    app_state.prismUser.following = ['A@x.com'];
    when(() => follow(any())).thenAnswer((_) async => Result.error<void>(const ServerFailure('offline')));
    final bloc = buildBloc();
    addTearDown(bloc.close);
    bloc.add(followEvent);
    await pumpEventQueue();
    expect(app_state.prismUser.following, ['A@x.com']);
    expect(bloc.state.followOutcome?.success, isFalse);
    expect(bloc.state.followOverrides, isEmpty);
    expect(messaging.calls, isEmpty);
  });

  test('closing with a follow pending suppresses late local effects and queued transactions', () async {
    final pending = Completer<Result<void>>();
    when(() => follow(any())).thenAnswer((_) => pending.future);
    when(() => unfollow(any())).thenAnswer((_) async => Result.success<void>(null));
    final bloc = buildBloc();
    bloc.add(followEvent);
    await pumpEventQueue();
    bloc.add(unfollowEvent);
    await pumpEventQueue();
    final closing = bloc.close();
    await pumpEventQueue();
    pending.complete(Result.success<void>(null));
    await closing;
    await pumpEventQueue();
    expect(app_state.prismUser.following, isEmpty);
    verifyNever(() => unfollow(any()));
    expect(messaging.calls, isEmpty);
  });

  test('returning to A keeps new intent ordered behind its earlier transaction', () async {
    final pending = Completer<Result<void>>();
    final calls = <String>[];
    when(() => follow(any())).thenAnswer((_) {
      calls.add('follow');
      return pending.future;
    });
    when(() => unfollow(any())).thenAnswer((_) async {
      calls.add('unfollow');
      return Result.success<void>(null);
    });
    final bloc = buildBloc();
    addTearDown(bloc.close);
    bloc.add(followEvent);
    await pumpEventQueue();
    app_state.prismUser = profileUser(id: 'other');
    CoinsService.instance.resetSession();
    app_state.prismUser = profileUser(id: 'me')..email = 'me@x.com';
    CoinsService.instance.resetSession();
    bloc.add(unfollowEvent);
    await pumpEventQueue();
    final bool wasQueued = calls.length == 1;
    pending.complete(Result.success<void>(null));
    await pumpEventQueue();
    expect(wasQueued, isTrue);
    expect(calls, ['follow', 'unfollow']);
    expect(app_state.prismUser.following, isEmpty);
    expect(bloc.state.followOutcome?.follow, isFalse);
    expect(messaging.subscriptions, isEmpty);
  });

  test('a pending topic change finishes before the next same-target transaction starts', () async {
    final gate = Completer<void>();
    messaging.subscribeGate = gate;
    when(() => follow(any())).thenAnswer((_) async => Result.success<void>(null));
    when(() => unfollow(any())).thenAnswer((_) async => Result.success<void>(null));
    final bloc = buildBloc();
    addTearDown(() async {
      if (!gate.isCompleted) gate.complete();
      await bloc.close();
    });
    bloc.add(unfollowEvent);
    await pumpEventQueue();
    expect(messaging.calls.any((call) => !call.$1), isTrue);
    bloc.add(followEvent);
    await pumpEventQueue();
    verifyNever(() => follow(any()));
    gate.complete();
    await pumpEventQueue();
    verify(() => follow(any())).called(1);
    expect(messaging.calls.any((call) => call.$1), isFalse);
    expect(bloc.state.followOverrides['a-id'], isTrue);
    expect(bloc.state.followOutcome?.follow, isTrue);
  });

  for (final bool closeInstead in <bool>[false, true]) {
    test(
      'invalidation during first native topic call prevents subsequent dispatch/outcome; close=$closeInstead',
      () async {
        final gate = Completer<void>();
        messaging.subscribeGate = gate;
        messaging.subscribeStarted = Completer<void>();
        when(() => unfollow(any())).thenAnswer((_) async => Result.success<void>(null));
        final bloc = buildBloc();
        addTearDown(() async {
          if (!gate.isCompleted) gate.complete();
          await bloc.close();
        });
        bloc.add(unfollowEvent);
        await messaging.subscribeStarted!.future;
        // Drain the platform-channel delivery while held.
        await pumpEventQueue();
        final dispatched = List<(bool, String)>.of(messaging.calls);
        expect(dispatched.first, (false, 'posts_a-id'));
        Future<void>? closing;
        if (closeInstead) {
          closing = bloc.close();
        } else {
          app_state.prismUser = profileUser(id: 'other');
          CoinsService.instance.resetSession();
        }
        gate.complete();
        await pumpEventQueue();
        if (closing != null) {
          await closing;
        } else {
          await bloc.close();
          expect(app_state.prismUser.following, isEmpty);
        }
        // Native calls dispatched while the old owner was current cannot be cancelled.
        expect(messaging.calls, dispatched);
        expect(bloc.state.followOutcome, isNull);
      },
    );
  }

  test('follow does not mutate legacy session email arrays', () async {
    final current = profileUser(id: 'me')..email = 'me@x.com';
    current.following = <String>['legacy@example.com'];
    app_state.prismUser = current;
    when(() => follow(any())).thenAnswer((_) async => Result.success<void>(null));
    final bloc = buildBloc();
    bloc.add(followEvent);
    await pumpEventQueue();
    expect(current.following, ['legacy@example.com']);
    expect(bloc.state.followOutcome?.success, isTrue);
    await bloc.close();
  });

  test('different targets do not block one another', () async {
    final first = Completer<Result<void>>();
    when(() => follow(any())).thenAnswer((invocation) {
      final params = invocation.positionalArguments.single as FollowUserParams;
      return params.targetUserId == 'a-id' ? first.future : Future.value(Result.success<void>(null));
    });
    final bloc = buildBloc();
    addTearDown(bloc.close);
    bloc.add(followEvent);
    await pumpEventQueue();
    bloc.add(
      const PublicProfileEvent.followChangeRequested(
        follow: true,
        currentUserId: 'me',
        currentUserEmail: 'me@x.com',
        targetUserId: 'b-id',
        targetUserEmail: 'b@x.com',
      ),
    );
    await pumpEventQueue();
    expect(app_state.prismUser.following, isEmpty);
    first.complete(Result.success<void>(null));
    await pumpEventQueue();
    expect(app_state.prismUser.following, isEmpty);
    expect(bloc.state.followOutcome?.id, 2);
  });

  blocTest<PublicProfileBloc, PublicProfileState>(
    'follow flips the UID row first, then reports success without mutating the legacy session array',
    setUp: () => app_state.prismUser = profileUser(id: 'me')..email = 'me@x.com',
    build: () {
      when(() => follow(any())).thenAnswer((_) async => Result.success<void>(null));
      return buildBloc();
    },
    seed: () => loading.copyWith(
      followers: loading.followers.copyWith(summaries: [_user('A@x.com', id: 'a-id')]),
    ),
    act: (bloc) => bloc.add(followEvent),
    expect: () => <Matcher>[
      isA<PublicProfileState>()
          .having((s) => s.followOverrides, 'overrides', <String, bool>{'a-id': true})
          .having((s) => s.followers.summaries.single.isFollowedByCurrentUser, 'row', isTrue)
          .having((s) => s.followOutcome, 'outcome', isNull),
      isA<PublicProfileState>().having(
        (s) => s.followOutcome,
        'outcome',
        const FollowOutcome(id: 1, follow: true, success: true, targetName: 'Ann', targetUserId: 'a-id'),
      ),
    ],
    verify: (_) {
      expect(app_state.prismUser.following, isEmpty);
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
    'unfollow updates the UID relation row without mutating the legacy session array',
    setUp: () => app_state.prismUser = profileUser(id: 'me')
      ..email = 'me@x.com'
      ..following = <String>['a@X.com', 'b@x.com'],
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
      expect(app_state.prismUser.following, <String>['a@X.com', 'b@x.com']);
      expect(bloc.state.followOutcome?.success, isTrue);
    },
  );

  blocTest<PublicProfileBloc, PublicProfileState>(
    'a failed follow rolls the button back, keeps the session as it was and reports the failure',
    setUp: () => app_state.prismUser = profileUser(id: 'me')..email = 'me@x.com',
    build: () {
      when(() => follow(any())).thenAnswer((_) async => Result.error<void>(const ServerFailure('offline')));
      return buildBloc();
    },
    seed: () => loading.copyWith(
      followers: loading.followers.copyWith(summaries: [_user('A@x.com', id: 'a-id')]),
    ),
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

  blocTest<PublicProfileBloc, PublicProfileState>(
    'a failed unfollow restores an initially-followed UID relation row',
    build: () {
      when(() => unfollow(any())).thenAnswer((_) async => Result.error<void>(const ServerFailure('offline')));
      return buildBloc();
    },
    seed: () => loading.copyWith(
      profileId: 'profileUid',
      following: loading.following.copyWith(
        summaries: <UserSummaryEntity>[
          const UserSummaryEntity(
            id: 'targetUid',
            name: 'Target',
            email: '',
            username: 'target',
            profilePhoto: '',
            isFollowedByCurrentUser: true,
          ),
        ],
      ),
    ),
    act: (bloc) => bloc.add(
      const PublicProfileEvent.followChangeRequested(
        follow: false,
        currentUserId: 'me',
        currentUserEmail: 'me@x.com',
        targetUserId: 'targetUid',
        targetUserEmail: '',
      ),
    ),
    expect: () => <Matcher>[
      isA<PublicProfileState>().having(
        (state) => state.following.summaries.single.isFollowedByCurrentUser,
        'row',
        false,
      ),
      isA<PublicProfileState>()
          .having((state) => state.following.summaries.single.isFollowedByCurrentUser, 'row', true)
          .having((state) => state.followOverrides, 'overrides', isEmpty)
          .having((state) => state.followOutcome?.success, 'success', false),
    ],
  );

  group('follow_result analytics', () {
    late FakeAppAnalytics recorder;

    setUp(() {
      recorder = FakeAppAnalytics();
      AnalyticsRuntime.instance = recorder;
      app_state.prismUser = profileUser(id: 'me')..email = 'me@x.com';
    });

    List<(String, String)> results() =>
        recorder.events.whereType<FollowResultEvent>().map((e) => (e.action, e.result)).toList();

    test('records a successful follow and a successful unfollow', () async {
      when(() => follow(any())).thenAnswer((_) async => Result.success<void>(null));
      when(() => unfollow(any())).thenAnswer((_) async => Result.success<void>(null));
      final bloc = buildBloc();
      addTearDown(bloc.close);

      bloc.add(followEvent);
      await bloc.stream.firstWhere((s) => s.followOutcome != null);
      bloc.add(
        const PublicProfileEvent.followChangeRequested(
          follow: false,
          currentUserId: 'me',
          currentUserEmail: 'me@x.com',
          targetUserId: 'a-id',
          targetUserEmail: 'A@x.com',
        ),
      );
      await bloc.stream.firstWhere((s) => s.followOutcome?.id == 2);

      expect(results(), <(String, String)>[('follow', 'success'), ('unfollow', 'success')]);
    });

    test('records a failed follow', () async {
      when(() => follow(any())).thenAnswer((_) async => Result.error<void>(const ServerFailure('offline')));
      final bloc = buildBloc();
      addTearDown(bloc.close);

      bloc.add(followEvent);
      await bloc.stream.firstWhere((s) => s.followOutcome != null);

      expect(results(), <(String, String)>[('follow', 'failure')]);
    });
  });

  test('withFollowState flips one UID in the list and its search results', () {
    final list = RelationList(
      summaries: [
        _user('a@x.com', id: 'a-id'),
        _user('b@x.com', id: 'b-id'),
      ],
      searchResults: [_user('A@x.com', id: 'a-id')],
    );

    final next = list.withFollowState('a-id', isFollowed: true);

    expect(next.summaries.map((u) => u.isFollowedByCurrentUser), <bool>[true, false]);
    expect(next.searchResults!.single.isFollowedByCurrentUser, isTrue);
    expect(list.summaries.first.isFollowedByCurrentUser, isFalse);
  });
}
