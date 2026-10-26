import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/wallpaper_detail/views/wallpaper_feed.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

FeedItemEntity _item(String id) => FeedItemEntity.prism(
  id: id,
  wallpaper: PrismWallpaper(
    core: WallpaperCore(
      id: id,
      source: WallpaperSource.prism,
      fullUrl: 'https://example.com/$id.jpg',
      thumbnailUrl: 'https://example.com/$id-thumb.jpg',
    ),
  ),
);

/// Pumps a 300 pt header, then a 3-column grid of 100 tiles. Returns the context of the first tile's builder.
Future<BuildContext> _pumpGrid(WidgetTester tester, ScrollController controller) async {
  late BuildContext gridContext;
  await tester.pumpWidget(
    MaterialApp(
      home: CustomScrollView(
        controller: controller,
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 300)),
          SliverPadding(
            padding: const EdgeInsets.all(8),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
              ),
              itemCount: 100,
              itemBuilder: (context, i) {
                if (i == 0) gridContext = context;
                return SizedBox(key: ValueKey('tile-$i'));
              },
            ),
          ),
        ],
      ),
    ),
  );
  return gridContext;
}

WallpaperFeed _feed(BuildContext grid) =>
    WallpaperFeed(grid: grid, tiles: [for (var i = 0; i < 100; i++) (item: _item('$i'), index: i, heroTag: 't$i')]);

void main() {
  testWidgets('indexOf finds a wall by source and id', (tester) async {
    final grid = await _pumpGrid(tester, ScrollController());
    final feed = _feed(grid);

    expect(feed.indexOf(_item('7')), 7);
    expect(feed.indexOf(_item('missing')), -1);
  });

  testWidgets('reveal centres a tile that is off screen', (tester) async {
    final controller = ScrollController();
    final grid = await _pumpGrid(tester, controller);

    _feed(grid).reveal(60);
    await tester.pump();

    final rect = tester.getRect(find.byKey(const ValueKey('tile-60')));
    expect((rect.center.dy - 300).abs(), lessThan(1.0));
    expect(controller.offset, greaterThan(0));
  });

  testWidgets('reveal leaves the grid alone when the tile is on screen', (tester) async {
    final controller = ScrollController();
    final grid = await _pumpGrid(tester, controller);

    controller.jumpTo(300);
    await tester.pump();

    final rect = tester.getRect(find.byKey(const ValueKey('tile-0')));
    expect(const Rect.fromLTWH(0, 0, 800, 600).contains(rect.topLeft), isTrue);
    expect(const Rect.fromLTWH(0, 0, 800, 600).contains(rect.bottomRight), isTrue);

    final before = controller.offset;
    _feed(grid).reveal(0);
    await tester.pump();

    expect(controller.offset, before);
  });

  testWidgets('reveal stops at the end of the grid', (tester) async {
    final controller = ScrollController();
    final grid = await _pumpGrid(tester, controller);

    _feed(grid).reveal(99);
    await tester.pump();

    expect(controller.offset, controller.position.maxScrollExtent);
  });

  testWidgets('reveal does nothing outside a grid', (tester) async {
    final controller = ScrollController();
    late BuildContext listContext;
    await tester.pumpWidget(
      MaterialApp(
        home: CustomScrollView(
          controller: controller,
          slivers: [
            const SliverToBoxAdapter(child: SizedBox(height: 300)),
            SliverList.builder(
              itemCount: 100,
              itemBuilder: (context, i) {
                if (i == 0) listContext = context;
                return SizedBox(key: ValueKey('tile-$i'), height: 260);
              },
            ),
          ],
        ),
      ),
    );

    _feed(listContext).reveal(60);
    await tester.pump();

    expect(controller.offset, 0);
  });

  testWidgets('reveal does nothing once the grid is gone', (tester) async {
    final grid = await _pumpGrid(tester, ScrollController());
    final feed = _feed(grid);

    await tester.pumpWidget(const SizedBox());

    expect(() => feed.reveal(60), returnsNormally);
  });
}
