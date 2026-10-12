import 'package:Prism/core/widgets/home/wallpapers/carousel_dots.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _dots({required int current, bool reduceMotion = false}) {
  return MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
      child: child!,
    ),
    home: Scaffold(body: CarouselDots(current: current, count: 4)),
  );
}

void main() {
  final Finder dots = find.descendant(of: find.byType(AnimatedContainer), matching: find.byType(DecoratedBox));

  List<Size> sizes(WidgetTester tester) => [for (int i = 0; i < 4; i++) tester.getSize(dots.at(i))];

  BoxDecoration decorationOf(WidgetTester tester, int index) =>
      tester.widget<DecoratedBox>(dots.at(index)).decoration as BoxDecoration;

  List<Color?> colours(WidgetTester tester) => [for (int i = 0; i < 4; i++) decorationOf(tester, i).color];

  testWidgets('the active dot is a 16 by 6 pill and the others are 6 by 6 dots', (tester) async {
    await tester.pumpWidget(_dots(current: 1));

    expect(sizes(tester), const <Size>[Size(6, 6), Size(16, 6), Size(6, 6), Size(6, 6)]);
    expect(colours(tester), const <Color>[Colors.white54, Colors.white, Colors.white54, Colors.white54]);
  });

  testWidgets('each dot carries a 3 blur shadow so it reads on a bright wall', (tester) async {
    await tester.pumpWidget(_dots(current: 0));

    final BoxShadow shadow = decorationOf(tester, 0).boxShadow!.single;

    expect(shadow.blurRadius, 3);
    expect(shadow.color, Colors.black26);
  });

  testWidgets('the pill moves to the next dot in 250 ms and the row keeps its width', (tester) async {
    await tester.pumpWidget(_dots(current: 0));
    final double rowWidth = sizes(tester).fold(0.0, (sum, size) => sum + size.width);

    await tester.pumpWidget(_dots(current: 1));
    await tester.pump(const Duration(milliseconds: 100));

    final List<Size> mid = sizes(tester);
    expect(mid[0].width, inExclusiveRange(6, 16));
    expect(mid[1].width, inExclusiveRange(6, 16));
    expect(mid.fold(0.0, (sum, size) => sum + size.width), closeTo(rowWidth, 0.01));

    await tester.pump(const Duration(milliseconds: 150));

    expect(sizes(tester), const <Size>[Size(6, 6), Size(16, 6), Size(6, 6), Size(6, 6)]);
    expect(colours(tester), const <Color>[Colors.white54, Colors.white, Colors.white54, Colors.white54]);
  });

  testWidgets('the pill jumps when the system asks for less motion', (tester) async {
    await tester.pumpWidget(_dots(current: 0, reduceMotion: true));

    await tester.pumpWidget(_dots(current: 2, reduceMotion: true));
    await tester.pump();

    expect(sizes(tester), const <Size>[Size(6, 6), Size(6, 6), Size(16, 6), Size(6, 6)]);
  });
}
