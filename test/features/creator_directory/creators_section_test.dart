import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/generated/analytics_events.g.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/creator_directory/biz/creator_directory_cubit.dart';
import 'package:Prism/features/creator_directory/views/creator_follow_changes.dart';
import 'package:Prism/features/creator_directory/views/widgets/creator_directory_card.dart';
import 'package:Prism/features/creator_directory/views/widgets/creators_section.dart';
import 'package:Prism/features/public_profile/biz/bloc/public_profile_bloc.j.dart';
import 'package:Prism/features/public_profile/domain/usecases/public_profile_usecases.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/favourite_test_scope.dart';
import 'creator_directory_test_support.dart';

class _MockWalls extends Mock implements FetchPublicProfileWallsUseCase {}

class _MockFollow extends Mock implements FollowUserUseCase {}

class _MockUnfollow extends Mock implements UnfollowUserUseCase {}

class _MockSummaries extends Mock implements FetchUserSummariesPageUseCase {}

class _MockSearch extends Mock implements SearchUsersByUsernameUseCase {}

Future<void> _pumpSection(
  WidgetTester tester, {
  required FakeCreatorDirectoryRepository repo,
  required PublicProfileBloc bloc,
}) async {
  await pumpCreators(
    tester,
    const Scaffold(
      body: SingleChildScrollView(child: CreatorsSection(source: 'home')),
    ),
    repository: repo,
    profileBloc: bloc,
  );
  // The row loads in microtasks, then rebuilds once.
  await tester.pump();
  await tester.pump();
}

Finder _cardFor(String name) => find.ancestor(of: find.text(name), matching: find.byType(CreatorDirectoryCard));

