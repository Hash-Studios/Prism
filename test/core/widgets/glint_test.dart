import 'dart:typed_data' as typed_data;
import 'dart:ui' as ui;

import 'package:Prism/core/widgets/glint/glint.dart';
import 'package:Prism/core/widgets/glint/glint_data.dart';
import 'package:Prism/features/debug_panel/views/pages/mascot_gallery_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child, {bool reduceMotion = false, bool tickerEnabled = true}) => MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: TickerMode(
        enabled: tickerEnabled,
        child: Center(child: child),
      ),
    ),
  );

  Future<List<int>> raster(WidgetTester tester, GlintMood mood, {double seconds = 0, bool still = false}) async {
    await tester.pumpWidget(host(GlintPose(mood: mood, seconds: seconds, size: 160, still: still)));
    final CustomPainter painter = tester.renderObject<RenderCustomPaint>(find.byType(CustomPaint).first).painter!;
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder);
    final int saveCount = canvas.getSaveCount();
    painter.paint(canvas, const Size(160, 160));
    expect(canvas.getSaveCount(), saveCount, reason: '$mood at $seconds (still: $still)');
    final ui.Picture picture = recorder.endRecording();
    final ui.Image image = (await tester.runAsync<ui.Image>(() => picture.toImage(160, 160)))!;
    final typed_data.ByteData data = (await tester.runAsync<typed_data.ByteData?>(
      () => image.toByteData(format: ui.ImageByteFormat.rawStraightRgba),
    ))!;
    final List<int> pixels = List<int>.generate(data.lengthInBytes, data.getUint8);
    image.dispose();
    picture.dispose();
    return pixels;
  }

  Future<int> pixelAt(WidgetTester tester, GlintMood mood, Offset point) async {
    final List<int> pixels = await raster(tester, mood);
    final int offset = (point.dy.floor() * 160 + point.dx.floor()) * 4;
    expect(pixels[offset + 3], greaterThan(0), reason: 'expected ring paint at $point');
    return 0xFF000000 | (pixels[offset] << 16) | (pixels[offset + 1] << 8) | pixels[offset + 2];
  }

  Future<_GlintPaintTrace> trace(WidgetTester tester, GlintMood mood, double fraction) async {
    await tester.pumpWidget(host(GlintPose(mood: mood, seconds: fraction * glintSpecOf(mood).period, size: 160)));
    final CustomPainter painter = tester.renderObject<RenderCustomPaint>(find.byType(CustomPaint).first).painter!;
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final _RecordingCanvas canvas = _RecordingCanvas(recorder);
    final int saveCount = canvas.getSaveCount();
    painter.paint(canvas, const Size(160, 160));
    expect(canvas.getSaveCount(), saveCount, reason: '$mood at $fraction');
    recorder.endRecording().dispose();
    return _GlintPaintTrace(canvas);
  }

  Future<Offset?> firstOutsidePixel(WidgetTester tester, GlintMood mood, double fraction) async {
    await tester.pumpWidget(host(GlintPose(mood: mood, seconds: fraction * glintSpecOf(mood).period, size: 160)));
    final CustomPainter painter = tester.renderObject<RenderCustomPaint>(find.byType(CustomPaint).first).painter!;
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder)..translate(64, 64);
    final int saveCount = canvas.getSaveCount();
    painter.paint(canvas, const Size(160, 160));
    expect(canvas.getSaveCount(), saveCount, reason: '$mood at $fraction');
    final ui.Picture picture = recorder.endRecording();
    final ui.Image image = (await tester.runAsync<ui.Image>(() => picture.toImage(288, 288)))!;
    final typed_data.ByteData data = (await tester.runAsync<typed_data.ByteData?>(() => image.toByteData()))!;
    for (int y = 0; y < 288; y++) {
      for (int x = 0; x < 288; x++) {
        if ((x < 64 || x >= 224 || y < 64 || y >= 224) && data.getUint8((y * 288 + x) * 4 + 3) != 0) {
          image.dispose();
          picture.dispose();
          return Offset(x - 64, y - 64);
        }
      }
    }
    image.dispose();
    picture.dispose();
    return null;
  }

  testWidgets('every mood paints at the start, at its still pose and part way through', (WidgetTester tester) async {
    for (final GlintMood mood in GlintMood.values) {
      final GlintMoodSpec spec = glintSpecOf(mood);
      for (final double seconds in <double>[0, spec.stillAt, .37 * spec.period]) {
        await tester.pumpWidget(host(GlintPose(mood: mood, seconds: seconds)));
      }
      await tester.pumpWidget(host(GlintPose(mood: mood, seconds: 0, still: true)));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('Glint loops while shown', (WidgetTester tester) async {
    await tester.pumpWidget(host(const Glint(mood: GlintMood.happy)));
    // Bounded pumps: Glint never settles.
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.binding.hasScheduledFrame, isTrue);
  });

  testWidgets('Glint stops scheduling frames after disposal', (WidgetTester tester) async {
    await tester.pumpWidget(host(const Glint(mood: GlintMood.happy)));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(host(const SizedBox.shrink()));
    await tester.pump(const Duration(seconds: 2));

    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('under reduce-motion Glint holds a still pose and schedules no frame', (WidgetTester tester) async {
    await tester.pumpWidget(host(const Glint(mood: GlintMood.sleepy), reduceMotion: true));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.binding.hasScheduledFrame, isFalse);
    final GlintPose pose = tester.widget(find.byType(GlintPose));
    expect(pose.still, isTrue);
    expect(pose.mood, GlintMood.sleepy);
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('Glint follows reduce-motion changes while mounted', (WidgetTester tester) async {
    await tester.pumpWidget(host(const Glint(mood: GlintMood.happy)));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.widget<GlintPose>(find.byType(GlintPose)).seconds, greaterThan(0));

    await tester.pumpWidget(host(const Glint(mood: GlintMood.happy), reduceMotion: true));
    final GlintPose reduced = tester.widget(find.byType(GlintPose));
    expect(reduced.still, isTrue);
    expect(reduced.seconds, greaterThan(0));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.binding.hasScheduledFrame, isFalse);

    await tester.pumpWidget(host(const Glint(mood: GlintMood.happy)));
    final GlintPose resumed = tester.widget(find.byType(GlintPose));
    expect(resumed.still, isFalse);
    expect(resumed.seconds, 0);
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.widget<GlintPose>(find.byType(GlintPose)).seconds, greaterThan(0));
  });

  testWidgets('gallery preserves inherited reduce-motion preference', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(body: MascotGalleryPage()),
        ),
      ),
    );

    expect(tester.widget<GlintPose>(find.byType(GlintPose).first).still, isTrue);
  });

  testWidgets('gallery fits narrow viewports with enlarged text', (WidgetTester tester) async {
    final List<String> overflows = <String>[];
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final (double, double) viewport in const <(double, double)>[(320, 1), (320, 3), (280, 1)]) {
      final (double width, double textScale) = viewport;
      tester.view.physicalSize = Size(width, 1200);
      tester.view.devicePixelRatio = 1;

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
            child: const Scaffold(body: MascotGalleryPage()),
          ),
        ),
      );

      final Object? exception = tester.takeException();
      if (exception != null) {
        overflows.add('$width px at text scale $textScale: $exception');
      }

      if (exception == null && textScale == 3) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -10000));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text(GlintMood.values.last.name), findsOneWidget);
        final Object? scrollException = tester.takeException();
        if (scrollException != null) {
          overflows.add('$width px at text scale $textScale while scrolling: $scrollException');
        }
      }
    }

    expect(overflows, isEmpty);
  });

  testWidgets('gallery stops scheduling frames while its tab is hidden', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DefaultTabController(
          length: 2,
          initialIndex: 1,
          child: Scaffold(
            appBar: TabBar(
              tabs: <Widget>[
                Tab(text: 'Other'),
                Tab(text: 'Mascot'),
              ],
            ),
            body: TabBarView(children: <Widget>[Text('Other tab'), MascotGalleryPage()]),
          ),
        ),
      ),
    );
    expect(find.byType(GlintPose), findsWidgets);
    await tester.tap(find.text('Other'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('a new mood starts its loop from the top', (WidgetTester tester) async {
    double seconds() => tester.widget<GlintPose>(find.byType(GlintPose)).seconds;

    await tester.pumpWidget(host(const Glint(mood: GlintMood.happy)));
    for (int i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(seconds(), greaterThan(1));

    await tester.pumpWidget(host(const Glint(mood: GlintMood.sad)));
    expect(seconds(), lessThan(.1));
  });

  testWidgets('a mood changed while muted starts at zero when its TickerMode resumes', (WidgetTester tester) async {
    double seconds() => tester.widget<GlintPose>(find.byType(GlintPose)).seconds;

    await tester.pumpWidget(host(const Glint(mood: GlintMood.happy)));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpWidget(host(const Glint(mood: GlintMood.happy), tickerEnabled: false));
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpWidget(host(const Glint(mood: GlintMood.sad), tickerEnabled: false));
    await tester.pumpWidget(host(const Glint(mood: GlintMood.sad)));
    await tester.pump();

    expect(seconds(), lessThan(.1));
  });

  testWidgets('Glint is a picture: screen readers skip it', (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      host(
        Semantics(
          container: true,
          label: 'box',
          child: const Glint(mood: GlintMood.love),
        ),
        reduceMotion: true,
      ),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('box')),
      matchesSemantics(label: 'box', children: const <Matcher>[]),
    );
    semantics.dispose();
  });

  test('the keys of every mood start at 0, end at 1 and never go back', () {
    for (final GlintMood mood in GlintMood.values) {
      final GlintMoodSpec spec = glintSpecOf(mood);
      expect(spec.stillAt, lessThan(spec.period), reason: mood.name);
      for (final MapEntry<String, List<GlintKey>> part in spec.parts.entries) {
        final List<double> times = [for (final GlintKey k in part.value) k.t];
        expect(times.first, 0, reason: '${mood.name} ${part.key}');
        expect(times.last, 1, reason: '${mood.name} ${part.key}');
        for (int i = 1; i < times.length; i++) {
          expect(times[i], greaterThanOrEqualTo(times[i - 1]), reason: '${mood.name} ${part.key}');
        }
      }
    }
  });

  testWidgets('no mood paints outside the 160 box, including effects between overshooting keys', (
    WidgetTester tester,
  ) async {
    for (final GlintMood mood in GlintMood.values) {
      final GlintMoodSpec spec = glintSpecOf(mood);
      final Set<double> samples = <double>{0};
      for (final List<GlintKey> keys in spec.parts.values) {
        for (int i = 0; i < keys.length; i++) {
          samples.add(keys[i].t);
          if (i + 1 < keys.length) {
            for (final double u in <double>[.25, .5, .75]) {
              samples.add(keys[i].t + (keys[i + 1].t - keys[i].t) * u);
            }
            if (keys[i].ease == GlintEase.pop) {
              // The CSS pop curve reaches its scale overshoot here, not at a quarter-frame sample.
              const double popPeakU = .5727947919125691;
              samples.add(keys[i].t + (keys[i + 1].t - keys[i].t) * popPeakU);
            }
          }
        }
      }
      for (final double fraction in samples) {
        expect(await firstOutsidePixel(tester, mood, fraction), isNull, reason: '${mood.name} at $fraction');
      }
    }
  });

  testWidgets('each reduced-motion pose rasterizes exactly at its approved stillAt time', (WidgetTester tester) async {
    const List<double> approvedStillAt = <double>[1.8, 1.05, 1.72, .72, .59, .67, 1.1, .27, 1.9, 2];
    for (int i = 0; i < GlintMood.values.length; i++) {
      final GlintMood mood = GlintMood.values[i];
      final GlintMoodSpec spec = glintSpecOf(mood);
      expect(spec.stillAt, approvedStillAt[i], reason: mood.name);
      final List<int> atStillAt = await raster(tester, mood, seconds: spec.stillAt);
      final List<int> reducedMotion = await raster(tester, mood, seconds: 999, still: true);
      expect(reducedMotion, atStillAt, reason: mood.name);
    }
  });

  testWidgets('native painter transform matches CSS ease-in-out and its declared origin', (WidgetTester tester) async {
    // At loop fraction .125, CSS ease-in-out has progressed .1292 through the [0, .5] segment.
    // The expected point is independently evaluated from the SVG's translate/rotate/scale transform order.
    final Offset top = (await trace(tester, GlintMood.love, .125)).point(const Offset(80, 46));
    expect(top.dx, closeTo(77.733, .03));
    expect(top.dy, closeTo(46.033, .03));
  });

  testWidgets('native painter transform matches CSS ease-out, ease-in and pop overshoot', (WidgetTester tester) async {
    expect(
      (await trace(tester, GlintMood.happy, .24)).point(const Offset(80, 46)).dy,
      closeTo(36.077231770839234, .03),
    );
    expect((await trace(tester, GlintMood.happy, .48)).point(const Offset(80, 46)).dy, closeTo(36.53008415369338, .03));
    expect(
      (await trace(tester, GlintMood.happy, .68)).point(const Offset(80, 46)).dy,
      closeTo(43.559941100527595, .03),
    );
  });

  testWidgets('repeated frames reuse paths and paints for every mood and effect', (WidgetTester tester) async {
    for (final GlintMood mood in GlintMood.values) {
      for (final double fraction in <double>[.37, .68]) {
        final _GlintPaintTrace first = await trace(tester, mood, fraction);
        final _GlintPaintTrace next = await trace(tester, mood, fraction);
        expect(next.paths.length, first.paths.length, reason: '$mood at $fraction');
        expect(next.paints.length, first.paints.length, reason: '$mood at $fraction');
        for (int i = 0; i < first.paths.length; i++) {
          expect(identical(next.paths[i], first.paths[i]), isTrue, reason: '$mood path $i at $fraction');
        }
        for (int i = 0; i < first.paints.length; i++) {
          expect(identical(next.paints[i], first.paints[i]), isTrue, reason: '$mood paint $i at $fraction');
        }
        expect(next.layerPaints.length, first.layerPaints.length, reason: '$mood at $fraction');
        for (int i = 0; i < first.layerPaints.length; i++) {
          expect(identical(next.layerPaints[i], first.layerPaints[i]), isTrue, reason: '$mood layer paint $i');
        }
      }
    }
  });

  testWidgets('the sheen uses its linear keyframe displacement from origin zero', (WidgetTester tester) async {
    final _GlintPaintTrace sheen = await trace(tester, GlintMood.calm, .64);
    final typed_data.Float64List transform = sheen.sheenTransform!;
    final typed_data.Float64List body = sheen.crystalTransform!;
    expect((transform[12] - body[12]) / body[0], closeTo(-8.5, .001));
    expect(transform[13] - body[13], closeTo(0, .001));
  });

  testWidgets('ring junction colours follow the SVG segment gradients and love palette', (WidgetTester tester) async {
    // Independently computed SVG gradient colours at the pixel centres nearest the two joins.
    final int coolUpperJoin = await pixelAt(tester, GlintMood.calm, const Offset(93, 33));
    final int coolRightJoin = await pixelAt(tester, GlintMood.calm, const Offset(133, 95));
    final int warmUpperJoin = await pixelAt(tester, GlintMood.love, const Offset(93, 33));
    final int coolArc = await pixelAt(tester, GlintMood.calm, const Offset(92, 38));
    final int warmArc = await pixelAt(tester, GlintMood.love, const Offset(92, 38));
    expect(coolUpperJoin, _nearColor(0xFFAF72F1), reason: 'purple to lavender SVG segment');
    expect(coolRightJoin, _nearColor(0xFF5FD7EF), reason: 'lavender to cyan SVG segment');
    expect(warmUpperJoin, _nearColor(0xFFDA61DB), reason: 'love uses its warm purple/pink segment');
    expect(coolArc, _nearColor(0xFFAE76F2, tolerance: 2), reason: 'SVG linear gradient along the top arc');
    expect(warmArc, _nearColor(0xFFDB62D9, tolerance: 2), reason: 'love gradient along the top arc');
  });
}

