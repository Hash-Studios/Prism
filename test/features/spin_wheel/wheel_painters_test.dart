import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:Prism/core/coins/spin_wheel.dart';
import 'package:Prism/features/spin_wheel/domain/bulb_pattern.dart';
import 'package:Prism/features/spin_wheel/views/widgets/spin_plinth.dart';
import 'package:Prism/features/spin_wheel/views/widgets/wheel_bezel.dart';
import 'package:Prism/features/spin_wheel/views/widgets/wheel_face.dart';
import 'package:Prism/features/spin_wheel/views/widgets/wheel_geometry.dart';
import 'package:Prism/features/spin_wheel/views/widgets/wheel_machine.dart';
import 'package:Prism/features/spin_wheel/views/widgets/wheel_palette.dart';
import 'package:Prism/features/spin_wheel/views/widgets/wheel_pointer.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:Prism/theme/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final WheelPalette palette = WheelPalette.of(kDarkTheme.colorScheme);
  const WheelGeometry geometry = WheelGeometry(300);

  test('the bezel painter does not listen to bulb frames, the bulbs painter does', () {
    final ValueNotifier<BulbFrame> frame = ValueNotifier<BulbFrame>(const BulbFrame());
    int bezelRepaints = 0;
    int bulbRepaints = 0;
    final WheelBezelPainter bezel = WheelBezelPainter(geometry: geometry, palette: palette)
      ..addListener(() => bezelRepaints++);
    final WheelBulbsPainter bulbs = WheelBulbsPainter(geometry: geometry, palette: palette, frame: frame)
      ..addListener(() => bulbRepaints++);
    frame.value = const BulbFrame(time: 1);
    expect(bezelRepaints, 0);
    expect(bulbRepaints, 1);
    expect(bezel.shouldRepaint(WheelBezelPainter(geometry: geometry, palette: palette)), isFalse);
    expect(bulbs.shouldRepaint(WheelBulbsPainter(geometry: geometry, palette: palette, frame: frame)), isFalse);
  });

  test('split bezel and bulbs pixels match the original combined painter', () async {
    for (final Brightness brightness in <Brightness>[Brightness.dark, Brightness.light]) {
      final WheelPalette themePalette = WheelPalette.of(
        brightness == Brightness.dark ? kDarkTheme.colorScheme : kLightTheme.colorScheme,
      );
      for (final double diameter in <double>[180, 300, 360]) {
        final WheelGeometry size = WheelGeometry(diameter);
        for (final BulbFrame bulbs in <BulbFrame>[
          const BulbFrame(time: 1.2),
          const BulbFrame(mode: BulbMode.spinning, chase: 5.4),
        ]) {
          final ValueNotifier<BulbFrame> frame = ValueNotifier<BulbFrame>(bulbs);
          final ui.Image legacy = await _paint(
            Size.square(diameter),
            _LegacyWheelBezelPainter(geometry: size, palette: themePalette, frame: frame),
          );
          final ui.Image split = await _paint(
            Size.square(diameter),
            _PainterStack(<CustomPainter>[
              WheelBezelPainter(geometry: size, palette: themePalette),
              WheelBulbsPainter(geometry: size, palette: themePalette, frame: frame),
            ]),
          );
          expect(await _pixels(split), await _pixels(legacy), reason: '$brightness $diameter $bulbs');
          legacy.dispose();
          split.dispose();
          frame.dispose();
        }
      }
    }
  });

  testWidgets('the real plinth fills its slab and matches the original combined paint', (tester) async {
    for (final Brightness brightness in <Brightness>[Brightness.dark, Brightness.light]) {
      final WheelPalette themePalette = WheelPalette.of(
        brightness == Brightness.dark ? kDarkTheme.colorScheme : kLightTheme.colorScheme,
      );
      const WheelGeometry size = WheelGeometry(300);
      final ValueNotifier<BulbFrame> frame = ValueNotifier<BulbFrame>(
        const BulbFrame(mode: BulbMode.spinning, chase: 2.4),
      );
      const double width = 360;
      final double height = size.plinthOverlap + PlinthMetrics.visibleHeight;
      await tester.pumpWidget(
        MaterialApp(
          theme: brightness == Brightness.dark ? kDarkTheme : kLightTheme,
          home: Scaffold(
            body: Center(
              child: RepaintBoundary(
                key: const ValueKey<String>('real'),
                child: SpinPlinth(
                  geometry: size,
                  width: width,
                  palette: themePalette,
                  bulbs: frame,
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final Finder realBoundary = find.byKey(const ValueKey<String>('real'));
      final RenderRepaintBoundary realRender = tester.renderObject<RenderRepaintBoundary>(realBoundary);
      expect(realRender.size, Size(width, height));
      final ui.Image current = (await tester.runAsync(realRender.toImage))!;

      await tester.pumpWidget(
        MaterialApp(
          theme: brightness == Brightness.dark ? kDarkTheme : kLightTheme,
          home: Scaffold(
            body: Center(
              child: RepaintBoundary(
                key: const ValueKey<String>('legacy'),
                child: SizedBox(
                  width: width,
                  height: height,
                  child: CustomPaint(
                    painter: _LegacyPlinthPainter(geometry: size, palette: themePalette, bulbs: frame),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final RenderRepaintBoundary legacyRender = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey<String>('legacy')),
      );
      final ui.Image legacy = (await tester.runAsync(legacyRender.toImage))!;
      final List<Uint8List> pixelData = (await tester.runAsync(
        () async => <Uint8List>[await _pixels(current), await _pixels(legacy)],
      ))!;
      expect(pixelData[0], pixelData[1], reason: '$brightness');
      current.dispose();
      legacy.dispose();
      frame.dispose();
    }
  });

  testWidgets('the real wheel machine matches its legacy combined bezel at dark and light palettes', (tester) async {
    for (final Brightness brightness in <Brightness>[Brightness.dark, Brightness.light]) {
      final ThemeData theme = brightness == Brightness.dark ? kDarkTheme : kLightTheme;
      for (final double diameter in <double>[180, 300, 360]) {
        final WheelGeometry size = WheelGeometry(diameter);
        final ValueNotifier<BulbFrame> bulbs = ValueNotifier<BulbFrame>(
          const BulbFrame(mode: BulbMode.spinning, chase: 6.2),
        );
        final ValueNotifier<double> theta = ValueNotifier<double>(0.3);
        final ValueNotifier<double> flapper = ValueNotifier<double>(0.08);
        Widget host(Widget child, String key) => MaterialApp(
          theme: theme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: RepaintBoundary(key: ValueKey<String>(key), child: child),
            ),
          ),
        );

        await tester.pumpWidget(
          host(
            WheelMachine(
              segments: defaultWheel,
              geometry: size,
              theta: theta,
              flapper: flapper,
              bulbs: bulbs,
              showLabels: false,
            ),
            'current',
          ),
        );
        await tester.pump();
        final RenderRepaintBoundary actualRender = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey<String>('current')),
        );
        final ui.Image actual = (await tester.runAsync(actualRender.toImage))!;
        await tester.pumpWidget(
          host(
            _LegacyWheelMachine(segments: defaultWheel, geometry: size, theta: theta, flapper: flapper, bulbs: bulbs),
            'legacyMachine',
          ),
        );
        await tester.pump();
        final RenderRepaintBoundary legacyRender = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey<String>('legacyMachine')),
        );
        final ui.Image legacy = (await tester.runAsync(legacyRender.toImage))!;
        final List<Uint8List> both = (await tester.runAsync(
          () async => <Uint8List>[await _pixels(actual), await _pixels(legacy)],
        ))!;
        expect(both[0], both[1], reason: '$brightness $diameter');
        actual.dispose();
        legacy.dispose();
        bulbs.dispose();
        theta.dispose();
        flapper.dispose();
      }
    }
  });
}

Future<ui.Image> _paint(Size size, CustomPainter painter) {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), size);
  return recorder.endRecording().toImage(size.width.ceil(), size.height.ceil());
}

Future<Uint8List> _pixels(ui.Image image) async => (await image.toByteData())!.buffer.asUint8List();

class _PainterStack extends CustomPainter {
  _PainterStack(this.painters);

  final List<CustomPainter> painters;

  @override
  void paint(Canvas canvas, Size size) {
    for (final CustomPainter painter in painters) {
      painter.paint(canvas, size);
    }
  }

  @override
  bool shouldRepaint(_PainterStack oldDelegate) => true;
}

class _LegacyWheelMachine extends StatelessWidget {
  const _LegacyWheelMachine({
    required this.segments,
    required this.geometry,
    required this.theta,
    required this.flapper,
    required this.bulbs,
  });

  final List<WheelSegment> segments;
  final WheelGeometry geometry;
  final ValueListenable<double> theta;
  final ValueListenable<double> flapper;
  final ValueListenable<BulbFrame> bulbs;

  @override
  Widget build(BuildContext context) {
    final WheelPalette palette = WheelPalette.of(Theme.of(context).colorScheme);
    final Size size = Size.square(geometry.diameter);
    return Semantics(
      label: context.l10n.economyPrizeWheel,
      excludeSemantics: true,
      child: SizedBox.fromSize(
        size: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            RepaintBoundary(
              child: CustomPaint(
                size: size,
                painter: _LegacyWheelBezelPainter(geometry: geometry, palette: palette, frame: bulbs),
              ),
            ),
            ValueListenableBuilder<double>(
              valueListenable: theta,
              child: RepaintBoundary(
                child: WheelFace(segments: segments, palette: palette, geometry: geometry, showLabels: false),
              ),
              builder: (BuildContext context, double angle, Widget? face) =>
                  Transform.rotate(angle: angle, child: face),
            ),
            Center(
              child: WheelHub(geometry: geometry, palette: palette),
            ),
            CustomPaint(
              size: size,
              painter: WheelPointerPainter(geometry: geometry, palette: palette, angle: flapper),
            ),
          ],
        ),
      ),
    );
  }
}

