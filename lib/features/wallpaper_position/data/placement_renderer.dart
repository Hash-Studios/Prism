import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:Prism/features/wallpaper_detail/views/wallpaper_edit/wallpaper_edit_pipeline.dart';
import 'package:Prism/features/wallpaper_position/domain/entities/wallpaper_placement.dart';
import 'package:Prism/features/wallpaper_position/domain/placement_geometry.dart';
import 'package:flutter/painting.dart';
import 'package:palette_generator/palette_generator.dart';

/// Size of the picture the palette is read from.
const int _paletteSide = 64;

/// Draws [source] as [placement] says onto a canvas of [width] x [height] pixels and returns PNG bytes.
///
/// It uses the same recorder and rasterize steps as the editor export.
Future<Uint8List> renderPlacementPng(
  ui.Image source,
  WallpaperPlacement placement, {
  required int width,
  required int height,
  required ui.Color fillColor,
}) async {
  final ui.Size frame = ui.Size(width.toDouble(), height.toDouble());
  final ui.Size image = ui.Size(source.width.toDouble(), source.height.toDouble());
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);
  final Rect bounds = Offset.zero & frame;
  canvas.clipRect(bounds);
  final ui.Size content = PlacementGeometry.contentSize(image, frame, placement.fit);
  final Offset shift = PlacementGeometry.translation(content, frame, placement);
  canvas
    ..save()
    ..translate(shift.dx, shift.dy)
    ..scale(placement.zoom);
  final Rect sourceRect = Offset.zero & image;
  final Paint photo = Paint()..filterQuality = FilterQuality.high;
  switch (placement.fit) {
    case PlacementFit.fill:
      canvas.drawImageRect(source, sourceRect, Offset.zero & content, photo);
    case PlacementFit.fitBlur:
      final double cover = PlacementGeometry.coverScale(image, frame);
      final Rect coverRect = Rect.fromCenter(
        center: bounds.center,
        width: image.width * cover,
        height: image.height * cover,
      );
      final double sigma = PlacementGeometry.blurFraction * math.min(frame.width, frame.height);
      canvas.drawImageRect(
        source,
        sourceRect,
        coverRect,
        Paint()
          ..filterQuality = FilterQuality.medium
          ..imageFilter = ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.mirror),
      );
      canvas.drawImageRect(source, sourceRect, PlacementGeometry.containRect(image, frame), photo);
    case PlacementFit.fitColor:
      canvas.drawRect(bounds, Paint()..color = fillColor);
      canvas.drawImageRect(source, sourceRect, PlacementGeometry.containRect(image, frame), photo);
  }
  canvas.restore();
  if (placement.dim > 0) {
    canvas.drawRect(bounds, Paint()..color = ui.Color.fromRGBO(0, 0, 0, placement.dim));
  }
  final ui.Image rendered = await rasterizePicture(recorder.endRecording(), width, height);
  try {
    final ByteData? data = await rendered.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw StateError('PNG encode returned null');
    return data.buffer.asUint8List();
  } finally {
    rendered.dispose();
  }
}

/// The most common colour of [source], read from a 64 x 64 copy. Falls back to [fallback] for a blank picture.
Future<ui.Color> dominantColorOf(ui.Image source, {ui.Color fallback = const ui.Color(0xFF000000)}) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  Canvas(recorder).drawImageRect(
    source,
    Offset.zero & ui.Size(source.width.toDouble(), source.height.toDouble()),
    Rect.fromLTWH(0, 0, _paletteSide.toDouble(), _paletteSide.toDouble()),
    Paint()..filterQuality = FilterQuality.medium,
  );
  final ui.Image small = await rasterizePicture(recorder.endRecording(), _paletteSide, _paletteSide);
  try {
    final PaletteGenerator palette = await PaletteGenerator.fromImage(small);
    return palette.dominantColor?.color ?? fallback;
  } finally {
    small.dispose();
  }
}
