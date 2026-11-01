import 'package:Prism/features/creator_directory/views/pages/creators_page.dart';
import 'package:Prism/features/creator_directory/views/widgets/creator_directory_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/favourite_test_scope.dart';
import 'creator_directory_test_support.dart';

Future<void> _pumpPage(WidgetTester tester, FakeCreatorDirectoryRepository repo) async {
  await pumpCreators(tester, const CreatorsPage(), repository: repo, profileBloc: publicProfileBlocWith());
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
}
