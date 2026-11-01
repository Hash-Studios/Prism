import 'package:Prism/core/wallpaper/wallpaper_display_source.dart';
import 'package:Prism/core/widgets/progressive_wallpaper_image.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/duo_reveal_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(WidgetTester tester, {required bool unfolded, bool reduceMotion = false}) => tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              height: 400,
              child: DuoRevealView(
                unfolded: unfolded,
                image: const ProgressiveWallpaperImage(
                  display: WallpaperDisplaySource(thumbnail: '', full: 'assets/images/prism.webp'),
                  decodeBox: Size(2670, 1878),
                ),
                overlay: const SizedBox(key: ValueKey<String>('clock')),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Size visibleSize(WidgetTester tester) => tester.getSize(find.byType(ClipRRect));

  testWidgets('both states preserve the full-image element, URL and fixed decode size', (tester) async {
    await pump(tester, unfolded: false);
    await tester.pumpAndSettle();
    final Element image = tester.element(find.byType(ProgressiveWallpaperImage));
    expect(visibleSize(tester).aspectRatio, closeTo(1398 / 2034, 1e-10));
    expect(find.byKey(const ValueKey<String>('clock')), findsOneWidget);

    await pump(tester, unfolded: true);
    await tester.pumpAndSettle();
    expect(visibleSize(tester).aspectRatio, closeTo(2670 / 1878, 1e-10));
    expect(tester.element(find.byType(ProgressiveWallpaperImage)), same(image));
    final ProgressiveWallpaperImage widget = tester.widget(find.byType(ProgressiveWallpaperImage));
    expect(widget.display.full, 'assets/images/prism.webp');
    expect(widget.decodeBox, const Size(2670, 1878));
    expect(find.byKey(const ValueKey<String>('clock')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a reveal reverses from its current presentation without remounting the image', (tester) async {
    await pump(tester, unfolded: false);
    await tester.pumpAndSettle();
    final double folded = visibleSize(tester).width;
    final Element image = tester.element(find.byType(ProgressiveWallpaperImage));
    await pump(tester, unfolded: true);
    await tester.pump(const Duration(milliseconds: 40));
    final double midway = visibleSize(tester).width;
    expect(midway, greaterThan(folded));
    expect(midway, lessThan(400));
    await pump(tester, unfolded: false);
    expect(visibleSize(tester).width, closeTo(midway, 1e-6));
    await tester.pumpAndSettle();
    expect(visibleSize(tester).width, closeTo(folded, 1e-6));
    expect(tester.element(find.byType(ProgressiveWallpaperImage)), same(image));
  });

  testWidgets('reduced motion reaches either endpoint immediately', (tester) async {
    await pump(tester, unfolded: false, reduceMotion: true);
    expect(visibleSize(tester).aspectRatio, closeTo(1398 / 2034, 1e-10));
    await pump(tester, unfolded: true, reduceMotion: true);
    expect(visibleSize(tester).aspectRatio, closeTo(2670 / 1878, 1e-10));
    await pump(tester, unfolded: false, reduceMotion: true);
    expect(visibleSize(tester).aspectRatio, closeTo(1398 / 2034, 1e-10));
  });
}
