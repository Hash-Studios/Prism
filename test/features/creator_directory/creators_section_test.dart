import 'dart:async';

import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/prism/prism_skeleton.dart';
import 'package:Prism/features/category_feed/views/widgets/wallpaper_tile.dart';
import 'package:Prism/features/creator_directory/views/widgets/creator_directory_card.dart';
import 'package:Prism/features/creator_directory/views/widgets/creators_section.dart';
import 'package:Prism/features/public_profile/biz/bloc/public_profile_bloc.j.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/favourite_test_scope.dart';
import 'creator_directory_test_support.dart';

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
      expect(find.descendant(of: _cardFor(name), matching: find.byType(WallpaperTile)), findsNWidgets(4));
    }
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
