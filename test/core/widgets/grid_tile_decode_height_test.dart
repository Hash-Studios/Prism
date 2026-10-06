import 'package:Prism/core/widgets/prism_image_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<int> decodeHeight(WidgetTester tester, {required double dpr, required int columns}) async {
    tester.view.physicalSize = Size(900 * dpr / 3, 1600);
    tester.view.devicePixelRatio = dpr;
    addTearDown(tester.view.reset);
    late int result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            result = gridTileDecodeHeight(context, crossAxisCount: columns);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return result;
  }

  testWidgets('decode height follows the real device pixel ratio', (tester) async {
    expect(await decodeHeight(tester, dpr: 1, columns: 3), 200);
    expect(await decodeHeight(tester, dpr: 3, columns: 3), 600);
  });

  testWidgets('more columns mean a smaller decode height', (tester) async {
    expect(await decodeHeight(tester, dpr: 2, columns: 5), 240);
  });
}
