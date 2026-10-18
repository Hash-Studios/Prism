@Tags(<String>['qa_render'])
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';

import 'qa_harness.dart';

const Color _background = Color(0xFF0E0E12);
const String _asset = 'assets/lottie/daily_chest.json';
const String _outDir = 'build/qa_render/daily_chest';

const Map<String, double> _poses = <String, double>{
  '01_idle_start': 0,
  '02_charge_mid': 150,
  '03_open_186': 186,
  '04_open_194': 194,
  '05_open_202': 202,
  '06_open_214': 214,
  '07_open_236': 236,
  '08_open_266': 266,
  '09_opened_mid': 330,
  '10_spent': 392,
};

const double _openedFrame = 330;

List<ValueDelegate> _glow(Color color) => <ValueDelegate>[
  ValueDelegate.color(const <String>['**', 'glow'], value: color),
];

List<ValueDelegate> _accent(Color light, Color mid, Color dark) => <ValueDelegate>[
  ValueDelegate.color(const <String>['**', 'accent_light'], value: light),
  ValueDelegate.color(const <String>['**', 'accent_mid'], value: mid),
  ValueDelegate.color(const <String>['**', 'accent_dark'], value: dark),
];

void _paintFrame(
  Canvas canvas,
  LottieComposition composition,
  Rect rect,
  double frame, [
  List<ValueDelegate> values = const <ValueDelegate>[],
]) {
  canvas.drawRect(rect, Paint()..color = _background);
  LottieDrawable(composition)
    ..delegates = LottieDelegates(values: values)
    ..setProgress(frame / composition.durationFrames)
    ..draw(canvas, rect, fit: BoxFit.contain);
}

void _paintLabel(Canvas canvas, String text, Offset at) {
  final TextPainter painter = TextPainter(
    text: TextSpan(
      text: text,
      style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 13, fontFamily: 'Roboto'),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  painter.paint(canvas, at);
}

Future<void> _writePng(
  WidgetTester tester,
  String name, {
  required Size size,
  required double pixelRatio,
  required void Function(Canvas canvas) paint,
}) async {
  await tester.runAsync(() async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder)..scale(pixelRatio);
    paint(canvas);
    final ui.Image image = await recorder.endRecording().toImage(
      (size.width * pixelRatio).round(),
      (size.height * pixelRatio).round(),
    );
    final ByteData? bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final File file = File('$_outDir/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> _writeSheet(WidgetTester tester, LottieComposition composition, String name, List<double> frames) {
  const int columns = 6;
  const double cell = 220;
  return _writePng(
    tester,
    name,
    size: Size(columns * cell, (frames.length / columns).ceil() * cell),
    pixelRatio: 1.5,
    paint: (Canvas canvas) {
      for (final (int i, double frame) in frames.indexed) {
        final Rect rect = Rect.fromLTWH((i % columns) * cell, (i ~/ columns) * cell, cell, cell);
        canvas.save();
        canvas.clipRect(rect);
        _paintFrame(canvas, composition, rect, frame);
        _paintLabel(canvas, 'f${frame.toInt()}', rect.topLeft + const Offset(8, 6));
        canvas.restore();
      }
    },
  );
}

void main() {
  testWidgets('draws the daily chest poses, contact sheet and tint proofs', skip: !qaRender, (
    WidgetTester tester,
  ) async {
    await loadFonts();
    final LottieComposition composition = (await tester.runAsync(
      () => LottieComposition.fromBytes(File(_asset).readAsBytesSync()),
    ))!;

    for (final MapEntry<String, double> pose in _poses.entries) {
      await _writePng(
        tester,
        pose.key,
        size: const Size(600, 600),
        pixelRatio: 2,
        paint: (Canvas canvas) => _paintFrame(canvas, composition, const Rect.fromLTWH(0, 0, 600, 600), pose.value),
      );
    }

    await _writeSheet(tester, composition, 'contact_sheet', <double>[
      for (int i = 0; i < 24; i++) (composition.durationFrames * i / 24).roundToDouble(),
    ]);
    await _writeSheet(tester, composition, 'open_sheet', <double>[for (int f = 180; f <= 270; f += 6) f.toDouble()]);

    final List<(String, List<ValueDelegate>)> variants = <(String, List<ValueDelegate>)>[
      ('glow_green', _glow(const Color(0xFF34D399))),
      ('glow_gold', _glow(const Color(0xFFF5B83D))),
      ('glow_violet', _glow(const Color(0xFFA78BFA))),
      ('accent_purple', _accent(const Color(0xFFB7A4FF), const Color(0xFF7C5CFF), const Color(0xFF4B30C9))),
      ('accent_teal', _accent(const Color(0xFF5EEAD4), const Color(0xFF14B8A6), const Color(0xFF0B766B))),
    ];
    const double tile = 340;
    await _writePng(
      tester,
      'tint_proof_sheet',
      size: Size(variants.length * tile, tile * 2),
      pixelRatio: 1.5,
      paint: (Canvas canvas) {
        for (final (int i, (String, List<ValueDelegate>) variant) in variants.indexed) {
          for (final (int row, double frame) in <double>[_openedFrame, 0].indexed) {
            final Rect rect = Rect.fromLTWH(i * tile, row * tile, tile, tile);
            canvas.save();
            canvas.clipRect(rect);
            _paintFrame(canvas, composition, rect, frame, variant.$2);
            _paintLabel(canvas, '${variant.$1} f${frame.toInt()}', rect.topLeft + const Offset(8, 6));
            canvas.restore();
          }
        }
      },
    );
    for (final (String, List<ValueDelegate>) variant in variants) {
      await _writePng(
        tester,
        'tint_${variant.$1}',
        size: const Size(600, 600),
        pixelRatio: 1,
        paint: (Canvas canvas) =>
            _paintFrame(canvas, composition, const Rect.fromLTWH(0, 0, 600, 600), _openedFrame, variant.$2),
      );
    }

    await _writePng(
      tester,
      'thumbnails_96',
      size: const Size(96 * 4, 96),
      pixelRatio: 2,
      paint: (Canvas canvas) {
        for (final (int i, double frame) in <double>[0, 150, 214, _openedFrame].indexed) {
          _paintFrame(canvas, composition, Rect.fromLTWH(i * 96, 0, 96, 96), frame);
        }
      },
    );
    expect(tester.takeException(), isNull);
  });
}
