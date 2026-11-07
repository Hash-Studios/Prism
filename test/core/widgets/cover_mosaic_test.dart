import 'package:Prism/core/widgets/glint/cover_mosaic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host({bool reduceMotion = false}) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: const Center(
        child: SizedBox(width: 240, height: 200, child: CoverMosaic(seed: 'Prism Premium')),
      ),
    ),
  );

  List<String> shownAssets(WidgetTester tester) =>
      tester.widgetList<Image>(find.byType(Image)).map((Image image) => (image.image as AssetImage).assetName).toList();

  test('the start is stable for a seed and inside the cover list', () {
    expect(coverMosaicStart('Downloads'), coverMosaicStart('Downloads'));
    for (final String seed in <String>['', 'About', 'No downloads yet', 'Invite friends']) {
      expect(coverMosaicStart(seed), inInclusiveRange(0, kCoverMosaicAssets.length - 1));
    }
    expect(kCoverMosaicAssets.toSet(), hasLength(kCoverMosaicAssets.length));
  });

  testWidgets('shows 3 different covers and crossfades one tile every 6 s without repeats', (tester) async {
    await tester.pumpWidget(host());
    List<String> previous = shownAssets(tester);
    expect(previous.toSet(), hasLength(3));
    expect(tester.getSize(find.byType(ClipRRect).first).height, 200, reason: 'the tall tile fills the height');

    const Duration settle = Duration(milliseconds: 1500);
    await tester.pump(CoverMosaic.interval);
    for (int tick = 0; tick < 12; tick++) {
      await tester.pump();
      await tester.pump(settle);
      final List<String> now = shownAssets(tester);
      expect(now.toSet(), hasLength(3), reason: 'no cover shows twice at tick $tick');
      int changed = 0;
      for (int i = 0; i < 3; i++) {
        if (now[i] != previous[i]) changed++;
      }
      expect(changed, 1, reason: 'one tile changes per tick');
      previous = now;
      await tester.pump(CoverMosaic.interval - settle);
    }
  });

  testWidgets('a wide banner lays the 3 tiles out as columns of full height', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(width: 360, height: 132, child: CoverMosaic(seed: 'Prism Premium')),
        ),
      ),
    );
    final List<Rect> tiles = find
        .byType(ClipRRect)
        .evaluate()
        .map((e) => tester.getRect(find.byWidget(e.widget)))
        .toList();
    expect(tiles, hasLength(3));
    for (final Rect tile in tiles) {
      expect(tile.height, 132);
      expect(tile.width, closeTo((360 - 8) / 3, 0.01));
    }
  });

  testWidgets('switches an in-progress crossfade to zero duration when reduce motion turns on', (tester) async {
    await tester.pumpWidget(host());
    await tester.pump(CoverMosaic.interval);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.widget<AnimatedSwitcher>(find.byType(AnimatedSwitcher).first).duration, CoverMosaic.crossfade);

    await tester.pumpWidget(host(reduceMotion: true));
    expect(
      find.byType(AnimatedSwitcher),
      findsNothing,
      reason: 'an active fade is removed, not just prevented from restarting',
    );
  });

  testWidgets('holds still under reduce motion', (tester) async {
    await tester.pumpWidget(host(reduceMotion: true));
    final List<String> before = shownAssets(tester);
    await tester.pump(CoverMosaic.interval * 3);
    expect(shownAssets(tester), before);
  });

  testWidgets('the badge sits on the bottom-end corner and hangs below the art', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(
            width: 240,
            height: 220,
            child: CoverMosaic(
              seed: 'T',
              badge: SizedBox.square(dimension: 56, key: Key('badge')),
            ),
          ),
        ),
      ),
    );
    final Rect box = tester.getRect(find.byType(CoverMosaic));
    final Rect badge = tester.getRect(find.byKey(const Key('badge')));
    final Rect art = tester.getRect(find.byType(ClipRRect).first);
    expect(art.bottom, box.bottom - 20);
    expect(badge.bottom, greaterThan(art.bottom));
    expect(badge.right, greaterThan(box.center.dx));
  });
}
