import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';

/// Applies the "Show anime wallpapers" setting to Prism walls. Wallhaven applies it on its server through the
/// `WHcategories` flag, and Pexels has no anime.
class AnimeContentFilter {
  AnimeContentFilter._();

  /// The setting is stored as the Wallhaven categories flag. Its second digit is anime, so 110 and 111 include it.
  static bool showsAnime(SettingsLocalDataSource settings) =>
      settings.get<int>('WHcategories', defaultValue: 100) >= 110;

  /// The mapper merges the classifier category into [PrismWallpaper.tags], so one check covers it and creator tags.
  static bool isAnime(PrismWallpaper wall) => wall.tags?.any((tag) => tag.trim().toLowerCase() == 'anime') ?? false;

  static bool hidesFeedItem(FeedItemEntity item, {required bool showAnime}) =>
      !showAnime && item.maybeWhen(prism: (_, wall) => isAnime(wall), orElse: () => false);

  static List<FeedItemEntity> filterFeedItems(List<FeedItemEntity> items, {required bool showAnime}) =>
      showAnime ? items : items.where((item) => !hidesFeedItem(item, showAnime: false)).toList(growable: false);
}