// Frozen copies from HEAD@2598874830e50f6d4a14d45c469c8e2cf815430a provide an independent pixel oracle for the painter split.
class _LegacyPlinthPainter extends CustomPainter {
  _LegacyPlinthPainter({required this.geometry, required this.palette, required this.bulbs}) : super(repaint: bulbs);

  final WheelGeometry geometry;
  final WheelPalette palette;
  final ValueListenable<BulbFrame> bulbs;

  @override
  void paint(Canvas canvas, Size size) {
    final ColorScheme cs = palette.colorScheme;
    final RRect slab = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(PrismRadius.xl));
    canvas.drawRRect(
      slab.shift(const Offset(0, 10)),
      Paint()
        ..color = cs.scrim.withValues(alpha: palette.dark ? 0.55 : 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );
    canvas.drawRRect(
      slab,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[palette.plinthTop, palette.plinthBottom],
        ).createShader(Offset.zero & size),
    );

    canvas.save();
    canvas.clipRRect(slab);
    final Offset wheelCentre = Offset(size.width / 2, geometry.plinthOverlap - geometry.radius);
    final double well = geometry.radius + geometry.diameter * 0.022;
    canvas.drawCircle(
      wheelCentre,
      well,
      Paint()
        ..color = palette.ink.withValues(alpha: 0.4)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, geometry.diameter * 0.012),
    );
    canvas.drawCircle(
      wheelCentre,
      well,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Colors.transparent, palette.shine.withValues(alpha: 0.4)],
        ).createShader(Rect.fromCircle(center: wheelCentre, radius: well)),
    );
    canvas.restore();

    canvas.drawRRect(
      slab.deflate(1),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            palette.shine.withValues(alpha: 0.55),
            palette.shine.withValues(alpha: 0.08),
            palette.ink.withValues(alpha: 0.25),
          ],
          stops: const <double>[0, 0.5, 1],
        ).createShader(Offset.zero & size),
    );

    final Rect panel = Rect.fromLTRB(
      PlinthMetrics.panelInset,
      geometry.plinthOverlap + PlinthMetrics.panelGap,
      size.width - PlinthMetrics.panelInset,
      size.height - PlinthMetrics.panelGap - 4,
    );
    final RRect panelShape = RRect.fromRectAndRadius(panel, const Radius.circular(PrismRadius.lg));
    canvas.drawRRect(panelShape, Paint()..color = palette.plinthPanel);
    canvas.drawRRect(
      panelShape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[palette.ink.withValues(alpha: 0.3), palette.shine.withValues(alpha: 0.26)],
        ).createShader(panel),
    );

    final BulbFrame frame = bulbs.value;
    final double midY = panel.center.dy;
    for (int k = 0; k < 3; k++) {
      final double y = midY + (k - 1) * PlinthMetrics.lightSpacing;
      final double lit = frame.intensity(k, period: 3);
      paintBulb(canvas, Offset(PlinthMetrics.lightInset, y), PlinthMetrics.lightRadius, lit, palette.gold);
      paintBulb(canvas, Offset(size.width - PlinthMetrics.lightInset, y), PlinthMetrics.lightRadius, lit, palette.gold);
    }
  }

  @override
  bool shouldRepaint(_LegacyPlinthPainter oldDelegate) =>
      oldDelegate.geometry != geometry ||
      oldDelegate.palette.colorScheme != palette.colorScheme ||
      oldDelegate.bulbs != bulbs;
}

