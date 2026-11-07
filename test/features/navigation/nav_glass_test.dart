import 'dart:ui' as ui;

import 'package:Prism/features/navigation/views/widgets/nav_glass.dart';
import 'package:Prism/theme/contrast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final ThemeData theme = ThemeData(
    primaryColor: Colors.white,
    colorScheme: const ColorScheme.light(secondary: Colors.black),
  );

  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Center(child: child),
    ),
  );

  testWidgets('blurs the backdrop under a translucent pill colour with a hairline and a soft shadow', (tester) async {
    await pump(tester, const NavGlass(child: SizedBox(width: 120, height: 56)));

    final BackdropFilter blur = tester.widget<BackdropFilter>(find.byType(BackdropFilter));
    expect(blur.filter, ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24));

    final List<ShapeDecoration> decorations = tester
        .widgetList<DecoratedBox>(find.descendant(of: find.byType(NavGlass), matching: find.byType(DecoratedBox)))
        .map((box) => box.decoration as ShapeDecoration)
        .toList();
    final ShapeDecoration shadow = decorations.first;
    expect(shadow.shadows!.single.color, Colors.black.withValues(alpha: 0.08));
    expect(shadow.shadows!.single.blurRadius, 24);
    final ShapeDecoration tint = decorations.last;
    expect(tint.color, Colors.white.withValues(alpha: 0.72));
    final StadiumBorder edge = tint.shape as StadiumBorder;
    expect(edge.side.width, 0.5);
    expect(edge.side.color, theme.colorScheme.onSurface.withValues(alpha: 0.08));
  });

  test('a theme with low-contrast ink gets a thicker tint, just enough to stay readable over any wall', () {
    expect(NavGlass.tintOf(theme), NavGlass.tintAlpha);

    final ThemeData grey = ThemeData(
      primaryColor: Colors.white,
      colorScheme: const ColorScheme.light(secondary: Color(0xFF666666)),
    );
    final double tint = NavGlass.tintOf(grey);
    expect(tint, greaterThan(NavGlass.tintAlpha));
    expect(tint, lessThanOrEqualTo(1));
    final Color overBlack = Color.alphaBlend(Colors.white.withValues(alpha: tint), Colors.black);
    expect(contrastRatio(const Color(0xFF666666), overBlack), greaterThanOrEqualTo(4.5));
  });

  testWidgets('a circle clips to a disc', (tester) async {
    await pump(tester, const NavGlass(circle: true, child: SizedBox.square(dimension: 44)));

    final ShapeDecoration tint = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((box) => box.decoration as ShapeDecoration)
        .last;
    expect(tint.shape, isA<CircleBorder>());
    final ClipPath clip = tester.widget<ClipPath>(find.byType(ClipPath));
    final Path path = clip.clipper!.getClip(const Size(44, 44));
    expect(path.contains(const Offset(22, 22)), isTrue);
    expect(path.contains(const Offset(1, 1)), isFalse);
  });

  testWidgets('glass under one BackdropGroup shares its backdrop key', (tester) async {
    final BackdropKey key = BackdropKey();
    await pump(
      tester,
      BackdropGroup(
        backdropKey: key,
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            NavGlass(child: SizedBox(width: 80, height: 56)),
            NavGlass(circle: true, child: SizedBox.square(dimension: 56)),
          ],
        ),
      ),
    );

    final Iterable<RenderBackdropFilter> filters = tester.renderObjectList<RenderBackdropFilter>(
      find.byType(BackdropFilter),
    );
    expect(filters, hasLength(2));
    expect(filters.every((filter) => filter.backdropKey == key), isTrue);
  });
}
