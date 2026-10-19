import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/l10n/l10n.dart';

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

/// Localized label for a known category while preserving [CategoryDefinition.name] as the stable data key.
String categoryDisplayName(String name, AppLocalizations l10n) => switch (name) {
  'Category' => l10n.coreCategoryDefault,
  'AI Art' => l10n.coreCategoryAiArt,
  'Aesthetic' => l10n.coreCategoryAesthetic,
  'Cyberpunk' => l10n.coreCategoryCyberpunk,
  '3D Render' => l10n.coreCategoryRender3d,
  'Gradient' => l10n.coreCategoryGradient,
  'Minimal' => l10n.coreCategoryMinimal,
  'Dark' => l10n.coreCategoryDark,
  'Nature' => l10n.coreCategoryNature,
  'Landscape' => l10n.coreCategoryLandscape,
  'Space' => l10n.coreCategorySpace,
  'Anime' => l10n.coreCategoryAnime,
  'Neon' => l10n.coreCategoryNeon,
  'Abstract' => l10n.coreCategoryAbstract,
  'Architecture' => l10n.coreCategoryArchitecture,
  'Ocean' => l10n.coreCategoryOcean,
  'Forest' => l10n.coreCategoryForest,
  'Galaxy' => l10n.coreCategoryGalaxy,
  'Vintage' => l10n.coreCategoryVintage,
  'Cars' => l10n.coreCategoryCars,
  'Flowers' => l10n.coreCategoryFlowers,
  'Vehicles' => l10n.coreCategoryVehicles,
  'Animals' => l10n.coreCategoryAnimals,
  'Fantasy' => l10n.coreCategoryFantasy,
  'Scenery' => l10n.coreCategoryScenery,
  'Aerial' => l10n.coreCategoryAerial,
  'Artistic' => l10n.coreCategoryArtistic,
  'Clouds' => l10n.coreCategoryClouds,
  'Textures' => l10n.coreCategoryTextures,
  'City' => l10n.coreCategoryCity,
  'Birds' => l10n.coreCategoryBirds,
  'Warriors' => l10n.coreCategoryWarriors,
  'Illustration' => l10n.coreCategoryIllustration,
  'Portraits' => l10n.coreCategoryPortraits,
  'Under the Sea' => l10n.coreCategoryUnderTheSea,
  'Quotes' => l10n.coreCategoryQuotes,
  'Robots' => l10n.coreCategoryRobots,
  'Spiritual' => l10n.coreCategorySpiritual,
  'Fashion' => l10n.coreCategoryFashion,
  'Kawaii' => l10n.coreCategoryKawaii,
  'Sports' => l10n.coreCategorySports,
  'Comic' => l10n.coreCategoryComic,
  'Tech' => l10n.coreCategoryTech,
  'Gaming' => l10n.coreCategoryGaming,
  'Food' => l10n.coreCategoryFood,
  'Music' => l10n.coreCategoryMusic,
  _ => name,
};
