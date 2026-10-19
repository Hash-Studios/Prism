import 'package:Prism/features/personalized_feed/views/widgets/feed_carousel.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _dots({required int current, bool reduceMotion = false}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,

    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
      child: child!,
    ),
    home: Scaffold(body: FeedCarouselDots(current: current, count: 4)),
  );
}

void main() {
  final Finder dots = find.descendant(of: find.byType(AnimatedContainer), matching: find.byType(DecoratedBox));

  List<Size> sizes(WidgetTester tester) => [for (int i = 0; i < 4; i++) tester.getSize(dots.at(i))];

  BoxDecoration decorationOf(WidgetTester tester, int index) =>
      tester.widget<DecoratedBox>(dots.at(index)).decoration as BoxDecoration;

  List<Color?> colours(WidgetTester tester) => [for (int i = 0; i < 4; i++) decorationOf(tester, i).color];

  testWidgets('the active dot is a 16 by 6 white pill and the others are 6 by 6 dots at half white', (tester) async {
    await tester.pumpWidget(_dots(current: 1));

    expect(sizes(tester), const <Size>[Size(6, 6), Size(16, 6), Size(6, 6), Size(6, 6)]);
    expect(colours(tester), <Color>[
      Colors.white.withValues(alpha: 0.5),
      Colors.white,
      Colors.white.withValues(alpha: 0.5),
      Colors.white.withValues(alpha: 0.5),
    ]);
  });

  testWidgets('every dot casts a soft shadow so it reads over a bright image', (tester) async {
    await tester.pumpWidget(_dots(current: 0));

    for (int i = 0; i < 4; i++) {
      expect(decorationOf(tester, i).boxShadow, isNotEmpty);
    }
  });

  testWidgets('the dots do not take touches, so a swipe or a tap reaches the page under them', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: Scaffold(
          body: Stack(
            children: <Widget>[
              Positioned.fill(child: GestureDetector(onTap: () => taps++)),
              const Positioned(left: 0, right: 0, bottom: 8, child: FeedCarouselDots(current: 0, count: 4)),
            ],
          ),
        ),
      ),
    );

    await tester.tap(dots.first, warnIfMissed: false);

    expect(taps, 1);
  });

  testWidgets('the pill moves to the next dot and the row keeps its width', (tester) async {
    await tester.pumpWidget(_dots(current: 0));
    final double rowWidth = sizes(tester).fold(0.0, (sum, size) => sum + size.width);

    await tester.pumpWidget(_dots(current: 1));
    await tester.pump(const Duration(milliseconds: 60));

    final List<Size> mid = sizes(tester);
    expect(mid[0].width, inExclusiveRange(6, 16));
    expect(mid[1].width, inExclusiveRange(6, 16));
    expect(mid.fold(0.0, (sum, size) => sum + size.width), closeTo(rowWidth, 0.01));

    await tester.pump(const Duration(milliseconds: 200));

    expect(sizes(tester), const <Size>[Size(6, 6), Size(16, 6), Size(6, 6), Size(6, 6)]);
  });

  testWidgets('the pill jumps when the system asks for less motion', (tester) async {
    await tester.pumpWidget(_dots(current: 0, reduceMotion: true));

    await tester.pumpWidget(_dots(current: 2, reduceMotion: true));
    await tester.pump();

    expect(sizes(tester), const <Size>[Size(6, 6), Size(6, 6), Size(16, 6), Size(6, 6)]);
  });
}
