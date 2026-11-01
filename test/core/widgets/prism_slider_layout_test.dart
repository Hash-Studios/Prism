import 'dart:ui' as ui;

import 'package:Prism/core/widgets/prism/prism_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('matches Material Slider size under tight and loose constraints', (tester) async {
    final List<Size> prismSizes = <Size>[];
    final List<Size> materialSizes = <Size>[];

    Future<void> measure(Widget child, List<Size> sizes) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: Align(alignment: Alignment.topLeft, child: child),
          ),
        ),
      );
      sizes.add(tester.getSize(find.byType(Slider)));
    }

    await measure(const SizedBox(width: 240, height: 32, child: PrismSlider(value: 0.4, onChanged: null)), prismSizes);
    await measure(const SizedBox(width: 240, height: 32, child: Slider(value: 0.4, onChanged: null)), materialSizes);

    await measure(const PrismSlider(value: 0.4, onChanged: null), prismSizes);
    await measure(const Slider(value: 0.4, onChanged: null), materialSizes);

    Future<void> measureUnbounded(Widget child, List<Size> sizes) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: Align(
              alignment: Alignment.topLeft,
              child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[child]),
            ),
          ),
        ),
      );
      sizes.add(tester.getSize(find.byType(Slider)));
    }

    await measureUnbounded(const PrismSlider(value: 0.4, onChanged: null), prismSizes);
    await measureUnbounded(const Slider(value: 0.4, onChanged: null), materialSizes);

    expect(prismSizes, materialSizes);
  });

  testWidgets('preserves migrated row and 32px callsite layouts', (tester) async {
    Future<Rect> measure(Widget child, Widget Function(Widget) callsite) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(width: 360, height: 80, child: callsite(child)),
            ),
          ),
        ),
      );
      return tester.getRect(find.byType(Slider));
    }

    Widget rowCallsite(Widget slider) => Row(
      children: <Widget>[
        const SizedBox(width: 84, child: Text('Dim')),
        Expanded(child: slider),
        const SizedBox(width: 44, child: Text('50%')),
      ],
    );

    Widget adjustmentCallsite(Widget slider) => Column(
      children: <Widget>[
        const SizedBox(height: 24, child: Text('Adjustment')),
        SizedBox(height: 32, child: slider),
      ],
    );

    Widget stretchedColumnCallsite(Widget slider) =>
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[slider]);

    Widget cardCallsite(Widget slider) =>
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[slider, const SizedBox(height: 24)]);

    final Rect prismRow = await measure(const PrismSlider(value: 0.5, onChanged: null), rowCallsite);
    final Rect materialRow = await measure(const Slider(value: 0.5, onChanged: null), rowCallsite);
    expect(prismRow, materialRow);

    final Rect prismAdjustment = await measure(const PrismSlider(value: 0.5, onChanged: null), adjustmentCallsite);
    final Rect materialAdjustment = await measure(const Slider(value: 0.5, onChanged: null), adjustmentCallsite);
    expect(prismAdjustment, materialAdjustment);

    final Rect prismStretched = await measure(const PrismSlider(value: 0.5, onChanged: null), stretchedColumnCallsite);
    final Rect materialStretched = await measure(const Slider(value: 0.5, onChanged: null), stretchedColumnCallsite);
    expect(prismStretched, materialStretched);

    final Rect prismCard = await measure(const PrismSlider(value: 0.5, onChanged: null), cardCallsite);
    final Rect materialCard = await measure(const Slider(value: 0.5, onChanged: null), cardCallsite);
    expect(prismCard, materialCard);
  });

  testWidgets('divided value indicator stays in the local overlay while the thumb is dragged', (tester) async {
    tester.view.physicalSize = const Size(400, 300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    double value = 0.25;
    final List<Rect> indicatorBounds = <Rect>[];
    const Key paintBoundaryKey = ValueKey<String>('slider-paint-boundary');

    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: Center(
            child: RepaintBoundary(
              key: paintBoundaryKey,
              child: ColoredBox(
                color: Colors.white,
                child: SizedBox(
                  width: 360,
                  height: 120,
                  child: Center(
                    child: SizedBox(
                      width: 300,
                      height: 32,
                      child: SliderTheme(
                        data: SliderThemeData(
                          showValueIndicator: ShowValueIndicator.onDrag,
                          valueIndicatorShape: _RecordingValueIndicatorShape(indicatorBounds),
                        ),
                        child: StatefulBuilder(
                          builder: (context, setState) => PrismSlider(
                            value: value,
                            divisions: 4,
                            label: '25%',
                            onChanged: (next) => setState(() => value = next),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final Finder slider = find.byType(Slider);
    final Rect sliderBounds = tester.getRect(slider);
    final Finder localOverlay = find.ancestor(of: slider, matching: find.byType(Overlay)).first;
    final Offset thumbCenter = Offset(sliderBounds.left + sliderBounds.width * 0.25, sliderBounds.center.dy);
    final TestGesture gesture = await tester.startGesture(thumbCenter);
    await tester.pump();
    await gesture.moveBy(const Offset(60, 0));
    await tester.pump();

    expect(value, greaterThan(0.25));
    expect(tester.getRect(localOverlay).contains(sliderBounds.center), isTrue);
    expect(indicatorBounds, isNotEmpty);
    expect(indicatorBounds.last.bottom, lessThan(sliderBounds.center.dy));
    expect(indicatorBounds.last.top, lessThan(sliderBounds.top));
    final Rect boundaryRect = tester.getRect(find.byKey(paintBoundaryKey));
    final Rect indicatorRect = indicatorBounds.last.shift(-boundaryRect.topLeft);
    final ui.Image image = await tester.renderObject<RenderRepaintBoundary>(find.byKey(paintBoundaryKey)).toImage();
    addTearDown(image.dispose);
    final ByteData pixels =
        await tester.runAsync(() async => (await image.toByteData())!) ??
        (throw StateError('Unable to read rendered slider pixels'));
    final int sampleX = indicatorRect.left.round() + 4;
    final int sampleY = indicatorRect.center.dy.round();
    final int pixelOffset = (sampleY * image.width + sampleX) * 4;
    expect(pixels.getUint8(pixelOffset), lessThan(240));

    await gesture.up();
    await tester.pump();
  });

  for (final TargetPlatform platform in <TargetPlatform>[TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('keeps slider and sibling semantics on $platform', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: Material(
            child: Row(
              children: <Widget>[
                Semantics(label: 'Before slider', child: const SizedBox(width: 1, height: 1)),
                const Expanded(
                  child: PrismSlider(
                    value: 0.5,
                    label: 'Volume',
                    semanticFormatterCallback: _formatPercent,
                    onChanged: _ignoreValue,
                  ),
                ),
                Semantics(label: 'After slider', child: const SizedBox(width: 1, height: 1)),
              ],
            ),
          ),
        ),
      );

      final SemanticsNode slider = tester.getSemantics(find.byType(PrismSlider));
      expect(slider.getSemanticsData().flagsCollection.isSlider, isTrue);
      expect(slider.label, 'Volume');
      expect(slider.value, '50%');
      expect(find.bySemanticsLabel('Before slider'), findsOneWidget);
      expect(find.bySemanticsLabel('After slider'), findsOneWidget);
      handle.dispose();
    });
  }

  testWidgets('keyboard arrows adjust the focused slider by one division', (tester) async {
    Future<double> nudge(Widget Function(double, ValueChanged<double>) buildSlider) async {
      double value = 0.5;
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: Center(
              child: StatefulBuilder(
                builder: (context, setState) => buildSlider(value, (next) => setState(() => value = next)),
              ),
            ),
          ),
        ),
      );

      final FocusNode focusNode = tester
          .widget<FocusableActionDetector>(
            find.descendant(of: find.byType(Slider), matching: find.byType(FocusableActionDetector)),
          )
          .focusNode!;
      focusNode.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      return value;
    }

    final double prismValue = await nudge(
      (value, onChanged) => PrismSlider(value: value, divisions: 4, onChanged: onChanged),
    );
    final double materialValue = await nudge(
      (value, onChanged) => Slider(value: value, divisions: 4, onChanged: onChanged),
    );

    expect(prismValue, closeTo(0.75, 0.001));
    expect(prismValue, materialValue);
  });
}

String _formatPercent(double value) => '${(value * 100).round()}%';

void _ignoreValue(double value) {}

class _RecordingValueIndicatorShape extends SliderComponentShape {
  _RecordingValueIndicatorShape(this.globalPaintBounds);

  final List<Rect> globalPaintBounds;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(80, 32);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final Rect bounds = Rect.fromCenter(center: center - const Offset(0, 24), width: 80, height: 32);
    globalPaintBounds.add(parentBox.localToGlobal(bounds.topLeft) & bounds.size);
    final Canvas canvas = context.canvas;
    canvas.drawRRect(
      RRect.fromRectAndRadius(bounds, const Radius.circular(8)),
      Paint()..color = sliderTheme.valueIndicatorColor ?? Colors.black,
    );
    labelPainter.paint(canvas, bounds.center - Offset(labelPainter.width / 2, labelPainter.height / 2));
  }
}
