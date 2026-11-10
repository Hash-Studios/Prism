import 'package:Prism/core/auth/require_signed_in_action.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/creator_directory/views/pages/creators_page.dart';
import 'package:Prism/features/creator_directory/views/widgets/creator_directory_card.dart';
import 'package:Prism/features/public_profile/biz/bloc/public_profile_bloc.j.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/favourite_test_scope.dart';
import '../../support/profile_user_fixture.dart';
import 'creator_directory_test_support.dart';

Future<void> _pumpPage(
  WidgetTester tester,
  FakeCreatorDirectoryRepository repo, {
  PublicProfileBloc? profileBloc,
}) async {
  await pumpCreators(
    tester,
    const CreatorsPage(),
    repository: repo,
    profileBloc: profileBloc ?? publicProfileBlocWith(),
  );
  // The first page loads in microtasks, then rebuilds once.
  await tester.pump();
  await tester.pump();
}

Future<void> _settle(WidgetTester tester) async {
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
}
