import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/recommendation_page.dart';

abstract interface class WallpaperRecommendationRepository {
  void release(String sessionKey);
  Future<RecommendationPage> load({
    required FeedItemEntity current,
    required String sessionKey,
    RecommendationCursor? cursor,
  });
}
