import 'package:Prism/core/wallpaper/wallpaper_source.dart';

enum CategorySearchType { search, nonSearch }

/// Values the `onWallCategorize` Cloud Function writes to `walls.category`.
const Set<String> prismClassifierCategories = <String>{
  'Nature', 'Architecture', 'Cars', 'Anime', 'Space', 'Ocean', 'Flowers', 'Neon', 'Dark', 'Abstract', //
  '3D Render', 'Minimal', 'Gradient', 'AI Art', 'Cyberpunk', 'Vintage', 'Landscape', 'Galaxy',
};

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

  /// True when creators' walls can carry this name as their `category`, so Prism walls can lead the feed.
  bool get hasPrismWalls => prismClassifierCategories.contains(name);
}
