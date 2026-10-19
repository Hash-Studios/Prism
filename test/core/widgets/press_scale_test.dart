import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:Prism/core/widgets/animated/press_scale.dart';
import 'package:Prism/core/widgets/prism_glass.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

class _Stripes extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = Colors.white;
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.black);
    for (double x = 0; x < size.width; x += 4) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 2, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_Stripes oldDelegate) => false;
}

void main() {
  testWidgets('settles a held press when reduce motion changes', (tester) async {
    Widget host(bool reduce) => MediaQuery(
      data: MediaQueryData(disableAnimations: reduce),
      child: const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: PressScale(child: SizedBox(width: 100, height: 100))),
      ),
    );
    await tester.pumpWidget(host(false));
    final TestGesture gesture = await tester.startGesture(tester.getCenter(find.byType(PressScale)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final Finder transform = find.descendant(of: find.byType(PressScale), matching: find.byType(Transform));
    expect(tester.widget<Transform>(transform).transform.storage[0], lessThan(1));

    await tester.pumpWidget(host(true));
    expect(tester.widget<Transform>(transform).transform.storage[0], 1);
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.widget<Transform>(transform).transform.storage[0], 1);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('scales down on press, returns after release, and keeps child taps', (tester) async {
    int taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: Center(
          child: PressScale(
            child: GestureDetector(
              onTap: () => taps++,
              child: const SizedBox(width: 100, height: 100, child: ColoredBox(color: Colors.red)),
            ),
          ),
        ),
      ),
    );
    double scale() => tester
        .widget<Transform>(find.descendant(of: find.byType(PressScale), matching: find.byType(Transform)))
        .transform
        .storage[0];

    expect(scale(), 1);
    final TestGesture g = await tester.startGesture(tester.getCenter(find.byType(PressScale)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(scale(), lessThan(1));
    await g.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(scale(), 1);
    expect(taps, 1);
  });

  testWidgets('presses down at once and lets go at once, with no slow start either way', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: Center(child: PressScale(child: SizedBox(width: 100, height: 100))),
      ),
    );
    final Finder transform = find.descendant(of: find.byType(PressScale), matching: find.byType(Transform));

    final TestGesture finger = await tester.startGesture(tester.getCenter(find.byType(PressScale)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));

    expect(tester.widget<Transform>(transform).transform.storage[0], lessThan(0.975));
    await tester.pump(const Duration(milliseconds: 100));
    await finger.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.widget<Transform>(transform).transform.storage[0], greaterThan(0.985));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.widget<Transform>(transform).transform.storage[0], 1);
  });

  testWidgets('a glass pill inside keeps its blurred backdrop while it is pressed', (tester) async {
    final GlobalKey boundary = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,

          home: Stack(
            children: <Widget>[
              Positioned.fill(child: CustomPaint(painter: _Stripes())),
              const Center(
                child: SizedBox(
                  width: 200,
                  height: 80,
                  child: PressScale(child: PrismGlass(borderRadius: 24, child: SizedBox.expand())),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    Future<int> stripeContrast() async {
      final RenderRepaintBoundary render = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final ui.Image image = (await tester.runAsync(() => render.toImage()))!;
      final ByteData pixels = (await tester.runAsync<ByteData?>(() => image.toByteData()))!;
      final Offset centre = tester.getCenter(find.byType(PrismGlass));
      final int y = centre.dy.toInt();
      int lowest = 255;
      int highest = 0;
      for (int x = centre.dx.toInt() - 30; x < centre.dx.toInt() + 30; x++) {
        final int red = pixels.getUint8((y * image.width + x) * 4);
        if (red < lowest) lowest = red;
        if (red > highest) highest = red;
      }
      return highest - lowest;
    }

    expect(await stripeContrast(), lessThan(60), reason: 'the glass blurs the stripes behind it');

    final TestGesture finger = await tester.startGesture(tester.getCenter(find.byType(PrismGlass)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(await stripeContrast(), lessThan(60), reason: 'it still blurs them while pressed');
    await finger.up();
  });
}
