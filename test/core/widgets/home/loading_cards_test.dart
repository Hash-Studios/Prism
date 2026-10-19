import 'package:Prism/core/widgets/home/wallpapers/loading.dart';
import 'package:Prism/core/widgets/prism/prism_wall_grid.dart';
import 'package:Prism/core/widgets/pulse_placeholder.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  GridView grid(WidgetTester tester) => tester.widget<GridView>(find.byType(GridView));

  BorderRadius? firstBoneRadius(WidgetTester tester) {
    final Finder bone = find.descendant(of: find.byType(GridView), matching: find.byType(DecoratedBox)).first;
    return (tester.widget<DecoratedBox>(bone).decoration as BoxDecoration).borderRadius as BorderRadius?;
  }

  Future<void> pumpAt600(WidgetTester tester, Widget cards) async {
    tester.view.physicalSize = const Size(600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: cards),
      ),
    );
  }

  testWidgets('the skeleton has the columns, tile ratio and margins of the wallpaper grids by default', (tester) async {
    await pumpAt600(tester, const LoadingCards());

    final delegate = grid(tester).gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, wallpaperGridColumns(600));
    expect(delegate.childAspectRatio, PrismFeedLayout.gridTileAspectRatio);
    expect(delegate.mainAxisSpacing, PrismWallGrid.spacing);
    expect(delegate.crossAxisSpacing, PrismWallGrid.spacing);
    expect(grid(tester).padding, PrismWallGrid.padding);
    expect(firstBoneRadius(tester), PrismWallGrid.tileRadius);
    expect(grid(tester).physics, isA<NeverScrollableScrollPhysics>());
  });

  testWidgets('the home skeleton has a 4 px side margin, 4 px gaps and rounded bones', (tester) async {
    await pumpAt600(tester, const LoadingCards(useFeedLayout: true));

    final delegate = grid(tester).gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, wallpaperGridColumns(600));
    expect(delegate.childAspectRatio, PrismFeedLayout.gridTileAspectRatio);
    expect(delegate.mainAxisSpacing, 4);
    expect(delegate.crossAxisSpacing, 4);
    expect(grid(tester).padding, const EdgeInsets.symmetric(horizontal: 4));
    expect(firstBoneRadius(tester), BorderRadius.circular(12));
    expect(tester.getTopLeft(find.byType(GridView)).dx, 0);
    expect(tester.getTopLeft(find.byType(PulseFill).first).dx, 4);
  });
}
