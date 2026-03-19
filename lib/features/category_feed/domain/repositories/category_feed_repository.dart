import 'package:Prism/core/utils/result.dart';

import 'package:Prism/features/category_feed/domain/entities/category_entity.dart';
import 'package:Prism/features/category_feed/domain/entities/category_feed_page.dart';

abstract class CategoryFeedRepository {
  Future<Result<List<CategoryEntity>>> getCategories();

  Future<Result<CategoryFeedPage>> fetchCategoryFeed({required CategoryEntity category, required bool refresh});
}