class _LegacyWheelBezelPainter extends CustomPainter {
  _LegacyWheelBezelPainter({required this.geometry, required this.palette, required this.frame})
    : super(repaint: frame);

  final WheelGeometry geometry;
  final WheelPalette palette;
  final ValueListenable<BulbFrame> frame;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = size.center(Offset.zero);
    final double outer = geometry.radius;
    final double inner = outer - geometry.bezelWidth;
    final WheelGold gold = palette.gold;
    final Rect bounds = Rect.fromCircle(center: c, radius: outer);

    canvas.drawCircle(
      c.translate(0, geometry.diameter * 0.035),
      outer * 0.98,
      Paint()
        ..color = palette.colorScheme.scrim.withValues(alpha: palette.dark ? 0.55 : 0.3)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, geometry.diameter * 0.04),
    );

    final Path ring = Path()
      ..fillType = PathFillType.evenOdd
      ..addOval(bounds)
      ..addOval(Rect.fromCircle(center: c, radius: inner));
    canvas.drawPath(
      ring,
      Paint()
        ..shader = SweepGradient(
          colors: gold.metal,
          transform: const GradientRotation(-math.pi * 0.62),
        ).createShader(bounds),
    );
    canvas.drawCircle(
      c,
      outer - 0.6,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = gold.dark.withValues(alpha: 0.7),
    );
    canvas.drawCircle(
      c,
      outer - geometry.diameter * 0.011,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = geometry.diameter * 0.006
        ..shader = SweepGradient(
          colors: <Color>[
            gold.highlight.withValues(alpha: 0.2),
            gold.glint.withValues(alpha: 0.75),
            gold.highlight.withValues(alpha: 0.2),
            gold.highlight.withValues(alpha: 0.05),
            gold.highlight.withValues(alpha: 0.2),
          ],
          stops: const <double>[0, 0.12, 0.3, 0.7, 1],
          transform: const GradientRotation(-math.pi * 0.9),
        ).createShader(bounds),
    );
    canvas.drawCircle(
      c,
      inner + 0.8,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = gold.dark.withValues(alpha: 0.85),
    );

    final double ringOuter = inner;
    final Rect ringBounds = Rect.fromCircle(center: c, radius: ringOuter);
    canvas.drawCircle(
      c,
      ringOuter,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color.lerp(palette.ink, palette.shine, 0.12)!, palette.ink],
        ).createShader(ringBounds),
    );

    final BulbFrame bulbs = frame.value;
    const double step = 2 * math.pi / wheelBulbCount;
    for (int k = 0; k < wheelBulbCount; k++) {
      final double a = -math.pi / 2 + (k + 0.5) * step;
      final Offset p = c + Offset(math.cos(a), math.sin(a)) * geometry.bulbOrbit;
      paintBulb(canvas, p, geometry.bulbRadius, bulbs.intensity(k), gold);
    }
  }

  @override
  bool shouldRepaint(_LegacyWheelBezelPainter oldDelegate) =>
      oldDelegate.geometry != geometry ||
      oldDelegate.palette.colorScheme != palette.colorScheme ||
      oldDelegate.frame != frame;
}
