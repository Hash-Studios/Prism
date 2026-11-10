import 'dart:async';

import 'package:Prism/auth/user_model.dart';
import 'package:Prism/core/auth/require_signed_in_action.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/creator_directory/biz/creator_directory_cubit.dart';
import 'package:Prism/features/creator_directory/views/creator_follow_changes.dart';
import 'package:Prism/features/creator_directory/views/pages/creators_page.dart';
import 'package:Prism/features/creator_directory/views/widgets/creator_directory_card.dart';
import 'package:Prism/features/public_profile/biz/bloc/public_profile_bloc.j.dart';
import 'package:Prism/features/session/domain/repositories/session_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/favourite_test_scope.dart';
import '../../support/profile_user_fixture.dart';
import 'creator_directory_test_support.dart';

Future<void> _pumpPage(
  WidgetTester tester,
  FakeCreatorDirectoryRepository repo, {
  PublicProfileBloc? profileBloc,
  PublicProfileBloc Function()? profileBlocFactory,
}) async {
  await pumpCreators(
    tester,
    const CreatorsPage(),
    repository: repo,
    profileBloc: profileBloc ?? publicProfileBlocWith(),
    profileBlocFactory: profileBlocFactory,
  );
  // The first page loads in microtasks, then rebuilds once.
  await tester.pump();
  await tester.pump();
}

Future<void> _settle(WidgetTester tester) async {
  // Session events replace providers, whose async load then needs its own frame.
  await tester.pump();
  await tester.pump();
  await tester.pump();
  await tester.pump();
}

