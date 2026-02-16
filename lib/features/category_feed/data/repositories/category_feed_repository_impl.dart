import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/data/categories/categories.dart' as category_data;
import 'package:Prism/data/pexels/provider/pexelsWithoutProvider.dart'
    as pexels_data;
import 'package:Prism/data/prism/provider/prismWithoutProvider.dart'
    as prism_data;
import 'package:Prism/data/wallhaven/provider/wallhavenWithoutProvider.dart'
    as wallhaven_data;
import 'package:Prism/features/category_feed/domain/entities/category_entity.dart';
import 'package:Prism/features/category_feed/domain/entities/category_feed_page.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/category_feed/domain/repositories/category_feed_repository.dart';
import 'package:hive/hive.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: CategoryFeedRepository)
class CategoryFeedRepositoryImpl implements CategoryFeedRepository {
  CategoryFeedRepositoryImpl(@Named('prefsBox') this._prefsBox);

  final Box<dynamic> _prefsBox;

  @override
  Future<Result<List<CategoryEntity>>> getCategories() async {
    final categories = category_data.categories.map((rawItem) {
      final item = Map<String, dynamic>.from(rawItem as Map);
      return CategoryEntity(
        name: (item['name'] ?? '').toString(),
        provider: (item['provider'] ?? '').toString(),
        type: (item['type'] ?? '').toString(),
        image: (item['image'] ?? '').toString(),
      );
    }).toList(growable: false);

    return Result.success(categories);
  }

  @override
  Future<Result<CategoryFeedPage>> fetchCategoryFeed({
    required CategoryEntity category,
    required bool refresh,
  }) async {
    final mode = refresh ? 'r' : 'm';

    try {
      List<dynamic> rawItems = <dynamic>[];
      if (category.type == 'search') {
        if (category.provider == 'WallHaven') {
          rawItems = await wallhaven_data.categoryDataFetcher(
            category.name,
            mode,
            (_prefsBox.get('WHcategories', defaultValue: 100) as int?) ?? 100,
            (_prefsBox.get('WHpurity', defaultValue: 100) as int?) ?? 100,
          );
        } else {
          rawItems =
              await pexels_data.categoryDataFetcherP(category.name, mode);
        }
      } else {
        if (category.name == 'Popular') {
          rawItems = await wallhaven_data.getData(
            mode,
            (_prefsBox.get('WHcategories', defaultValue: 100) as int?) ?? 100,
            (_prefsBox.get('WHpurity', defaultValue: 100) as int?) ?? 100,
          );
        } else if (category.name == 'Curated') {
          rawItems = await pexels_data.getDataP(mode);
        } else {
          rawItems = refresh
              ? (await prism_data.getPrismWalls() ?? <dynamic>[])
              : (await prism_data.seeMorePrism() ?? <dynamic>[]);
        }
      }

      final items = rawItems.map((item) {
        if (item is Map<String, dynamic>) {
          return FeedItemEntity(
            id: (item['id'] ?? '').toString(),
            provider: category.provider,
            payload: item,
          );
        }

        final id = item.hashCode.toString();
        final payload = <String, dynamic>{'raw': item, 'id': id};
        return FeedItemEntity(
            id: id, provider: category.provider, payload: payload);
      }).toList(growable: false);

      return Result.success(
        CategoryFeedPage(
          items: items,
          hasMore: items.isNotEmpty,
          nextCursor: items.isEmpty ? null : items.length.toString(),
        ),
      );
    } catch (error) {
      return Result.error(
          ServerFailure('Failed to fetch category feed: $error'));
    }
  }
}