Matcher _nearColor(int expected, {int tolerance = 1}) => predicate<int>((int actual) {
  for (final int shift in <int>[16, 8, 0]) {
    if (((actual >> shift) & 0xFF) - ((expected >> shift) & 0xFF) > tolerance ||
        ((expected >> shift) & 0xFF) - ((actual >> shift) & 0xFF) > tolerance) {
      return false;
    }
  }
  return true;
}, 'near $expected');

class _GlintPaintTrace {
  _GlintPaintTrace(this.canvas);

  final _RecordingCanvas canvas;

  List<ui.Path> get paths => canvas.paths;
  List<ui.Paint> get paints => canvas.drawPaints;
  List<ui.Paint> get layerPaints => canvas.layerPaints;
  typed_data.Float64List? get crystalTransform => canvas.crystalTransform;
  typed_data.Float64List? get sheenTransform => canvas.sheenTransform;

  Offset point(Offset point) {
    final typed_data.Float64List transform = canvas.crystalTransform!;
    return Offset(
      transform[0] * point.dx + transform[4] * point.dy + transform[12],
      transform[1] * point.dx + transform[5] * point.dy + transform[13],
    );
  }
}

class _RecordingCanvas implements ui.Canvas {
  _RecordingCanvas(ui.PictureRecorder recorder) : _delegate = ui.Canvas(recorder);

