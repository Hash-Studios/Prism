import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:Prism/features/wallpaper_detail/domain/entities/crop_spec.dart';
import 'package:Prism/features/wallpaper_detail/views/wallpaper_edit/color_matrix.dart';
import 'package:Prism/features/wallpaper_detail/views/wallpaper_edit/wallpaper_filters.dart';
import 'package:Prism/logger/logger.dart';
import 'package:flutter/painting.dart';

/// Blur sigma at full slider, as a fraction of the image's short side.
const double _maxBlurFraction = 0.04;

ui.FragmentProgram? _convolveProgram;

/// Loads the convolution shader. Returns false when [KernelEffect]s cannot run on this device.
Future<bool> loadKernelEffects() async {
  if (!ui.ImageFilter.isShaderFilterSupported) return false;
  try {
    _convolveProgram ??= await ui.FragmentProgram.fromAsset('shaders/convolve3x3.frag');
    return true;
  } catch (error, stackTrace) {
    logger.w('convolve3x3 shader unavailable', error: error, stackTrace: stackTrace);
    return false;
  }
}

ui.ImageFilter kernelImageFilter(KernelEffect effect, {double kernelScale = 1, double lightness = 0}) {
  final ui.FragmentShader shader = _convolveProgram!.fragmentShader();
  for (int i = 0; i < 9; i++) {
    shader.setFloat(2 + i, effect.kernel[i]);
  }
  shader.setFloat(11, effect.bias / 255);
  shader.setFloat(12, kernelScale);
  shader.setFloat(13, lightness);
  return ui.ImageFilter.shader(shader);
}

double kernelScaleForExport(int sourceShortSide, double previewPixelShortSide) =>
    sourceShortSide / previewPixelShortSide;

Future<ui.Image> rasterizePicture(ui.Picture picture, int width, int height) async {
  try {
    return await picture.toImage(width, height);
  } finally {
    picture.dispose();
  }
}

/// Builds one GPU filter for the stack, applied in selection order, then the sliders, then blur.
/// [shortSide] is the short side of the drawn image in the filter's pixel space.
ui.ImageFilter? buildEditFilter(
  List<WallpaperFilter> stack,
  WallpaperAdjustments adjustments,
  double shortSide, {
  double kernelScale = 1,
}) {
  ui.ImageFilter? filter;
  ColorMatrix? pending;

  void then(ui.ImageFilter next) =>
      filter = filter == null ? next : ui.ImageFilter.compose(outer: next, inner: filter!);
  void flush() {
    if (pending != null && !isIdentityMatrix(pending!)) then(ColorFilter.matrix(pending!));
    pending = null;
  }

  for (final WallpaperFilter item in stack) {
    switch (item) {
      case ColorPreset():
        pending = pending == null ? item.matrix : composeMatrices(pending!, item.matrix);
      case KernelEffect():
        flush();
        then(kernelImageFilter(item, kernelScale: kernelScale));
    }
  }
  pending = pending == null ? adjustments.matrix : composeMatrices(pending!, adjustments.matrix);
  flush();
  if (adjustments.lightness != 0) {
    then(
      kernelImageFilter(const KernelEffect('Lightness', [0, 0, 0, 0, 1, 0, 0, 0, 0]), lightness: adjustments.lightness),
    );
  }
  if (adjustments.blur > 0) {
    final double sigma = adjustments.blur * _maxBlurFraction * shortSide;
    then(ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.mirror));
  }
  return filter;
}

/// Longest side the editor exports, in pixels, unless the device screen is larger.
const int maxExportLongSide = 4096;

/// Size the export is rendered at: [width] x [height], scaled down so the long side fits the cap.
/// The cap is [maxExportLongSide] or the device's native long side, whichever is larger.
({int width, int height}) exportSize(int width, int height, {double deviceLongSidePx = 0}) {
  final int cap = math.max(maxExportLongSide, deviceLongSidePx.ceil());
  final int longSide = math.max(width, height);
  if (longSide <= cap) return (width: width, height: height);
  final double scale = cap / longSide;
  return (width: math.max(1, (width * scale).round()), height: math.max(1, (height * scale).round()));
}

/// How long an export may take before the editor gives up and says so.
const Duration editExportTimeLimit = Duration(seconds: 30);

