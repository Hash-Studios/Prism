import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Color, Rect;

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show TargetPlatform;

/// A part of the screen where the system draws text over the wallpaper.
enum ReadabilityZone {
  /// The lock screen clock and date.
  clock,

  /// The home screen icons, their labels, and the dock.
  icons,
}

/// How a fix makes a busy zone readable.
enum ReadabilityFixKind {
  /// A soft black gradient behind the zone, for text that has too little contrast.
  dim,

  /// A small blur behind the zone, for a background with too much detail.
  blur,
}

/// The rectangles of [zone] on [platform], as fractions of the screen from 0 to 1.
///
/// Each platform has its own layout. The values come from Prism's lock and home previews
/// (`preview_layers.dart`), which follow the stock iOS and Android layouts. Launchers differ, so a zone is approximate.
List<Rect> readabilityZoneRects(ReadabilityZone zone, TargetPlatform platform) =>
    (platform == TargetPlatform.iOS ? _iosZones : _androidZones)[zone]!;

const Map<ReadabilityZone, List<Rect>> _iosZones = <ReadabilityZone, List<Rect>>{
  // The date and the large clock under the status bar.
  ReadabilityZone.clock: <Rect>[Rect.fromLTRB(0.12, 0.09, 0.88, 0.27)],
  // The icon grid fills from the top. The dock sits at the bottom.
  ReadabilityZone.icons: <Rect>[Rect.fromLTRB(0.05, 0.08, 0.95, 0.50), Rect.fromLTRB(0.03, 0.84, 0.97, 0.95)],
};

const Map<ReadabilityZone, List<Rect>> _androidZones = <ReadabilityZone, List<Rect>>{
  // The large clock in the top third.
  ReadabilityZone.clock: <Rect>[Rect.fromLTRB(0.10, 0.07, 0.90, 0.30)],
  // Two icon rows and the dock above the search bar.
  ReadabilityZone.icons: <Rect>[Rect.fromLTRB(0.04, 0.60, 0.96, 0.88)],
};

/// A fix the user applied to one zone. It changes only the image that the user sets, never the source wall.
class ReadabilityFix extends Equatable {
  const ReadabilityFix(this.zone, this.kind);

  final ReadabilityZone zone;
  final ReadabilityFixKind kind;

  /// Safe in a file name, for example `clock-dim`.
  String get key => '${zone.name}-${kind.name}';

  @override
  List<Object?> get props => <Object?>[zone, kind];
}

/// The file name key of a list of fixes, for example `read-clock-dim`.
String readabilityFixesKey(List<ReadabilityFix> fixes) => 'read-${fixes.map((fix) => fix.key).join('-')}';

/// What the analysis found for one zone. A zone with a [fix] is busy. A zone without one is ok.
class ReadabilityResult extends Equatable {
  const ReadabilityResult({required this.zone, required this.lowContrastShare, required this.edgeShare, this.fix});

  final ReadabilityZone zone;

  /// The share of the zone, 0 to 1, where text has less than [minContrast] against the wall.
  final double lowContrastShare;

  /// The share of the zone, 0 to 1, that is a sharp edge.
  final double edgeShare;

  /// The fix to offer. Null when the zone is ok.
  final ReadabilityFixKind? fix;

  bool get busy => fix != null;

  @override
  List<Object?> get props => <Object?>[zone, lowContrastShare, edgeShare, fix];
}

/// The minimum contrast ratio that counts as readable. WCAG asks 3:1 for large text.
const double minContrast = 3;

// ponytail: fixed thresholds, tuned on the fixtures and a few real walls. Move them to Remote Config if they misfire.
/// A zone is busy for contrast when more than this share of it is below [minContrast].
const double maxLowContrastShare = 0.25;

/// A zone is busy for detail when more than this share of it is a sharp edge.
const double maxEdgeShare = 0.22;

/// The luma step between neighbour pixels that counts as a sharp edge, on a 0 to 1 scale.
const double edgeStep = 0.15;

/// The width of the frame the analysis reads. The height follows the screen aspect.
const int analysisWidth = 108;

/// One frame for [analyzeReadability]: RGBA pixels of the image as it will show on the screen.
class ReadabilityFrame {
  const ReadabilityFrame({required this.rgba, required this.width, required this.height});

  final Uint8List rgba;
  final int width;
  final int height;
}

/// Checks each zone of [frame] against the colour of its text. Pure, so it runs in an isolate.
///
/// [textColors] gives the text colour per zone. A zone without one uses white.
Map<ReadabilityZone, ReadabilityResult> analyzeReadability(
  ReadabilityFrame frame, {
  required TargetPlatform platform,
  Map<ReadabilityZone, Color> textColors = const <ReadabilityZone, Color>{},
}) {
  final int width = frame.width;
  final int height = frame.height;
  if (width < 2 || height < 2 || frame.rgba.length < width * height * 4) {
    throw ArgumentError('A frame needs at least 2 x 2 RGBA pixels');
  }
  final Float32List luma = Float32List(width * height);
  final Float32List linear = Float32List(width * height);
  for (int i = 0; i < width * height; i++) {
    final double r = frame.rgba[i * 4] / 255;
    final double g = frame.rgba[i * 4 + 1] / 255;
    final double b = frame.rgba[i * 4 + 2] / 255;
    luma[i] = 0.2126 * r + 0.7152 * g + 0.0722 * b;
    linear[i] = 0.2126 * _toLinear(r) + 0.7152 * _toLinear(g) + 0.0722 * _toLinear(b);
  }
  return <ReadabilityZone, ReadabilityResult>{
    for (final ReadabilityZone zone in ReadabilityZone.values)
      zone: _zoneResult(
        zone,
        readabilityZoneRects(zone, platform),
        luma,
        linear,
        width,
        height,
        textColors[zone] ?? const Color(0xFFFFFFFF),
      ),
  };
}

ReadabilityResult _zoneResult(
  ReadabilityZone zone,
  List<Rect> rects,
  Float32List luma,
  Float32List linear,
  int width,
  int height,
  Color text,
) {
  final double textLuminance = text.computeLuminance();
  int pixels = 0;
  int lowContrast = 0;
  int edges = 0;
  for (final Rect rect in rects) {
    final int left = (rect.left * width).floor().clamp(0, width - 2);
    final int right = (rect.right * width).ceil().clamp(left + 1, width - 1);
    final int top = (rect.top * height).floor().clamp(0, height - 2);
    final int bottom = (rect.bottom * height).ceil().clamp(top + 1, height - 1);
    for (int y = top; y < bottom; y++) {
      for (int x = left; x < right; x++) {
        final int i = y * width + x;
        pixels++;
        final double lighter = math.max(linear[i], textLuminance);
        final double darker = math.min(linear[i], textLuminance);
        if ((lighter + 0.05) / (darker + 0.05) < minContrast) lowContrast++;
        final double step = (luma[i + 1] - luma[i]).abs() + (luma[i + width] - luma[i]).abs();
        if (step > edgeStep) edges++;
      }
    }
  }
  final double lowShare = pixels == 0 ? 0 : lowContrast / pixels;
  final double edgeShare = pixels == 0 ? 0 : edges / pixels;
  return ReadabilityResult(
    zone: zone,
    lowContrastShare: lowShare,
    edgeShare: edgeShare,
    fix: lowShare > maxLowContrastShare
        ? ReadabilityFixKind.dim
        : edgeShare > maxEdgeShare
        ? ReadabilityFixKind.blur
        : null,
  );
}

double _toLinear(double channel) =>
    channel <= 0.04045 ? channel / 12.92 : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();
