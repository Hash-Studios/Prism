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
    core: WallpaperCore(id: 'w1', source: WallpaperSource.prism, fullUrl: '', thumbnailUrl: '', authorName: author),
  ),
);

void main() {
  testWidgets('reduced motion disables tile Hero flights and image fades', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: SizedBox(width: 120, height: 200, child: WallpaperTile(item: _item(), index: 0)),
          ),
        ),
      ),
    );
    expect(tester.widget<HeroMode>(find.byType(HeroMode)).enabled, isFalse);
  });

  testWidgets('the same wallpaper twice has distinct Hero tags', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GridView.count(
            crossAxisCount: 2,
            children: [
              WallpaperTile(item: _item(), index: 0),
              WallpaperTile(item: _item(), index: 1),
            ],
          ),
        ),
      ),
    );
    final tags = tester.widgetList<Hero>(find.byType(Hero)).map((hero) => hero.tag).toSet();
    expect(tags, hasLength(2));
  });
  testWidgets('home tiles and the upload button are named buttons for screen readers', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              SizedBox(
                width: 120,
                height: 200,
                child: WallpaperTile(item: _item(author: 'Ana'), index: 0),
              ),
              const PrismFab(),
            ],
          ),
        ),
      ),
    );

    for (final label in ['Wallpaper by Ana', 'Upload']) {
      expect(
        tester.getSemantics(find.bySemanticsLabel(label)),
        isSemantics(label: label, isButton: true, hasTapAction: true),
      );
    }
    handle.dispose();
  });
}