void main() {
  setUpAll(() {
    registerFallbackValue(
      const FollowUserParams(currentUserId: '', currentUserEmail: '', targetUserId: '', targetUserEmail: ''),
    );
  });

  late FakeCreatorDirectoryRepository repo;

  setUpFavouriteCounts();

  setUp(() {
    setUpCreatorDirectoryGlobals();
    repo = FakeCreatorDirectoryRepository();
  });

  tearDown(resetCreatorDirectoryGlobals);

  testWidgets('shows a skeleton and no title while the first fetch is pending', (tester) async {
    repo.gates[(null, null)] = Completer<void>();
    await _pumpSection(tester, repo: repo, bloc: publicProfileBlocWith());

    expect(find.byType(PrismSkeleton), findsOneWidget);
    expect(find.text('Creators to follow'), findsNothing);
  });

  testWidgets('renders nothing when the directory is empty', (tester) async {
    await _pumpSection(tester, repo: repo, bloc: publicProfileBlocWith());

    expect(find.text('Creators to follow'), findsNothing);
    expect(tester.getSize(find.byType(CreatorsSection)).height, 0);
  });

  testWidgets('refresh reloads the row and preserves a pending follow and viewed tracking', (tester) async {
    final ValueNotifier<int> revision = ValueNotifier<int>(0);
    addTearDown(revision.dispose);
    repo.pages[(null, null)] = creatorPage(<DirectoryCreator>[directoryCreator('a')]);
    final FakeAppAnalytics sectionAnalytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = sectionAnalytics;
    final _MockWalls walls = _MockWalls();
    final _MockFollow follow = _MockFollow();
    final Completer<Result<void>> pendingFollow = Completer<Result<void>>();
    when(() => follow(any())).thenAnswer((_) => pendingFollow.future);
    final PublicProfileBloc profileBloc = PublicProfileBloc(
      walls,
      follow,
      _MockUnfollow(),
      _MockSummaries(),
      _MockSearch(),
    );
    const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, (_) async => null);
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, null));
    addTearDown(() {
      final String viewer = app_state.prismUser.id;
      app_state.prismUser.id = '$viewer-test-cleanup';
      creatorFollowChanges.record('a', false);
    });
    await pumpCreators(
      tester,
      Scaffold(
        body: ValueListenableBuilder<int>(
          valueListenable: revision,
          builder: (context, value, child) => SingleChildScrollView(
            child: CreatorsSection(source: 'home', refreshRevision: value),
          ),
        ),
      ),
      repository: repo,
      profileBloc: profileBloc,
    );
    await tester.pump();
    await tester.pump();
    final CreatorDirectoryCubit cubit = tester
        .element(find.byType(BlocBuilder<CreatorDirectoryCubit, CreatorDirectoryState>))
        .read<CreatorDirectoryCubit>();
    expect(find.text('Creators to follow'), findsOneWidget);
    expect(sectionAnalytics.events.whereType<CreatorsSectionViewedEvent>(), hasLength(1));

    await tester.tap(find.descendant(of: _cardFor('Creator a'), matching: find.text('Follow')));
    await tester.pump();
    await tester.pump();
    expect(find.descendant(of: _cardFor('Creator a'), matching: find.text('Following')), findsOneWidget);

    revision.value++;
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(repo.fetchCalls, hasLength(2));
    expect(
      tester
          .element(find.byType(BlocBuilder<CreatorDirectoryCubit, CreatorDirectoryState>))
          .read<CreatorDirectoryCubit>(),
      same(cubit),
    );
    expect(find.descendant(of: _cardFor('Creator a'), matching: find.text('Following')), findsOneWidget);
    expect(sectionAnalytics.events.whereType<CreatorsSectionViewedEvent>(), hasLength(1));

    pendingFollow.complete(Result.success<void>(null));
    await tester.runAsync<void>(pumpEventQueue);
    await tester.pump();
    expect(profileBloc.state.followOutcome?.success, isTrue);
    expect(find.descendant(of: _cardFor('Creator a'), matching: find.text('Following')), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('shows the title, See all, each creator with its follower count and four walls', (tester) async {
    repo.pages[(null, null)] = creatorPage(<DirectoryCreator>[
      directoryCreator('a'),
      directoryCreator('b', rank: 2, followers: 1),
    ]);
    await _pumpSection(tester, repo: repo, bloc: publicProfileBlocWith());

    expect(find.text('Creators to follow'), findsOneWidget);
    expect(find.text('See all'), findsOneWidget);
    expect(find.text('Creator a'), findsOneWidget);
    expect(find.text('Creator b'), findsOneWidget);
    expect(find.text('2 followers'), findsOneWidget);
    expect(find.text('1 follower'), findsOneWidget);
    for (final String name in <String>['Creator a', 'Creator b']) {
      expect(find.descendant(of: _cardFor(name), matching: find.byType(PrismWallTile)), findsNWidgets(4));
    }
  });

  testWidgets('a creator with fewer walls than slots shows only the walls it has', (tester) async {
    repo.pages[(null, null)] = creatorPage(<DirectoryCreator>[directoryCreator('a', wallCount: 2)]);
    await _pumpSection(tester, repo: repo, bloc: publicProfileBlocWith());

    final Finder strip = find.descendant(of: _cardFor('Creator a'), matching: find.byType(CreatorWallStrip));
    // Two walls, two tiles; the other two slots stay empty so the card keeps the shared row height.
    expect(find.descendant(of: strip, matching: find.byType(PrismWallTile)), findsNWidgets(2));
    expect(find.descendant(of: strip, matching: find.byType(AspectRatio)), findsNWidgets(4));
  });

  testWidgets('shows an error with Try again, and Try again fetches once more', (tester) async {
    repo.fetchError = StateError('network down');
    await _pumpSection(tester, repo: repo, bloc: publicProfileBlocWith());

    expect(find.text("Couldn't load creators"), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(repo.fetchCalls, hasLength(1));

    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump();

    expect(repo.fetchCalls, hasLength(2));
  });

  testWidgets('screen readers can follow and open the profile from a card', (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final bloc = publicProfileBlocWith();
    repo.pages[(null, null)] = creatorPage(<DirectoryCreator>[directoryCreator('a')]);
    await _pumpSection(tester, repo: repo, bloc: bloc);

    expect(
      tester.getSemantics(find.bySemanticsLabel('Follow Creator a')),
      matchesSemantics(label: 'Follow Creator a', isButton: true, hasTapAction: true),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel("Open Creator a's profile")),
      matchesSemantics(label: "Open Creator a's profile", isButton: true, hasTapAction: true),
    );

    tester.semantics.tap(find.semantics.byLabel('Follow Creator a'));
    await tester.pump();
    verify(
      () => bloc.add(
        PublicProfileEvent.followChangeRequested(
          follow: true,
          currentUserId: app_state.prismUser.id,
          currentUserEmail: app_state.prismUser.email,
          targetUserId: 'a',
          targetUserEmail: '',
          targetName: 'Creator a',
        ),
      ),
    ).called(1);
    semantics.dispose();
  });

  testWidgets('Follow sends followChangeRequested for that creator', (tester) async {
    final bloc = publicProfileBlocWith();
    repo.pages[(null, null)] = creatorPage(<DirectoryCreator>[directoryCreator('a')]);
    await _pumpSection(tester, repo: repo, bloc: bloc);

    await tester.tap(find.descendant(of: _cardFor('Creator a'), matching: find.text('Follow')));
    await tester.pump();

    verify(
      () => bloc.add(
        PublicProfileEvent.followChangeRequested(
          follow: true,
          currentUserId: app_state.prismUser.id,
          currentUserEmail: app_state.prismUser.email,
          targetUserId: 'a',
          targetUserEmail: '',
          targetName: 'Creator a',
        ),
      ),
    ).called(1);
  });

  testWidgets('a card shows Following once the bloc has an override for that creator', (tester) async {
    final bloc = publicProfileBlocWith(
      state: PublicProfileState.initial().copyWith(followOverrides: <String, bool>{'a': true}),
    );
    repo.pages[(null, null)] = creatorPage(<DirectoryCreator>[directoryCreator('a')]);
    await _pumpSection(tester, repo: repo, bloc: bloc);

    expect(find.descendant(of: _cardFor('Creator a'), matching: find.text('Following')), findsOneWidget);
    expect(find.descendant(of: _cardFor('Creator a'), matching: find.text('Follow')), findsNothing);
  });

  testWidgets('a creator the viewer already follows is not in the row', (tester) async {
    repo.followed = <String>{'a'};
    repo.pages[(null, null)] = creatorPage(<DirectoryCreator>[directoryCreator('a'), directoryCreator('b', rank: 2)]);
    await _pumpSection(tester, repo: repo, bloc: publicProfileBlocWith());

    expect(find.text('Creator a'), findsNothing);
    expect(find.text('Creator b'), findsOneWidget);
  });
}
