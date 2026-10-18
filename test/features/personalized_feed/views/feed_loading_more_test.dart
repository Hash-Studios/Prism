import 'package:Prism/features/personalized_feed/views/widgets/feed_loading_more.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the loading row has a 4 px side margin, 4 px gaps and rounded tiles', (tester) async {
    tester.view.physicalSize = const Size(600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: FeedLoadingMore(columns: 3))));

    final Finder tiles = find.byType(AspectRatio);
    expect(tiles, findsNWidgets(3));
    const double tileWidth = (600 - 4 * 4) / 3;
    for (int i = 0; i < 3; i++) {
      final Rect rect = tester.getRect(tiles.at(i));
      expect(rect.left, closeTo(4 + i * (tileWidth + 4), 0.01));
      expect(rect.width, closeTo(tileWidth, 0.01));
    }
    expect(tester.getRect(tiles.last).right, closeTo(596, 0.01));
    expect(tester.getTopLeft(tiles.first).dy, 4);
    final Finder bone = find.descendant(of: tiles.first, matching: find.byType(DecoratedBox));
    expect(((tester.widget<DecoratedBox>(bone).decoration) as BoxDecoration).borderRadius, BorderRadius.circular(12));
  });
}
