import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/category_feed/views/widgets/wallpaper_tile.dart';
import 'package:Prism/features/navigation/views/widgets/prism_fab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

FeedItemEntity _item({String? author}) => FeedItemEntity.prism(
  id: 'w1',
  wallpaper: PrismWallpaper(
    core: WallpaperCore(
      id: 'w1',
      source: WallpaperSource.prism,
      fullUrl: '',
      thumbnailUrl: '',
      authorName: author,
    ),
  ),
);

void main() {
  test('tiles are named after their author when there is one', () {
    expect(_item(author: 'Ana').semanticLabel, 'Wallpaper by Ana');
    expect(_item().semanticLabel, 'Wallpaper');
    expect(_item(author: '').semanticLabel, 'Wallpaper');
  });

  testWidgets('home tiles and the upload button are named buttons for screen readers', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              SizedBox(width: 120, height: 200, child: WallpaperTile(item: _item(author: 'Ana'), index: 0)),
              const PrismFab(),
            ],
          ),
        ),
      ),
    );

    for (final label in ['Wallpaper by Ana', 'Upload']) {
      expect(
        tester.getSemantics(find.bySemanticsLabel(label)),
        containsSemantics(label: label, isButton: true, hasTapAction: true),
      );
    }
    handle.dispose();
  });
}