void main() {
  late FakeCreatorDirectoryRepository repo;

  setUpFavouriteCounts();

  setUpAll(() => registerFallbackValue(const PublicProfileEvent.refreshRequested()));

  setUp(() {
    setUpCreatorDirectoryGlobals();
    repo = FakeCreatorDirectoryRepository();
  });

  tearDown(resetCreatorDirectoryGlobals);

  testWidgets('lists creators with the All chip and the category chips', (tester) async {
    repo.pages[(null, null)] = creatorPage(<DirectoryCreator>[
      directoryCreator('a', categories: <String>['Nature', 'Abstract']),
      directoryCreator('b', rank: 2, categories: <String>['Nature']),
    ]);
    await _pumpPage(tester, repo);

    expect(find.text('Creator a'), findsOneWidget);
    expect(find.text('Creator b'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Nature'), findsOneWidget);
    expect(find.text('Abstract'), findsOneWidget);
  });

  testWidgets('tapping a category loads that category and shows only its creators', (tester) async {
    repo.pages[(null, null)] = creatorPage(<DirectoryCreator>[
      directoryCreator('a', categories: <String>['Nature']),
    ]);
    repo.pages[('Nature', null)] = creatorPage(<DirectoryCreator>[
      directoryCreator('n1', categories: <String>['Nature']),
    ]);
    await _pumpPage(tester, repo);

    await tester.tap(find.text('Nature'));
    await _settle(tester);

    expect(repo.fetchCalls.last, (category: 'Nature', afterRank: null));
    expect(find.text('Creator n1'), findsOneWidget);
    expect(find.text('Creator a'), findsNothing);
    expect(find.text('Nature'), findsOneWidget);
  });

  testWidgets('an empty category shows the empty state', (tester) async {
    repo.pages[(null, null)] = creatorPage(<DirectoryCreator>[
      directoryCreator('a', categories: <String>['Nature']),
    ]);
    repo.pages[('Nature', null)] = creatorPage(<DirectoryCreator>[]);
    await _pumpPage(tester, repo);

    await tester.tap(find.text('Nature'));
    await _settle(tester);

    expect(find.text('No creators here yet'), findsOneWidget);
    expect(find.byType(CreatorDirectoryCard), findsNothing);
  });

  testWidgets('a failed load shows the error with Try again', (tester) async {
    repo.fetchError = StateError('network down');
    await _pumpPage(tester, repo);

    expect(find.text("Couldn't load creators"), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('scrolling to the bottom loads the next page after the last rank', (tester) async {
    repo.pages[(null, null)] = creatorPage(<DirectoryCreator>[
      for (int i = 1; i <= 12; i++) directoryCreator('c$i', rank: i),
    ], nextRank: 12);
    repo.pages[(null, 12)] = creatorPage(<DirectoryCreator>[directoryCreator('c13', rank: 13)]);
    await _pumpPage(tester, repo);

    await tester.drag(
      find.byWidgetPredicate((w) => w is ListView && w.scrollDirection == Axis.vertical),
      const Offset(0, -20000),
    );
    await _settle(tester);

    expect(repo.fetchCalls.last, (category: null, afterRank: 12));
    expect(find.text('Creator c13'), findsOneWidget);
  });

  testWidgets('a guest sees the creators', (tester) async {
    app_state.prismUser = profileUser(loggedIn: false);
    repo.pages[(null, null)] = creatorPage(<DirectoryCreator>[directoryCreator('a')]);
    await _pumpPage(tester, repo);

    expect(find.text('Creator a'), findsOneWidget);
  });

  testWidgets('a guest who taps Follow is asked to sign in, and cancelling follows no one', (tester) async {
    app_state.prismUser = profileUser(loggedIn: false);
    final bloc = publicProfileBlocWith();
    final signIn = signedInActionSignIn;
    addTearDown(() => signedInActionSignIn = signIn);
    int signInCalls = 0;
    signedInActionSignIn = (_) async {
      signInCalls++;
      return false;
    };
    repo.pages[(null, null)] = creatorPage(<DirectoryCreator>[directoryCreator('a')]);
    await _pumpPage(tester, repo, profileBloc: bloc);

    await tester.tap(find.text('Follow'));
    await _settle(tester);

    expect(signInCalls, 1);
    expect(find.text('Follow'), findsOneWidget);
    verifyNever(() => bloc.add(any()));
  });

  for (final bool notify in <bool>[true, false]) {
    testWidgets('a guest follow continues when the session event is ${notify ? 'early' : 'late'}', (tester) async {
      app_state.prismUser = profileUser(loggedIn: false);
      final FakeCreatorSessionRepository session = FakeCreatorSessionRepository(app_state.prismUser);
      getIt.registerSingleton<SessionRepository>(session);
      addTearDown(session.close);
      final guestBloc = publicProfileBlocWith();
      final signedInBloc = publicProfileBlocWith();
      final states = StreamController<PublicProfileState>.broadcast();
      addTearDown(states.close);
      whenListen(signedInBloc, states.stream, initialState: PublicProfileState.initial());
      when(() => signedInBloc.add(any())).thenAnswer((_) {
        final PublicProfileState followed = PublicProfileState.initial().copyWith(
          followOverrides: <String, bool>{'a': true},
        );
        when(() => signedInBloc.state).thenReturn(followed);
        states.add(followed);
      });
      final List<PublicProfileBloc> blocs = <PublicProfileBloc>[guestBloc, signedInBloc];
      final signIn = signedInActionSignIn;
      addTearDown(() => signedInActionSignIn = signIn);
      final Completer<void> finishSignIn = Completer<void>();
      signedInActionSignIn = (_) async {
        final user = profileUser(id: 'new-viewer');
        app_state.prismUser = user;
        session.setUser(user, notify: notify);
        await finishSignIn.future;
        return true;
      };
      repo.pages[(null, null)] = creatorPage(<DirectoryCreator>[directoryCreator('a')]);
      await _pumpPage(tester, repo, profileBlocFactory: () => blocs.removeAt(0));
      final BuildContext guestButton = tester.element(find.byType(CreatorFollowButton));

      await tester.tap(find.text('Follow'));
      await _settle(tester);
      expect(guestButton.mounted, !notify);
      verifyNever(() => guestBloc.add(any()));
      verifyNever(() => signedInBloc.add(any()));
      finishSignIn.complete();
      await _settle(tester);

      expect(find.text('Following'), findsOneWidget);
      verify(
        () => signedInBloc.add(
          const PublicProfileEvent.followChangeRequested(
            follow: true,
            currentUserId: 'new-viewer',
            currentUserEmail: 'user@example.com',
            targetUserId: 'a',
            targetUserEmail: '',
            targetName: 'Creator a',
          ),
        ),
      ).called(1);
      verifyNever(() => guestBloc.add(any()));
      session.setUser(session.currentUser);
      await _settle(tester);
      expect(blocs, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('logout clears follow overrides and pagination, and ignores the old pending page', (tester) async {
    final FakeCreatorSessionRepository session = FakeCreatorSessionRepository(app_state.prismUser);
    getIt.registerSingleton<SessionRepository>(session);
    addTearDown(session.close);
    final oldBloc = publicProfileBlocWith(
      state: PublicProfileState.initial().copyWith(followOverrides: <String, bool>{'a': true}),
    );
    final guestBloc = publicProfileBlocWith();
    final List<PublicProfileBloc> blocs = <PublicProfileBloc>[oldBloc, guestBloc];
    repo.pages[(null, null)] = creatorPage(<DirectoryCreator>[directoryCreator('a')], nextRank: 1);
    repo.pages[(null, 1)] = creatorPage(<DirectoryCreator>[directoryCreator('old-only')]);
    final Completer<void> oldPage = Completer<void>();
    repo.gates[(null, 1)] = oldPage;
    await _pumpPage(tester, repo, profileBlocFactory: () => blocs.removeAt(0));
    final CreatorDirectoryCubit oldDirectory = tester
        .element(find.byType(CreatorFollowButton))
        .read<CreatorDirectoryCubit>();
    final Future<void> pending = oldDirectory.loadMore();
    await tester.pump();
    expect(find.text('Following'), findsOneWidget);
    expect(oldDirectory.state.loadingMore, isTrue);

    repo.pages[(null, null)] = creatorPage(<DirectoryCreator>[directoryCreator('a'), directoryCreator('guest-only')]);
    app_state.prismUser = profileUser(loggedIn: false);
    session.setUser(app_state.prismUser);
    await _settle(tester);
    final CreatorDirectoryCubit guestDirectory = tester
        .element(find.byType(CreatorFollowButton).first)
        .read<CreatorDirectoryCubit>();
    expect(guestDirectory, isNot(same(oldDirectory)));
    await tester.runAsync<void>(pumpEventQueue);
    expect(oldDirectory.isClosed, isTrue);
    expect(guestDirectory.state.loadingMore, isFalse);
    expect(guestDirectory.state.hasMore, isFalse);
    expect(find.text('Following'), findsNothing);
    expect(find.text('Follow'), findsNWidgets(2));
    verify(() => oldBloc.close()).called(1);

    oldPage.complete();
    await pending;
    await _settle(tester);
    expect(find.text('Creator old-only'), findsNothing);
    expect(find.text('Creator guest-only'), findsOneWidget);
    expect(repo.followedAmongCalls, hasLength(1));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a pending sign-in follow does not move to a later account', (tester) async {
    app_state.prismUser = profileUser(loggedIn: false);
    final FakeCreatorSessionRepository session = FakeCreatorSessionRepository(app_state.prismUser);
    getIt.registerSingleton<SessionRepository>(session);
    addTearDown(session.close);
    final List<MockPublicProfileBloc> allBlocs = List<MockPublicProfileBloc>.generate(
      4,
      (_) => publicProfileBlocWith(),
    );
    final List<PublicProfileBloc> unusedBlocs = List<PublicProfileBloc>.of(allBlocs);
    final signIn = signedInActionSignIn;
    addTearDown(() => signedInActionSignIn = signIn);
    final Completer<bool> finishSignIn = Completer<bool>();
    signedInActionSignIn = (_) => finishSignIn.future;
    repo.pages[(null, null)] = creatorPage(<DirectoryCreator>[directoryCreator('a')]);
    await _pumpPage(tester, repo, profileBlocFactory: () => unusedBlocs.removeAt(0));
    await tester.tap(find.text('Follow'));
    for (final user in <PrismUsersV2>[
      profileUser(id: 'first-login'),
      profileUser(loggedIn: false),
      profileUser(id: 'later-login'),
    ]) {
      app_state.prismUser = user;
      session.setUser(user);
      await _settle(tester);
    }
    finishSignIn.complete(true);
    await _settle(tester);
    for (final bloc in allBlocs) {
      verifyNever(() => bloc.add(any()));
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a rapid logout and same-account login cannot revive shared follow overrides', (tester) async {
    final PrismUsersV2 viewer = app_state.prismUser;
    final FakeCreatorSessionRepository session = FakeCreatorSessionRepository(viewer);
    getIt.registerSingleton<SessionRepository>(session);
    addTearDown(session.close);
    final List<PublicProfileBloc> blocs = List<PublicProfileBloc>.generate(3, (_) => publicProfileBlocWith());
    creatorFollowChanges.record('a', true);
    repo.pages[(null, null)] = creatorPage(<DirectoryCreator>[directoryCreator('a')]);
    await _pumpPage(tester, repo, profileBlocFactory: () => blocs.removeAt(0));
    expect(find.text('Following'), findsOneWidget);

    app_state.prismUser = profileUser(loggedIn: false);
    session.setUser(app_state.prismUser);
    app_state.prismUser = viewer;
    session.setUser(viewer);
    await _settle(tester);
    expect(find.text('Following'), findsNothing);
    expect(find.text('Follow'), findsOneWidget);
    expect(blocs, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
