import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/data/categories/category_definition.dart';

class CategoryDefinitionCodec {
  const CategoryDefinitionCodec();

  CategoryDefinition fromRawMap(Map<Object?, Object?> raw) {
    final String name = (raw['name'] ?? '').toString();
    final String providerStr = (raw['provider'] ?? '').toString();
    final String typeStr = (raw['type'] ?? '').toString();
    final String imageUrl = (raw['image'] ?? '').toString();

    final WallpaperSource source = WallpaperSourceX.fromWire(providerStr);
    final CategorySearchType searchType = typeStr == 'search'
        ? CategorySearchType.search
        : CategorySearchType.nonSearch;

    return CategoryDefinition(name: name, source: source, searchType: searchType, imageUrl: imageUrl);
  }
}
