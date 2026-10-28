import 'dart:async';

import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/data/categories/category_definition.dart';
import 'package:Prism/features/category_feed/domain/entities/category_entity.dart';
import 'package:Prism/features/category_feed/domain/entities/category_feed_page.dart';
import 'package:Prism/features/category_feed/domain/repositories/category_feed_repository.dart';
import 'package:Prism/features/taste_quiz/data/repositories/taste_quiz_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/in_memory_local_store.dart';

const CategoryEntity _nature = CategoryEntity(
  name: 'Nature',
  source: WallpaperSource.wallhaven,
  searchType: CategorySearchType.search,
  image: '',
  image2: '',
);

class _CategoryFeedRepository implements CategoryFeedRepository {
  _CategoryFeedRepository({required this.categories, this.feed});

  final Future<Result<List<CategoryEntity>>> Function() categories;
  final Future<Result<CategoryFeedPage>> Function()? feed;

  @override
  Future<Result<List<CategoryEntity>>> getCategories() => categories();

  @override
  Future<Result<CategoryFeedPage>> fetchCategoryFeed({required CategoryEntity category, required bool refresh}) =>
      feed?.call() ??
      Future<Result<CategoryFeedPage>>.value(
        Result.success<CategoryFeedPage>(const CategoryFeedPage(items: [], hasMore: false)),
      );
}

TasteQuizRepositoryImpl _repository(CategoryFeedRepository repository) =>
    TasteQuizRepositoryImpl(repository, SettingsLocalDataSource(InMemoryLocalStore()));

void main() {
  test('category discovery errors return null instead of throwing', () async {
    final repository = _repository(
      _CategoryFeedRepository(categories: () => Future<Result<List<CategoryEntity>>>.error(StateError('offline'))),
    );

    await expectLater(repository.loadPlan(const <String>['Nature']), completion(isNull));
  });

  test('category discovery timeout returns null within the total load budget', () async {
    final Completer<Result<List<CategoryEntity>>> pending = Completer<Result<List<CategoryEntity>>>();
    final repository = _repository(_CategoryFeedRepository(categories: () => pending.future));

    await expectLater(repository.loadPlan(const <String>['Nature']), completion(isNull));
  }, timeout: const Timeout(Duration(seconds: 5)));

  test('a category feed timeout returns null instead of throwing', () async {
    final Completer<Result<CategoryFeedPage>> pending = Completer<Result<CategoryFeedPage>>();
    final repository = _repository(
      _CategoryFeedRepository(
        categories: () async => Result.success<List<CategoryEntity>>(const <CategoryEntity>[_nature]),
        feed: () => pending.future,
      ),
    );

    await expectLater(repository.loadPlan(const <String>['Nature']), completion(isNull));
  }, timeout: const Timeout(Duration(seconds: 5)));
}
