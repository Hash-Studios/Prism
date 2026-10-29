import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';

/// Applies the "Show AI-generated wallpapers" setting to Prism walls. Wallhaven and Pexels walls are never AI here.
///
/// The user's own uploads and favourites skip this filter.
class AiContentFilter {
  AiContentFilter._();

  static const String settingKey = 'showAiWallpapers';

  static bool showsAi(SettingsLocalDataSource settings) => settings.get<bool>(settingKey, defaultValue: true);

  static Future<void> setShowsAi(SettingsLocalDataSource settings, bool value) => settings.set(settingKey, value);

  /// Older AI walls have [PrismWallpaper.aiMetadata] but no flag.
  static bool isAi(PrismWallpaper wall) => wall.isAiGenerated || (wall.aiMetadata?.isNotEmpty ?? false);

  static bool hidesFeedItem(FeedItemEntity item, {required bool showAi}) =>
      !showAi && item.maybeWhen(prism: (_, wall) => isAi(wall), orElse: () => false);

  static List<FeedItemEntity> filterFeedItems(List<FeedItemEntity> items, {required bool showAi}) =>
      showAi ? items : items.where((item) => !hidesFeedItem(item, showAi: false)).toList(growable: false);
}
