import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/category_feed/domain/entities/category_entity.dart';
import 'package:Prism/features/category_feed/domain/entities/category_feed_page.dart';
import 'package:Prism/features/category_feed/domain/repositories/category_feed_repository.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class LoadCategoriesUseCase implements UseCase<List<CategoryEntity>, NoParams> {
  LoadCategoriesUseCase(this._repository);

  final CategoryFeedRepository _repository;

  @override
  Future<Result<List<CategoryEntity>>> call(NoParams params) => _repository.getCategories();
}

class FetchCategoryFeedParams {
  const FetchCategoryFeedParams({required this.category, required this.refresh});

  final CategoryEntity category;
  final bool refresh;
}

@lazySingleton
class FetchCategoryFeedUseCase implements UseCase<CategoryFeedPage, FetchCategoryFeedParams> {
  FetchCategoryFeedUseCase(this._repository);

  final CategoryFeedRepository _repository;

  @override
  Future<Result<CategoryFeedPage>> call(FetchCategoryFeedParams params) {
    return _repository.fetchCategoryFeed(category: params.category, refresh: params.refresh);
  }
}
