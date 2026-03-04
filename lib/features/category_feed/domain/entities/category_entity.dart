import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/data/categories/category_definition.dart';

class CategoryEntity {
  const CategoryEntity({required this.name, required this.source, required this.searchType, required this.image});

  final String name;
  final WallpaperSource source;
  final CategorySearchType searchType;
  final String image;
}