/// The export did not finish inside [editExportTimeLimit].
class EditExportTimedOut implements Exception {
  const EditExportTimedOut();
}

/// Runs [export] under [limit]. Throws [EditExportTimedOut] when it runs out.
Future<T> withExportTimeLimit<T>(Future<T> export, {Duration limit = editExportTimeLimit}) =>
    export.timeout(limit, onTimeout: () => throw const EditExportTimedOut());

/// Renders [source] with the edit applied and returns PNG bytes.
///
/// A [crop] that is not the identity is applied first, in source pixels, so the filters run on the kept area only. The
/// output is then the kept area at full resolution. Without a crop the long side is capped, see [exportSize].
Future<Uint8List> renderEditedPng(
  ui.Image source,
  List<WallpaperFilter> stack,
  WallpaperAdjustments adjustments, {
  CropSpec? crop,
  double? previewPixelShortSide,
  double deviceLongSidePx = 0,
}) async {
  final CropSpec? applied = crop == null || crop.isIdentity ? null : crop;
  if (applied != null && (applied.sourceWidth != source.width || applied.sourceHeight != source.height)) {
    throw StateError(
      'Crop is for ${applied.sourceWidth}x${applied.sourceHeight}, source is ${source.width}x${source.height}',
    );
  }
  final ({int width, int height}) size = applied == null
      ? exportSize(source.width, source.height, deviceLongSidePx: deviceLongSidePx)
      : (width: applied.outputWidth, height: applied.outputHeight);
  final int width = size.width;
  final int height = size.height;
  final int shortSide = math.min(width, height);
  final double kernelScale = previewPixelShortSide == null ? 1 : kernelScaleForExport(shortSide, previewPixelShortSide);
  final ui.ImageFilter? filter = buildEditFilter(stack, adjustments, shortSide.toDouble(), kernelScale: kernelScale);
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);
  final Rect bounds = Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());
  if (filter != null) canvas.saveLayer(bounds, Paint()..imageFilter = filter);
  final Paint paint = Paint()..filterQuality = FilterQuality.high;
  if (applied == null) {
    canvas.drawImageRect(source, Rect.fromLTWH(0, 0, source.width.toDouble(), source.height.toDouble()), bounds, paint);
  } else {
    final PixelRect area = applied.sourceRect;
    canvas
      ..save()
      ..translate(
        applied.quarterTurns == 1 || applied.quarterTurns == 2 ? width.toDouble() : 0,
        applied.quarterTurns >= 2 ? height.toDouble() : 0,
      )
      ..rotate(applied.quarterTurns * math.pi / 2)
      ..drawImageRect(
        source,
        Rect.fromLTWH(area.left.toDouble(), area.top.toDouble(), area.width.toDouble(), area.height.toDouble()),
        Rect.fromLTWH(0, 0, area.width.toDouble(), area.height.toDouble()),
        paint,
      )
      ..restore();
  }
  if (filter != null) canvas.restore();
  final ui.Picture picture = recorder.endRecording();
  final ui.Image rendered = await rasterizePicture(picture, width, height);
  try {
    final ByteData? data = await rendered.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw StateError('PNG encode returned null');
    return data.buffer.asUint8List();
  } finally {
    rendered.dispose();
  }
}

/// Decodes the image at [path] and renders it with the edit, see [renderEditedPng]. The decode, the render and the
/// PNG encode run on the engine's threads, so the UI thread only waits.
Future<Uint8List> renderEditedFile(
  String path, {
  required List<WallpaperFilter> stack,
  required WallpaperAdjustments adjustments,
  CropSpec? crop,
  double? previewPixelShortSide,
  double deviceLongSidePx = 0,
}) async {
  final ui.Codec codec = await ui.instantiateImageCodecFromBuffer(await ui.ImmutableBuffer.fromFilePath(path));
  try {
    final ui.FrameInfo frame = await codec.getNextFrame();
    try {
      return await renderEditedPng(
        frame.image,
        stack,
        adjustments,
        crop: crop,
        previewPixelShortSide: previewPixelShortSide,
        deviceLongSidePx: deviceLongSidePx,
      );
    } finally {
      frame.image.dispose();
    }
  } finally {
    codec.dispose();
  }
}
