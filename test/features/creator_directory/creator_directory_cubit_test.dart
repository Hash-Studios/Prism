import 'dart:async';

import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/creator_directory/biz/creator_directory_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/profile_user_fixture.dart';
import 'creator_directory_test_support.dart';

/// Matches a state. Omitted fields match anything.
Matcher _state({
  Object status = anything,
  Object uids = anything,
  Object categories = anything,
  Object category = anything,
  Object nextRank = anything,
  Object loadingMore = anything,
}) => isA<CreatorDirectoryState>()
    .having((s) => s.status, 'status', status)
    .having((s) => uidsOf(s.creators), 'uids', uids)
    .having((s) => s.categories, 'categories', categories)
    .having((s) => s.category, 'category', category)
    .having((s) => s.nextRank, 'nextRank', nextRank)
    .having((s) => s.loadingMore, 'loadingMore', loadingMore);

void main() {
  late FakeCreatorDirectoryRepository repo;

  setUp(() {
    setUpCreatorDirectoryGlobals();
    repo = FakeCreatorDirectoryRepository();
  });

  tearDown(resetCreatorDirectoryGlobals);

  test('a pending row cannot restore creators after signing out', () async {
    final gate = Completer<void>();
    repo.gates[(null, null)] = gate;
    repo.pages[(null, null)] = creatorPage(<DirectoryCreator>[directoryCreator('a')]);
    final cubit = CreatorDirectoryCubit(repo);
    final pending = cubit.loadRow();
    app_state.prismUser = profileUser(loggedIn: false);
    await cubit.loadRow();
    gate.complete();
    await pending;
    expect(cubit.state.creators, isEmpty);
    await cubit.close();
  });

  test('guests cannot load See all', () async {
    app_state.prismUser = profileUser(loggedIn: false);
    final cubit = CreatorDirectoryCubit(repo);
    await cubit.loadPage();
    expect(cubit.state.isEmpty, isTrue);
    expect(repo.fetchCalls, isEmpty);
    await cubit.close();
  });

  group('loadRow', () {
    blocTest<CreatorDirectoryCubit, CreatorDirectoryState>(
      'emits loaded with the creators the viewer does not follow',
      build: () {
        repo.pages[(null, null)] = creatorPage(<DirectoryCreator>[
          directoryCreator('a'),
          directoryCreator('b', rank: 2),
          directoryCreator('c', rank: 3),
        ], nextRank: 3);
        repo.followed = <String>{'b'};
        return CreatorDirectoryCubit(repo);
      },
      act: (cubit) => cubit.loadRow(),
      expect: () => <Matcher>[
        _state(status: CreatorDirectoryStatus.loaded, uids: <String>['a', 'c']),
      ],
      verify: (_) {
        expect(repo.fetchCalls, <({String? category, int? afterRank})>[(category: null, afterRank: null)]);
        expect(repo.followedAmongCalls, <List<String>>[
          <String>['a', 'b', 'c'],
        ]);
      },
    );

    blocTest<CreatorDirectoryCubit, CreatorDirectoryState>(
      'signed-out viewer emits loaded empty without calling the repository',
      setUp: () => app_state.prismUser = profileUser(loggedIn: false),
      build: () => CreatorDirectoryCubit(repo),
      act: (cubit) => cubit.loadRow(),
      expect: () => <Matcher>[_state(status: CreatorDirectoryStatus.loaded, uids: <String>[])],
      verify: (_) => expect(repo.fetchCalls, isEmpty),
    );

    blocTest<CreatorDirectoryCubit, CreatorDirectoryState>(
      'emits failed when the fetch throws',
      build: () {
        repo.fetchError = StateError('network down');
        return CreatorDirectoryCubit(repo);
      },
      act: (cubit) => cubit.loadRow(),
      expect: () => <Matcher>[_state(status: CreatorDirectoryStatus.failed)],
    );
  });

  group('loadPage', () {
    blocTest<CreatorDirectoryCubit, CreatorDirectoryState>(
      'builds category chips from the first unfiltered page, most common first',
      build: () {
        repo.pages[(null, null)] = creatorPage(<DirectoryCreator>[
          directoryCreator('a', categories: <String>['Nature', 'Abstract']),
          directoryCreator('b', rank: 2, categories: <String>['Nature', 'Dark']),
          directoryCreator('c', rank: 3, categories: <String>['Nature', 'Minimal', 'Abstract']),
        ]);
        return CreatorDirectoryCubit(repo);
      },
      act: (cubit) => cubit.loadPage(),
      expect: () => <Matcher>[
        _state(status: CreatorDirectoryStatus.loading),
        _state(
          status: CreatorDirectoryStatus.loaded,
          uids: <String>['a', 'b', 'c'],
          categories: <String>['Nature', 'Abstract', 'Dark', 'Minimal'],
        ),
      ],
    );

    blocTest<CreatorDirectoryCubit, CreatorDirectoryState>(
      'keeps at most 8 category chips',
      build: () {
        repo.pages[(null, null)] = creatorPage(<DirectoryCreator>[
          for (int i = 0; i < 10; i++) directoryCreator('c$i', rank: i + 1, categories: <String>['Cat0$i']),
        ]);
        return CreatorDirectoryCubit(repo);
      },
      act: (cubit) => cubit.loadPage(),
      expect: () => <Matcher>[
        _state(status: CreatorDirectoryStatus.loading),
        _state(
          status: CreatorDirectoryStatus.loaded,
          categories: <String>['Cat00', 'Cat01', 'Cat02', 'Cat03', 'Cat04', 'Cat05', 'Cat06', 'Cat07'],
        ),
      ],
    );

    blocTest<CreatorDirectoryCubit, CreatorDirectoryState>(
      'a category filter passes the category and keeps the chips',
      seed: () => const CreatorDirectoryState(
        status: CreatorDirectoryStatus.loaded,
        categories: <String>['Nature', 'Abstract'],
      ),
      build: () {
        repo.pages[('Nature', null)] = creatorPage(<DirectoryCreator>[
          directoryCreator('n1', categories: <String>['Nature']),
        ]);
        return CreatorDirectoryCubit(repo);
      },
      act: (cubit) => cubit.loadPage(category: 'Nature'),
      expect: () => <Matcher>[
        _state(status: CreatorDirectoryStatus.loading, category: 'Nature', categories: <String>['Nature', 'Abstract']),
        _state(
          status: CreatorDirectoryStatus.loaded,
          uids: <String>['n1'],
          category: 'Nature',
          categories: <String>['Nature', 'Abstract'],
        ),
      ],
      verify: (_) {
        expect(repo.fetchCalls, <({String? category, int? afterRank})>[(category: 'Nature', afterRank: null)]);
      },
    );

    test('a stale loadPage result is ignored after a newer loadPage', () async {
      final CreatorDirectoryCubit cubit = CreatorDirectoryCubit(repo);
      addTearDown(cubit.close);
      repo.gates[(null, null)] = Completer<void>();
      repo.pages[(null, null)] = creatorPage(<DirectoryCreator>[directoryCreator('a')]);
      repo.pages[('Nature', null)] = creatorPage(<DirectoryCreator>[
        directoryCreator('n1', categories: <String>['Nature']),
      ]);

      final Future<void> first = cubit.loadPage();
      await cubit.loadPage(category: 'Nature');
      repo.gates[(null, null)]!.complete();
      await first;

      expect(uidsOf(cubit.state.creators), <String>['n1']);
      expect(cubit.state.category, 'Nature');
      expect(cubit.state.status, CreatorDirectoryStatus.loaded);
    });
  });

  group('loadMore', () {
    blocTest<CreatorDirectoryCubit, CreatorDirectoryState>(
      'appends the next page using afterRank = nextRank and stops at the end',
      seed: () => CreatorDirectoryState(
        status: CreatorDirectoryStatus.loaded,
        creators: <DirectoryCreator>[directoryCreator('a'), directoryCreator('b', rank: 2)],
        nextRank: 2,
      ),
      build: () {
        repo.pages[(null, 2)] = creatorPage(<DirectoryCreator>[
          directoryCreator('c', rank: 3),
          directoryCreator('d', rank: 4),
        ]);
        return CreatorDirectoryCubit(repo);
      },
      act: (cubit) => cubit.loadMore(),
      expect: () => <Matcher>[
        _state(status: CreatorDirectoryStatus.loaded, uids: <String>['a', 'b'], nextRank: 2, loadingMore: true),
        _state(
          status: CreatorDirectoryStatus.loaded,
          uids: <String>['a', 'b', 'c', 'd'],
          nextRank: isNull,
          loadingMore: false,
        ),
      ],
      verify: (_) {
        expect(repo.fetchCalls, <({String? category, int? afterRank})>[(category: null, afterRank: 2)]);
      },
    );

    blocTest<CreatorDirectoryCubit, CreatorDirectoryState>(
      'does nothing when nextRank is null',
      seed: () => const CreatorDirectoryState(status: CreatorDirectoryStatus.loaded),
      build: () => CreatorDirectoryCubit(repo),
      act: (cubit) => cubit.loadMore(),
      expect: () => <Matcher>[],
      verify: (_) => expect(repo.fetchCalls, isEmpty),
    );
  });
}
