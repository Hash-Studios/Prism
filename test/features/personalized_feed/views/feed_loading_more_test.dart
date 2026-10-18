import 'package:Prism/features/personalized_feed/views/widgets/feed_loading_more.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the loading row is edge to edge with 2 px gaps and square tiles', (tester) async {
    tester.view.physicalSize = const Size(600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: FeedLoadingMore(columns: 3))));

    final Finder tiles = find.byType(AspectRatio);
    expect(tiles, findsNWidgets(3));
    const double tileWidth = (600 - 2 * PrismFeedLayout.gridSpacing) / 3;
    for (int i = 0; i < 3; i++) {
      final Rect rect = tester.getRect(tiles.at(i));
      expect(rect.left, closeTo(i * (tileWidth + PrismFeedLayout.gridSpacing), 0.01));
      expect(rect.width, closeTo(tileWidth, 0.01));
    }
    expect(tester.getRect(tiles.last).right, closeTo(600, 0.01));
    expect(tester.getTopLeft(tiles.first).dy, PrismFeedLayout.gridSpacing);
    for (final Element bone in find.byType(DecoratedBox).evaluate()) {
      expect(((bone.widget as DecoratedBox).decoration as BoxDecoration).borderRadius, isNull);
    }
  });
}
