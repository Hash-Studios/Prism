import 'dart:async';

import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/data/categories/category_definition.dart';
import 'package:Prism/features/category_feed/biz/bloc/category_feed_bloc.j.dart';
import 'package:Prism/features/category_feed/domain/entities/category_entity.dart';
import 'package:Prism/features/category_feed/domain/entities/category_feed_page.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/category_feed/domain/usecases/category_feed_usecases.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_user_block_repository.dart';

class _MockLoadCategoriesUseCase extends Mock implements LoadCategoriesUseCase {}

class _MockFetchCategoryFeedUseCase extends Mock implements FetchCategoryFeedUseCase {}

const CategoryEntity _home = CategoryEntity(
  name: 'Home',
  source: WallpaperSource.prism,
  searchType: CategorySearchType.nonSearch,
  image: '',
  image2: '',
);

FeedItemEntity _prismItem(String id, {required String authorUid}) {
  return FeedItemEntity.prism(
    id: id,
    wallpaper: PrismWallpaper(
      core: WallpaperCore(
        id: id,
        source: WallpaperSource.prism,
        fullUrl: 'https://example.com/$id.jpg',
        thumbnailUrl: 'https://example.com/$id-thumb.jpg',
        authorUid: authorUid,
      ),
    ),
  );
}

void main() {
  test('same-category refresh rejects old pages and ignores pagination while loading', () async {
    final load = _MockLoadCategoriesUseCase();
    final fetch = _MockFetchCategoryFeedUseCase();
    final oldPage = Completer<Result<CategoryFeedPage>>();
    final refresh = Completer<Result<CategoryFeedPage>>();
    int calls = 0;
    when(() => fetch(any())).thenAnswer((_) {
      calls++;
      if (calls == 1) {
        return Future.value(
          Result.success(CategoryFeedPage(items: <FeedItemEntity>[_prismItem('old', authorUid: 'a')], hasMore: true)),
        );
      }
      return calls == 2 ? oldPage.future : refresh.future;
    });
    final bloc = CategoryFeedBloc(load, fetch, FakeUserBlockRepository.pending()..completeInitial(<String>{}));
    addTearDown(bloc.close);
    bloc.add(const CategoryFeedEvent.categorySelected(category: _home));
    await Future<void>.delayed(Duration.zero);
    bloc.add(const CategoryFeedEvent.fetchMoreRequested());
    await Future<void>.delayed(Duration.zero);
    bloc.add(const CategoryFeedEvent.refreshRequested());
    await Future<void>.delayed(Duration.zero);
    bloc.add(const CategoryFeedEvent.fetchMoreRequested());
    await Future<void>.delayed(Duration.zero);
    final callsDuringRefresh = calls;
    refresh.complete(
      Result.success(CategoryFeedPage(items: <FeedItemEntity>[_prismItem('fresh', authorUid: 'a')], hasMore: true)),
    );
    await Future<void>.delayed(Duration.zero);
    oldPage.complete(
      Result.success(
        CategoryFeedPage(items: <FeedItemEntity>[_prismItem('stale-page', authorUid: 'a')], hasMore: false),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.items.map((item) => item.id), <String>['fresh']);
    expect(bloc.state.hasMore, isTrue);
    expect(callsDuringRefresh, 3);
  });

  test('A-B-A selection rejects the first A completion', () async {
    final fetch = _MockFetchCategoryFeedUseCase();
    final old = Completer<Result<CategoryFeedPage>>();
    int calls = 0;
    when(() => fetch(any())).thenAnswer((_) {
      if (++calls == 1) return old.future;
      return Future.value(
        Result.success(
          CategoryFeedPage(items: <FeedItemEntity>[_prismItem('fresh-$calls', authorUid: 'a')], hasMore: true),
        ),
      );
    });
    final bloc = CategoryFeedBloc(
      _MockLoadCategoriesUseCase(),
      fetch,
      FakeUserBlockRepository.pending()..completeInitial(<String>{}),
    );
    addTearDown(bloc.close);
    bloc.add(const CategoryFeedEvent.categorySelected(category: _home));
    await Future<void>.delayed(Duration.zero);
    bloc.add(
      const CategoryFeedEvent.categorySelected(
        category: CategoryEntity(
          name: 'B',
          source: WallpaperSource.prism,
          searchType: CategorySearchType.nonSearch,
          image: '',
          image2: '',
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    bloc.add(const CategoryFeedEvent.categorySelected(category: _home));
    await Future<void>.delayed(Duration.zero);
    old.complete(Result.success(const CategoryFeedPage(items: <FeedItemEntity>[], hasMore: false)));
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.items.map((item) => item.id), <String>['fresh-3']);
    expect(bloc.state.hasMore, isTrue);
  });
  test('started loads the category list and fetches no feed', () async {
    final load = _MockLoadCategoriesUseCase();
    final fetch = _MockFetchCategoryFeedUseCase();
    when(() => load(any())).thenAnswer((_) async => Result.success(const <CategoryEntity>[_home]));
    final bloc = CategoryFeedBloc(load, fetch, FakeUserBlockRepository.pending()..completeInitial(<String>{}));
    addTearDown(bloc.close);

    bloc.add(const CategoryFeedEvent.started());
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(bloc.state.categories, const <CategoryEntity>[_home]);
    expect(bloc.state.selectedCategory, isNull);
    verifyNever(() => fetch(any()));
  });

  test('refreshRequested does nothing until a category was selected', () async {
    final load = _MockLoadCategoriesUseCase();
    final fetch = _MockFetchCategoryFeedUseCase();
    when(() => load(any())).thenAnswer((_) async => Result.success(const <CategoryEntity>[_home]));
    final bloc = CategoryFeedBloc(load, fetch, FakeUserBlockRepository.pending()..completeInitial(<String>{}));
    addTearDown(bloc.close);

    bloc.add(const CategoryFeedEvent.started());
    bloc.add(const CategoryFeedEvent.refreshRequested());
    await Future<void>.delayed(const Duration(milliseconds: 10));

    verifyNever(() => fetch(any()));
  });

  setUpAll(() {
    registerFallbackValue(const NoParams());
    registerFallbackValue(const FetchCategoryFeedParams(category: _home, refresh: true));
  });

  test('blocking a creator removes their walls from the home feed without a refetch', () async {
    final load = _MockLoadCategoriesUseCase();
    final fetch = _MockFetchCategoryFeedUseCase();
    when(() => load(any())).thenAnswer((_) async => Result.success(const <CategoryEntity>[_home]));
    when(() => fetch(any())).thenAnswer(
      (_) async => Result.success(
        CategoryFeedPage(
          items: <FeedItemEntity>[
            _prismItem('1', authorUid: 'blocked-uid'),
            _prismItem('2', authorUid: 'kept-uid'),
          ],
          hasMore: false,
        ),
      ),
    );
    final blockRepo = FakeUserBlockRepository.pending()..completeInitial(<String>{});
    final bloc = CategoryFeedBloc(load, fetch, blockRepo);
    addTearDown(bloc.close);

    bloc.add(const CategoryFeedEvent.started());
    await Future<void>.delayed(const Duration(milliseconds: 10));
    bloc.add(const CategoryFeedEvent.categorySelected(category: _home));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(bloc.state.items.map((e) => e.id), <String>['1', '2']);

    blockRepo.completeInitial(<String>{});
    await Future<void>.delayed(Duration.zero);
    blockRepo.completeInitial(<String>{'blocked-uid'});
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.items.map((e) => e.id), <String>['2']);
    verify(() => fetch(any())).called(1);
  });

  test('an unknown block list hides creator walls, and recovery reloads the home feed', () async {
    final load = _MockLoadCategoriesUseCase();
    final fetch = _MockFetchCategoryFeedUseCase();
    when(() => load(any())).thenAnswer((_) async => Result.success(const <CategoryEntity>[_home]));
    when(() => fetch(any())).thenAnswer(
      (_) async => Result.success(
        CategoryFeedPage(
          items: <FeedItemEntity>[
            _prismItem('1', authorUid: 'blocked-uid'),
            _prismItem('2', authorUid: 'kept-uid'),
          ],
          hasMore: false,
        ),
      ),
    );
    final blockRepo = FakeUserBlockRepository.pending()..completeInitial(<String>{});
    final bloc = CategoryFeedBloc(load, fetch, blockRepo);
    addTearDown(bloc.close);

    bloc.add(const CategoryFeedEvent.started());
    await Future<void>.delayed(const Duration(milliseconds: 10));
    bloc.add(const CategoryFeedEvent.categorySelected(category: _home));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(bloc.state.items.map((e) => e.id), <String>['1', '2']);

    blockRepo.emitUnknown();
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.items, isEmpty);

    blockRepo.completeInitial(<String>{'blocked-uid'});
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(bloc.state.items.map((e) => e.id), <String>['2']);
    verify(() => fetch(any())).called(2);
  });

  test('a block list that becomes known during a request gets one bounded recovery fetch', () async {
    final fetch = _MockFetchCategoryFeedUseCase();
    final Completer<Result<CategoryFeedPage>> pending = Completer<Result<CategoryFeedPage>>();
    when(() => fetch(any())).thenAnswer((_) => pending.future);
    final FakeUserBlockRepository blocks = FakeUserBlockRepository.pending();
    final bloc = CategoryFeedBloc(_MockLoadCategoriesUseCase(), fetch, blocks);
    addTearDown(bloc.close);

    bloc.add(const CategoryFeedEvent.categorySelected(category: _home));
    await Future<void>.delayed(Duration.zero);
    blocks.completeInitial(<String>{});
    await Future<void>.delayed(Duration.zero);
    pending.complete(
      Result.success(
        CategoryFeedPage(items: <FeedItemEntity>[_prismItem('restored', authorUid: 'creator')], hasMore: false),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(bloc.state.items.map((item) => item.id), <String>['restored']);
    verify(() => fetch(any())).called(2);
  });

  test('refreshRequested refetches the selected category, and fetchMoreRequested pages it', () async {
    final load = _MockLoadCategoriesUseCase();
    final fetch = _MockFetchCategoryFeedUseCase();
    when(() => load(any())).thenAnswer((_) async => Result.success(const <CategoryEntity>[_home]));
    when(() => fetch(any())).thenAnswer((invocation) async {
      final params = invocation.positionalArguments.single as FetchCategoryFeedParams;
      return Result.success(
        CategoryFeedPage(
          items: <FeedItemEntity>[_prismItem(params.refresh ? '1' : '2', authorUid: 'kept-uid')],
          hasMore: params.refresh,
        ),
      );
    });
    final bloc = CategoryFeedBloc(load, fetch, FakeUserBlockRepository.pending()..completeInitial(<String>{}));
    addTearDown(bloc.close);

    bloc.add(const CategoryFeedEvent.started());
    await Future<void>.delayed(const Duration(milliseconds: 10));
    bloc.add(const CategoryFeedEvent.categorySelected(category: _home));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    bloc.add(const CategoryFeedEvent.refreshRequested());
    await Future<void>.delayed(const Duration(milliseconds: 10));
    bloc.add(const CategoryFeedEvent.fetchMoreRequested());
    await Future<void>.delayed(const Duration(milliseconds: 10));

    final calls = verify(() => fetch(captureAny())).captured.cast<FetchCategoryFeedParams>();
    expect(calls.map((call) => call.refresh), <bool>[true, true, false]);
    expect(bloc.state.items.map((e) => e.id), <String>['1', '2']);
    expect(bloc.state.hasMore, isFalse);
  });

  test('selecting another category clears the old items, and a same-category refresh keeps them', () async {
    const other = CategoryEntity(
      name: 'Other',
      source: WallpaperSource.prism,
      searchType: CategorySearchType.nonSearch,
      image: '',
      image2: '',
    );
    final load = _MockLoadCategoriesUseCase();
    final fetch = _MockFetchCategoryFeedUseCase();
    final pending = Completer<Result<CategoryFeedPage>>();
    var calls = 0;
    when(() => load(any())).thenAnswer((_) async => Result.success(const <CategoryEntity>[_home, other]));
    when(() => fetch(any())).thenAnswer((_) {
      calls++;
      if (calls < 3) {
        return Future.value(
          Result.success(CategoryFeedPage(items: <FeedItemEntity>[_prismItem('1', authorUid: 'a-uid')], hasMore: true)),
        );
      }
      return pending.future;
    });
    final bloc = CategoryFeedBloc(load, fetch, FakeUserBlockRepository.pending()..completeInitial(<String>{}));
    addTearDown(bloc.close);
    final states = <CategoryFeedState>[];
    final sub = bloc.stream.listen(states.add);
    addTearDown(sub.cancel);

    bloc.add(const CategoryFeedEvent.categorySelected(category: _home));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    states.clear();
    bloc.add(const CategoryFeedEvent.categorySelected(category: _home));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(states.first.status, LoadStatus.loading);
    expect(states.first.items.map((e) => e.id), <String>['1']);

    bloc.add(const CategoryFeedEvent.categorySelected(category: other));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(bloc.state.status, LoadStatus.loading);
    expect(bloc.state.selectedCategory, other);
    expect(bloc.state.items, isEmpty);
    expect(bloc.state.hasMore, isFalse);
  });

  group('switching category while a request is in flight', () {
    const CategoryEntity space = CategoryEntity(
      name: 'Space',
      source: WallpaperSource.prism,
      searchType: CategorySearchType.nonSearch,
      image: '',
      image2: '',
    );

    test('a late next page of the old category never joins the new category', () async {
      final load = _MockLoadCategoriesUseCase();
      final fetch = _MockFetchCategoryFeedUseCase();
      when(() => load(any())).thenAnswer((_) async => Result.success(const <CategoryEntity>[_home, space]));
      final Completer<Result<CategoryFeedPage>> latePage = Completer<Result<CategoryFeedPage>>();
      when(() => fetch(any())).thenAnswer((invocation) {
        final params = invocation.positionalArguments.single as FetchCategoryFeedParams;
        if (params.category.name == 'Home' && !params.refresh) return latePage.future;
        final String id = params.category.name == 'Home' ? 'home-1' : 'space-1';
        return Future.value(
          Result.success(
            CategoryFeedPage(items: <FeedItemEntity>[_prismItem(id, authorUid: 'a@x.com')], hasMore: true),
          ),
        );
      });
      final bloc = CategoryFeedBloc(load, fetch, FakeUserBlockRepository.pending()..completeInitial(<String>{}));
      addTearDown(bloc.close);

      bloc.add(const CategoryFeedEvent.categorySelected(category: _home));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      bloc.add(const CategoryFeedEvent.fetchMoreRequested());
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(bloc.state.isFetchingMore, isTrue);

      bloc.add(const CategoryFeedEvent.categorySelected(category: space));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(bloc.state.isFetchingMore, isFalse, reason: 'the new category starts without a page in flight');
      expect(bloc.state.items.map((e) => e.id), <String>['space-1']);

      latePage.complete(
        Result.success(
          CategoryFeedPage(items: <FeedItemEntity>[_prismItem('home-2', authorUid: 'a@x.com')], hasMore: false),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(bloc.state.selectedCategory?.name, 'Space');
      expect(bloc.state.items.map((e) => e.id), <String>['space-1']);
      expect(bloc.state.hasMore, isTrue);
      expect(bloc.state.isFetchingMore, isFalse);
    });

    test('a slow first page of the old category cannot replace the new one', () async {
      final load = _MockLoadCategoriesUseCase();
      final fetch = _MockFetchCategoryFeedUseCase();
      when(() => load(any())).thenAnswer((_) async => Result.success(const <CategoryEntity>[_home, space]));
      final Completer<Result<CategoryFeedPage>> slowHome = Completer<Result<CategoryFeedPage>>();
      when(() => fetch(any())).thenAnswer((invocation) {
        final params = invocation.positionalArguments.single as FetchCategoryFeedParams;
        if (params.category.name == 'Home') return slowHome.future;
        return Future.value(
          Result.success(
            CategoryFeedPage(items: <FeedItemEntity>[_prismItem('space-1', authorUid: 'a@x.com')], hasMore: false),
          ),
        );
      });
      final bloc = CategoryFeedBloc(load, fetch, FakeUserBlockRepository.pending()..completeInitial(<String>{}));
      addTearDown(bloc.close);

      bloc.add(const CategoryFeedEvent.categorySelected(category: _home));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      bloc.add(const CategoryFeedEvent.categorySelected(category: space));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      slowHome.complete(
        Result.success(
          CategoryFeedPage(items: <FeedItemEntity>[_prismItem('home-1', authorUid: 'a@x.com')], hasMore: true),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(bloc.state.items.map((e) => e.id), <String>['space-1']);
      expect(bloc.state.hasMore, isFalse);
    });
  });

  group('pages emptied by hidden walls', () {
    const CategoryFeedPage empty = CategoryFeedPage(items: <FeedItemEntity>[], hasMore: true);

    test('an empty first page with more behind it fetches the next page', () async {
      final fetch = _MockFetchCategoryFeedUseCase();
      final List<bool> refreshes = <bool>[];
      when(() => fetch(any())).thenAnswer((invocation) async {
        final params = invocation.positionalArguments.single as FetchCategoryFeedParams;
        refreshes.add(params.refresh);
        if (refreshes.length < 3) return Result.success(empty);
        return Result.success(
          CategoryFeedPage(items: <FeedItemEntity>[_prismItem('human', authorUid: 'a')], hasMore: false),
        );
      });
      final bloc = CategoryFeedBloc(_MockLoadCategoriesUseCase(), fetch, FakeUserBlockRepository.pending());
      addTearDown(bloc.close);

      bloc.add(const CategoryFeedEvent.categorySelected(category: _home));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(refreshes, <bool>[true, false, false]);
      expect(bloc.state.status, LoadStatus.success);
      expect(bloc.state.items.map((e) => e.id), <String>['human']);
      expect(bloc.state.hasMore, isFalse);
    });

    test('an empty next page fetches the one after it', () async {
      final fetch = _MockFetchCategoryFeedUseCase();
      int calls = 0;
      when(() => fetch(any())).thenAnswer((_) async {
        calls++;
        if (calls == 2) return Result.success(empty);
        return Result.success(
          CategoryFeedPage(items: <FeedItemEntity>[_prismItem('wall-$calls', authorUid: 'a')], hasMore: true),
        );
      });
      final bloc = CategoryFeedBloc(_MockLoadCategoriesUseCase(), fetch, FakeUserBlockRepository.pending());
      addTearDown(bloc.close);

      bloc.add(const CategoryFeedEvent.categorySelected(category: _home));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      bloc.add(const CategoryFeedEvent.fetchMoreRequested());
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(calls, 3);
      expect(bloc.state.items.map((e) => e.id), <String>['wall-1', 'wall-3']);
      expect(bloc.state.isFetchingMore, isFalse);
    });

    test('stops after 5 empty pages in a row', () async {
      final fetch = _MockFetchCategoryFeedUseCase();
      when(() => fetch(any())).thenAnswer((_) async => Result.success(empty));
      final bloc = CategoryFeedBloc(_MockLoadCategoriesUseCase(), fetch, FakeUserBlockRepository.pending());
      addTearDown(bloc.close);

      bloc.add(const CategoryFeedEvent.categorySelected(category: _home));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      verify(() => fetch(any())).called(5);
      expect(bloc.state.status, LoadStatus.success);
      expect(bloc.state.items, isEmpty);
      expect(bloc.state.hasMore, isTrue);

      bloc.add(const CategoryFeedEvent.fetchMoreRequested());
      await Future<void>.delayed(const Duration(milliseconds: 10));

      verify(() => fetch(any())).called(5);
      expect(bloc.state.isFetchingMore, isFalse);
    });
  });
}
