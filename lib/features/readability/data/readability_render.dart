import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:Prism/features/readability/domain/readability.dart';
import 'package:Prism/features/wallpaper_detail/views/wallpaper_edit/wallpaper_edit_pipeline.dart';
import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter/painting.dart';

/// Black at this opacity sits behind a dimmed zone. It fades to clear past the zone.
const double fixDimOpacity = 0.5;

/// Blur sigma of a softened zone, as a fraction of the frame's short side.
const double fixBlurFraction = 0.012;

/// How far a fix fades out past its zone, as a fraction of the frame height.
const double _feather = 0.1;

/// Paints [fixes] over a [frame] canvas that already holds the wall.
///
/// [redraw] draws the wall again with the given paint, so a blur reads the wall and not what lies over it. The set
/// render, the before and after preview and the analysis frame all paint through here, so the preview matches the file.
void paintReadabilityFixes(
  Canvas canvas,
  Size frame,
  List<ReadabilityFix> fixes, {
  required TargetPlatform platform,
  required void Function(Canvas canvas, Paint paint) redraw,
}) {
  final Rect bounds = Offset.zero & frame;
  for (final ReadabilityFix fix in fixes) {
    for (final Rect zone in readabilityZoneRects(fix.zone, platform)) {
      switch (fix.kind) {
        case ReadabilityFixKind.dim:
          _dim(canvas, bounds, zone);
        case ReadabilityFixKind.blur:
          _blur(canvas, bounds, zone, redraw);
      }
    }
  }
}

/// A black gradient from the nearest screen edge over the zone, fading out past it.
void _dim(Canvas canvas, Rect bounds, Rect zone) {
  final double h = bounds.height;
  final bool fromTop = zone.center.dy < 0.5;
  final double edge = fromTop ? 0 : h;
  final double zoneEnd = (fromTop ? zone.bottom : zone.top) * h;
  final double fadeEnd = fromTop ? zoneEnd + _feather * h : zoneEnd - _feather * h;
  final double hold = (zoneEnd - edge).abs() / (fadeEnd - edge).abs();
  const ui.Color shade = ui.Color.fromRGBO(0, 0, 0, fixDimOpacity);
  canvas.drawRect(
    bounds,
    Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, edge),
        Offset(0, fadeEnd),
        <ui.Color>[shade, shade, const ui.Color(0x00000000)],
        <double>[0, hold, 1],
      ),
  );
}

/// The wall drawn again with a small blur, kept only in a soft band around the zone.
void _blur(Canvas canvas, Rect bounds, Rect zone, void Function(Canvas canvas, Paint paint) redraw) {
  final double h = bounds.height;
  final double sigma = fixBlurFraction * math.min(bounds.width, h);
  final double top = (zone.top - _feather) * h;
  final double bottom = (zone.bottom + _feather) * h;
  final double fade = _feather * h / (bottom - top);
  canvas.saveLayer(bounds, Paint());
  redraw(
    canvas,
    Paint()
      ..filterQuality = FilterQuality.medium
      ..imageFilter = ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.mirror),
  );
  canvas
    ..drawRect(
      bounds,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = ui.Gradient.linear(
          Offset(0, top),
          Offset(0, bottom),
          const <ui.Color>[ui.Color(0x00000000), ui.Color(0xFF000000), ui.Color(0xFF000000), ui.Color(0x00000000)],
          <double>[0, fade, 1 - fade, 1],
        ),
    )
    ..restore();
}

/// [source] as the screen shows it: scaled to cover a [width] x [height] frame, centred, with the colour variation
/// [tint] and then [fixes]. The analysis frame and the before and after preview use it.
Future<ui.Image> renderReadabilityFrame(
  ui.Image source, {
  required int width,
  required int height,
  required TargetPlatform platform,
  ui.Color? tint,
  List<ReadabilityFix> fixes = const <ReadabilityFix>[],
}) {
  final Size frame = Size(width.toDouble(), height.toDouble());
  final Size image = Size(source.width.toDouble(), source.height.toDouble());
  final double scale = math.max(frame.width / image.width, frame.height / image.height);
  final Rect cover = Rect.fromCenter(
    center: frame.center(Offset.zero),
    width: image.width * scale,
    height: image.height * scale,
  );
  final ui.ColorFilter? hue = tint == null ? null : ui.ColorFilter.mode(tint, BlendMode.hue);
  void draw(Canvas canvas, Paint paint) =>
      canvas.drawImageRect(source, Offset.zero & image, cover, paint..colorFilter = hue);

  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder)..clipRect(Offset.zero & frame);
  draw(canvas, Paint()..filterQuality = FilterQuality.medium);
  paintReadabilityFixes(canvas, frame, fixes, platform: platform, redraw: draw);
  return rasterizePicture(recorder.endRecording(), width, height);
}

/// The RGBA pixels of [image], for [analyzeReadability].
Future<ReadabilityFrame> readabilityFrameOf(ui.Image image) async {
  final ByteData? data = await image.toByteData();
  if (data == null) throw StateError('The frame has no pixels');
  return ReadabilityFrame(rgba: data.buffer.asUint8List(), width: image.width, height: image.height);
}

/// Decodes [provider] [height] pixels tall. A wall that is wider than the screen still covers it at this height.
/// The caller owns the image and disposes it.
Future<ui.Image> decodeForFrame(ImageProvider provider, int height) {
  final Completer<ui.Image> done = Completer<ui.Image>();
  final ImageStream stream = ResizeImage(provider, height: height).resolve(ImageConfiguration.empty);
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (info, _) {
      stream.removeListener(listener);
      if (!done.isCompleted) done.complete(info.image);
    },
    onError: (error, stackTrace) {
      stream.removeListener(listener);
      if (!done.isCompleted) done.completeError(error, stackTrace);
    },
  );
  stream.addListener(listener);
  return done.future;
}