  final ui.Canvas _delegate;

  final List<ui.Path> paths = <ui.Path>[];
  final List<ui.Paint> drawPaints = <ui.Paint>[];
  final List<ui.Paint> layerPaints = <ui.Paint>[];
  typed_data.Float64List? crystalTransform;
  typed_data.Float64List? sheenTransform;

  @override
  int getSaveCount() => _delegate.getSaveCount();

  @override
  typed_data.Float64List getTransform() => _delegate.getTransform();

  @override
  void save() => _delegate.save();

  @override
  void restore() => _delegate.restore();

  @override
  void translate(double dx, double dy) => _delegate.translate(dx, dy);

  @override
  void rotate(double radians) => _delegate.rotate(radians);

  @override
  void scale(double sx, [double? sy]) => _delegate.scale(sx, sy);

  @override
  void clipPath(ui.Path path, {bool doAntiAlias = true}) {
    if (doAntiAlias) {
      _delegate.clipPath(path);
    } else {
      _delegate.clipPath(path, doAntiAlias: false);
    }
  }

  @override
  void drawRect(ui.Rect rect, ui.Paint paint) {
    drawPaints.add(paint);
    _delegate.drawRect(rect, paint);
  }

  @override
  void drawLine(ui.Offset p1, ui.Offset p2, ui.Paint paint) {
    drawPaints.add(paint);
    _delegate.drawLine(p1, p2, paint);
  }

  @override
  void drawOval(ui.Rect rect, ui.Paint paint) {
    drawPaints.add(paint);
    _delegate.drawOval(rect, paint);
  }

  @override
  void drawCircle(ui.Offset c, double radius, ui.Paint paint) {
    drawPaints.add(paint);
    _delegate.drawCircle(c, radius, paint);
  }

  @override
  void drawPath(ui.Path path, ui.Paint paint) {
    paths.add(path);
    drawPaints.add(paint);
    if (identical(path, glintCrystalPath) && crystalTransform == null) {
      crystalTransform = _delegate.getTransform();
    }
    if (path.getBounds() == const ui.Rect.fromLTRB(52, 40, 82, 125) && sheenTransform == null) {
      sheenTransform = _delegate.getTransform();
    }
    _delegate.drawPath(path, paint);
  }

  @override
  void saveLayer(ui.Rect? bounds, ui.Paint paint) {
    layerPaints.add(paint);
    _delegate.saveLayer(bounds, paint);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
