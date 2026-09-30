import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/result.dart';
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

FeedItemEntity _prismItem(String id, {required String authorEmail}) {
  return FeedItemEntity.prism(
    id: id,
    wallpaper: PrismWallpaper(
      core: WallpaperCore(
        id: id,
        source: WallpaperSource.prism,
        fullUrl: 'https://example.com/$id.jpg',
        thumbnailUrl: 'https://example.com/$id-thumb.jpg',
        authorEmail: authorEmail,
      ),
    ),
  );
}

void main() {
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
            _prismItem('1', authorEmail: 'blocked@example.com'),
            _prismItem('2', authorEmail: 'kept@example.com'),
          ],
          hasMore: false,
        ),
      ),
    );
    final blockRepo = FakeUserBlockRepository.pending();
    final bloc = CategoryFeedBloc(load, fetch, blockRepo);
    addTearDown(bloc.close);

    bloc.add(const CategoryFeedEvent.started());
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(bloc.state.items.map((e) => e.id), <String>['1', '2']);

    blockRepo.completeInitial(<String>{});
    await Future<void>.delayed(Duration.zero);
    blockRepo.completeInitial(<String>{'blocked@example.com'});
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.items.map((e) => e.id), <String>['2']);
    verify(() => fetch(any())).called(1);
  });

  test('refreshRequested refetches the selected category, and fetchMoreRequested pages it', () async {
    final load = _MockLoadCategoriesUseCase();
    final fetch = _MockFetchCategoryFeedUseCase();
    when(() => load(any())).thenAnswer((_) async => Result.success(const <CategoryEntity>[_home]));
    when(() => fetch(any())).thenAnswer((invocation) async {
      final params = invocation.positionalArguments.single as FetchCategoryFeedParams;
      return Result.success(
        CategoryFeedPage(
          items: <FeedItemEntity>[_prismItem(params.refresh ? '1' : '2', authorEmail: 'kept@example.com')],
          hasMore: params.refresh,
        ),
      );
    });
    final bloc = CategoryFeedBloc(load, fetch, FakeUserBlockRepository.pending());
    addTearDown(bloc.close);

    bloc.add(const CategoryFeedEvent.started());
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
}
