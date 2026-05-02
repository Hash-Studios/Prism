import 'package:Prism/core/wallpaper/wallpaper_source.dart';

enum CategorySearchType { search, nonSearch }

class CategoryDefinition {
  const CategoryDefinition({
    required this.name,
    required this.source,
    required this.searchType,
    required this.imageUrl,
    required this.secondaryImageUrl,
  });

  final String name;
  final WallpaperSource source;
  final CategorySearchType searchType;
  final String imageUrl;
  final String secondaryImageUrl;
}
