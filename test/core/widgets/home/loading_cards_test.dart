import 'package:Prism/core/widgets/home/wallpapers/loading.dart';
import 'package:Prism/core/widgets/prism/prism_wall_grid.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  GridView grid(WidgetTester tester) => tester.widget<GridView>(find.byType(GridView));

  testWidgets('the skeleton has the columns, tile ratio and padding of the wallpaper grids', (tester) async {
    tester.view.physicalSize = const Size(600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: LoadingCards(useFeedLayout: true))));

    final delegate = grid(tester).gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, wallpaperGridColumns(600));
    expect(delegate.childAspectRatio, PrismFeedLayout.gridTileAspectRatio);
    expect(delegate.mainAxisSpacing, PrismWallGrid.spacing);
    expect(grid(tester).padding, PrismWallGrid.padding);
    expect(grid(tester).physics, isA<NeverScrollableScrollPhysics>());
  });
}
