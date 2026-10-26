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
    final rect = tester.getRect(find.byKey(const ValueKey('tile-99')));
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.bottom, lessThanOrEqualTo(600));
  });

  testWidgets('reveal accounts for a pinned header when checking whether a tile is visible', (tester) async {
    final controller = ScrollController();
    late BuildContext grid;
    await tester.pumpWidget(
      MaterialApp(
        home: CustomScrollView(
          controller: controller,
          slivers: [
            const SliverAppBar(pinned: true, toolbarHeight: 80, title: Text('Pinned')),
            SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisExtent: 500),
              itemCount: 100,
              itemBuilder: (context, i) {
                if (i == 0) grid = context;
                return SizedBox(key: ValueKey('tile-$i'));
              },
            ),
          ],
        ),
      ),
    );

    final feed = _feed(grid);
    controller.jumpTo(620);
    await tester.pump();
    final before = tester.getRect(find.byKey(const ValueKey('tile-2')));
    expect(before.top, lessThan(80));

    feed.reveal(2);
    await tester.pump();

    final after = tester.getRect(find.byKey(const ValueKey('tile-2')));
    expect(after.top, greaterThanOrEqualTo(80));
    expect(after.center.dy, closeTo(340, 1));
  });

  testWidgets('reveal keeps working when the tapped child element is rebuilt away', (tester) async {
    final controller = ScrollController();
    BuildContext? tappedTile;

    Widget buildGrid({required bool includeOriginal}) => MaterialApp(
      home: CustomScrollView(
        controller: controller,
        slivers: [
          SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2),
            itemCount: 100,
            itemBuilder: (context, i) {
              if (i == 0) {
                return Builder(
                  key: ValueKey(includeOriginal ? 'original' : 'replacement'),
                  builder: (tileContext) {
                    if (includeOriginal) {
                      tappedTile = tileContext;
                    }
                    return const SizedBox();
                  },
                );
              }
              return SizedBox(key: ValueKey('tile-$i'));
            },
          ),
        ],
      ),
    );

    await tester.pumpWidget(buildGrid(includeOriginal: true));
    final feed = _feed(tappedTile!);
    await tester.pumpWidget(buildGrid(includeOriginal: false));
    expect(tappedTile!.mounted, isFalse);

    feed.reveal(60);
    await tester.pump();

    expect(tester.getRect(find.byKey(const ValueKey('tile-60'))).center.dy, closeTo(300, 1));
  });

  testWidgets('reveal locates a tile in a NestedScrollView inner grid', (tester) async {
    final outer = ScrollController();
    late BuildContext grid;
    await tester.pumpWidget(
      MaterialApp(
        home: NestedScrollView(
          controller: outer,
          headerSliverBuilder: (context, _) => [
            SliverOverlapAbsorber(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
              sliver: const SliverAppBar(pinned: true, toolbarHeight: 80, expandedHeight: 120, title: Text('Nested')),
            ),
          ],
          body: Builder(
            builder: (context) => CustomScrollView(
              slivers: [
                SliverOverlapInjector(handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context)),
                SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2),
                  itemCount: 100,
                  itemBuilder: (context, i) {
                    if (i == 0) grid = context;
                    return SizedBox(key: ValueKey('nested-$i'));
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );

    _feed(grid).reveal(60);
    await tester.pump();

    final rect = tester.getRect(find.byKey(const ValueKey('nested-60')));
    expect(rect.top, greaterThanOrEqualTo(80));
    expect(rect.bottom, lessThanOrEqualTo(600));
    expect(outer.offset, greaterThan(0));
  });

  testWidgets('reveal centres a tile in a reversed grid', (tester) async {
    final controller = ScrollController();
    late BuildContext grid;
    await tester.pumpWidget(
      MaterialApp(
        home: CustomScrollView(
          controller: controller,
          reverse: true,
          slivers: [
            SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2),
              itemCount: 100,
              itemBuilder: (context, i) {
                if (i == 0) grid = context;
                return SizedBox(key: ValueKey('reverse-$i'));
              },
            ),
          ],
        ),
      ),
    );

    _feed(grid).reveal(60);
    await tester.pump();

    expect(tester.getRect(find.byKey(const ValueKey('reverse-60'))).center.dy, closeTo(300, 1));
  });

  testWidgets('reveal centres a tile in a horizontal grid', (tester) async {
    final controller = ScrollController();
    late BuildContext grid;
    await tester.pumpWidget(
      MaterialApp(
        home: CustomScrollView(
          controller: controller,
          scrollDirection: Axis.horizontal,
          slivers: [
            SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2),
              itemCount: 100,
              itemBuilder: (context, i) {
                if (i == 0) grid = context;
                return SizedBox(key: ValueKey('horizontal-$i'));
              },
            ),
          ],
        ),
      ),
    );

    _feed(grid).reveal(60);
    await tester.pump();

    expect(tester.getRect(find.byKey(const ValueKey('horizontal-60'))).center.dx, closeTo(400, 1));
  });

  testWidgets('reveal safely no-ops during initial grid layout and works after layout', (tester) async {
    final controller = ScrollController();
    late WallpaperFeed feed;
    var attemptedBeforeLayout = false;
    await tester.pumpWidget(
      MaterialApp(
        home: CustomScrollView(
          controller: controller,
          slivers: [
            SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2),
              itemCount: 100,
              itemBuilder: (context, i) {
                if (i == 0) {
                  feed = _feed(context);
                  feed.reveal(60);
                  attemptedBeforeLayout = true;
                }
                return SizedBox(key: ValueKey('offstage-$i'));
              },
            ),
          ],
        ),
      ),
    );

    expect(attemptedBeforeLayout, isTrue);
    expect(controller.offset, 0);
    feed.reveal(60);
    await tester.pump();

    expect(tester.getRect(find.byKey(const ValueKey('offstage-60'))).center.dy, closeTo(300, 1));
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
