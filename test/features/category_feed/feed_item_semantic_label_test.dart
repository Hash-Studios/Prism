import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:flutter_test/flutter_test.dart';

FeedItemEntity _item({String? author}) => FeedItemEntity.prism(
  id: 'w1',
  wallpaper: PrismWallpaper(
    core: WallpaperCore(id: 'w1', source: WallpaperSource.prism, fullUrl: '', thumbnailUrl: '', authorName: author),
  ),
);

void main() {
  test('tiles are named after their author when there is one', () {
    expect(_item(author: 'Ana').semanticLabel, 'Wallpaper by Ana');
    expect(_item().semanticLabel, 'Wallpaper');
    expect(_item(author: '').semanticLabel, 'Wallpaper');
  });
}
