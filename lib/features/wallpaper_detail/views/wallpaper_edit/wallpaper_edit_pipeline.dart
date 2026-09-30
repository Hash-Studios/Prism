import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

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

ui.ImageFilter kernelImageFilter(KernelEffect effect, {double kernelScale = 1}) {
  final ui.FragmentShader shader = _convolveProgram!.fragmentShader();
  for (int i = 0; i < 9; i++) {
    shader.setFloat(2 + i, effect.kernel[i]);
  }
  shader.setFloat(11, effect.bias / 255);
  shader.setFloat(12, kernelScale);
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
  if (adjustments.blur > 0) {
    final double sigma = adjustments.blur * _maxBlurFraction * shortSide;
    then(ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.mirror));
  }
  return filter;
}

/// Renders [source] at full resolution with the edit applied and returns PNG bytes.
Future<Uint8List> renderEditedPng(
  ui.Image source,
  List<WallpaperFilter> stack,
  WallpaperAdjustments adjustments, {
  double? previewPixelShortSide,
}) async {
  final int width = source.width;
  final int height = source.height;
  final int shortSide = math.min(width, height);
  final double kernelScale = previewPixelShortSide == null ? 1 : kernelScaleForExport(shortSide, previewPixelShortSide);
  final ui.ImageFilter? filter = buildEditFilter(stack, adjustments, shortSide.toDouble(), kernelScale: kernelScale);
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);
  final Rect bounds = Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());
  if (filter != null) canvas.saveLayer(bounds, Paint()..imageFilter = filter);
  canvas.drawImage(source, Offset.zero, Paint()..filterQuality = FilterQuality.high);
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
