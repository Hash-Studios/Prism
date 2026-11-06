import 'package:Prism/features/personalized_feed/views/widgets/feed_loading_more.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the loading row has a 16 px side margin, 8 px gaps and rounded tiles', (tester) async {
    tester.view.physicalSize = const Size(600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: FeedLoadingMore(columns: 3)),
      ),
    );

    final Finder tiles = find.byType(AspectRatio);
    expect(tiles, findsNWidgets(3));
    const double tileWidth = (600 - 2 * 16 - 2 * 8) / 3;
    for (int i = 0; i < 3; i++) {
      final Rect rect = tester.getRect(tiles.at(i));
      expect(rect.left, closeTo(16 + i * (tileWidth + 8), 0.01));
      expect(rect.width, closeTo(tileWidth, 0.01));
    }
    expect(tester.getRect(tiles.last).right, closeTo(584, 0.01));
    expect(tester.getTopLeft(tiles.first).dy, 8);
    final Finder bone = find.descendant(of: tiles.first, matching: find.byType(DecoratedBox));
    expect(((tester.widget<DecoratedBox>(bone).decoration) as BoxDecoration).borderRadius, BorderRadius.circular(12));
  });
}
