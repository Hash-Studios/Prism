import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/folders/views/widgets/folder_cover.dart';
import 'package:Prism/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

List<String> _urls(int count) => List<String>.generate(count, (i) => 'https://example.com/$i.jpg');

Future<void> _pump(WidgetTester tester, List<String> covers, {double size = 120}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: kLightTheme,
      home: Scaffold(
        body: Center(
          child: FolderCover(covers: covers, size: size),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('no covers shows the folder icon and no image tiles', (tester) async {
    await _pump(tester, const <String>[]);

    expect(find.byType(PrismImageTile), findsNothing);
    expect(find.byIcon(Icons.folder_rounded), findsOneWidget);
  });

  testWidgets('one cover fills the square', (tester) async {
    await _pump(tester, _urls(1));

    expect(find.byType(PrismImageTile), findsOneWidget);
    expect(tester.getSize(find.byType(PrismImageTile)), const Size(120, 120));
    expect(find.byIcon(Icons.folder_rounded), findsNothing);
  });

  testWidgets('two covers split the square into two columns with a 2 px gap', (tester) async {
    await _pump(tester, _urls(2));

    final Finder tiles = find.byType(PrismImageTile);
    expect(tiles, findsNWidgets(2));
    expect(tester.getSize(tiles.at(0)), const Size(59, 120));
    expect(tester.getSize(tiles.at(1)), const Size(59, 120));
    expect(tester.getTopLeft(tiles.at(1)).dx - tester.getTopLeft(tiles.at(0)).dx, 61);
    expect(find.byIcon(Icons.folder_rounded), findsNothing);
  });

  testWidgets('three covers put the newest on the left half and stack the other two on the right', (tester) async {
    await _pump(tester, _urls(3));

    final Finder tiles = find.byType(PrismImageTile);
    expect(tiles, findsNWidgets(3));
    expect(tester.getSize(tiles.at(0)), const Size(59, 120));
    expect(tester.getSize(tiles.at(1)), const Size(59, 59));
    expect(tester.getSize(tiles.at(2)), const Size(59, 59));
    expect(tester.getTopLeft(tiles.at(2)).dy - tester.getTopLeft(tiles.at(1)).dy, 61);
    expect(find.byIcon(Icons.folder_rounded), findsNothing);
  });

  testWidgets('four covers make a 2x2 grid of squares', (tester) async {
    await _pump(tester, _urls(4));

    final Finder tiles = find.byType(PrismImageTile);
    expect(tiles, findsNWidgets(4));
    for (int i = 0; i < 4; i++) {
      expect(tester.getSize(tiles.at(i)), const Size(59, 59));
    }
    expect(find.byIcon(Icons.folder_rounded), findsNothing);
  });

  testWidgets('more than four covers shows only the first four', (tester) async {
    await _pump(tester, _urls(6));

    final Finder tiles = find.byType(PrismImageTile);
    expect(tiles, findsNWidgets(4));
    final List<String> urls = tester.widgetList<PrismImageTile>(tiles).map((tile) => tile.url).toList();
    expect(urls, _urls(4));
    expect(find.byIcon(Icons.folder_rounded), findsNothing);
  });

  testWidgets('a 40 px cover uses a 1 px gap, as in the folder sheet', (tester) async {
    await _pump(tester, _urls(4), size: 40);

    final Finder tiles = find.byType(PrismImageTile);
    expect(tiles, findsNWidgets(4));
    for (int i = 0; i < 4; i++) {
      expect(tester.getSize(tiles.at(i)), const Size(19.5, 19.5));
    }
    expect(tester.getTopLeft(tiles.at(1)).dx - tester.getTopLeft(tiles.at(0)).dx, 20.5);
  });

  testWidgets('the cover excludes its images from semantics', (tester) async {
    await _pump(tester, _urls(2));

    expect(find.descendant(of: find.byType(FolderCover), matching: find.byType(ExcludeSemantics)), findsWidgets);
  });
}
