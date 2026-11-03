import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/data/categories/category_definition.dart';

class CategoryEntity {
  const CategoryEntity({
    required this.name,
    required this.source,
    required this.searchType,
    required this.image,
    required this.image2,
    this.hasPrismWalls = false,
    this.query,
  });

  final String name;
  final WallpaperSource source;
  final CategorySearchType searchType;
  final String image;
  final String image2;

  /// The provider search term when it differs from [name].
  final String? query;

  String get searchQuery => query ?? name;

  /// Prism creator walls exist under this name, so the feed starts with them.
  final bool hasPrismWalls;
}
