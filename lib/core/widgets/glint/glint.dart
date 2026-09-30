import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:Prism/core/widgets/glint/glint_data.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// What Glint is feeling, and so which face, motion and details it shows.
enum GlintMood {
  /// Idle, empty states. Breathes, blinks, and a glint sweeps over the crystal.
  calm,

  /// A wallpaper saved or set. Bounces while sparkles pop.
  happy,

  /// A streak milestone, coins earned. Jumps and clicks back down, with a burst of rays.
  celebrate,

  /// A wall favourited. Sways with heart eyes while hearts float up.
  love,

  /// A new Wall of the Day, a notification. Jumps and stretches, with two "!".
  surprised,

  /// Loading, searching. Tilts and glances about while a sparkle hops around the ring.
  curious,

  /// The streak is kept for today. Stands tall with a smirk and a sparkle.
  proud,

  /// Offline, the streak at risk. Shivers, with a sweat drop.
  worried,

  /// An error, the streak lost. Droops, with a tear.
  sad,

  /// Nothing new, night time. Sways slowly under "z z z".
  sleepy,
}

/// Prism's mascot: the crystal from the logo, with a face, inside the logo's rainbow ring.
///
/// The colours are fixed brand colours (the logo's), not theme colours. A mood changes the face, motion and details;
/// love also warms the ring. Glint is a picture, so screen readers skip it: callers say what it means in words beside
/// it.
///
/// Glint loops while its route and app are active, following [TickerMode]. Under reduce-motion it holds a still pose
/// of the same mood. Because it loops, a test that shows Glint pumps a bounded number of frames instead of
/// `pumpAndSettle`.
class Glint extends StatefulWidget {
  const Glint({super.key, this.mood = GlintMood.calm, this.size = 96});

  final GlintMood mood;

  /// Width and height of the drawing.
  final double size;

  @override
  State<Glint> createState() => _GlintState();
}

class _GlintState extends State<Glint> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  Duration _now = Duration.zero;

  void _onTick(Duration elapsed) => setState(() => _now = elapsed);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (still && _ticker.isActive) _ticker.stop();
    if (!still && !_ticker.isActive) {
      _now = Duration.zero;
      _ticker.start();
    }
  }

  @override
  void didUpdateWidget(Glint oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new mood starts its loop from the top.
    if (oldWidget.mood != widget.mood && _ticker.isActive) {
      _now = Duration.zero;
      _ticker
        ..stop()
        ..start();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: GlintPose(
      mood: widget.mood,
      size: widget.size,
      seconds: _now.inMicroseconds / Duration.microsecondsPerSecond,
      still: !_ticker.isActive,
    ),
  );
}

/// Glint at one moment: [seconds] into its [mood]'s loop.
///
/// [Glint] drives this from a ticker. It is a picture, so it has no semantics.
class GlintPose extends StatelessWidget {
  const GlintPose({super.key, required this.mood, required this.seconds, this.size = 96, this.still = false});

  final GlintMood mood;
  final double seconds;

  /// Width and height of the drawing.
  final double size;

  /// The reduce-motion pose: the mood at its [GlintMoodSpec.stillAt], whatever [seconds] is.
  final bool still;

  @override
  Widget build(BuildContext context) {
    final GlintMoodSpec spec = glintSpecOf(mood);
    final double at = still ? spec.stillAt : seconds;
    final double fraction = (at % spec.period) / spec.period;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _GlintPainter(spec, fraction, love: mood == GlintMood.love)),
      ),
    );
  }
}

/// The design of [mood].
@visibleForTesting
GlintMoodSpec glintSpecOf(GlintMood mood) => switch (mood) {
  GlintMood.calm => glintCalm,
  GlintMood.happy => glintHappy,
  GlintMood.celebrate => glintCelebrate,
  GlintMood.love => glintLove,
  GlintMood.surprised => glintSurprised,
  GlintMood.curious => glintCurious,
  GlintMood.proud => glintProud,
  GlintMood.worried => glintWorried,
  GlintMood.sad => glintSad,
  GlintMood.sleepy => glintSleepy,
};

// ---------------------------------------------------------------- motion

/// A part's motion at one moment.
class _Pose {
  const _Pose(this.tx, this.ty, this.rot, this.sx, this.sy, this.op);

  static const _Pose identity = _Pose(0, 0, 0, 1, 1, 1);

  final double tx;
  final double ty;
  final double rot;
  final double sx;
  final double sy;
  final double op;

  factory _Pose.between(GlintKey a, GlintKey b, double u) => _Pose(
    a.tx + (b.tx - a.tx) * u,
    a.ty + (b.ty - a.ty) * u,
    a.rot + (b.rot - a.rot) * u,
    a.sx + (b.sx - a.sx) * u,
    a.sy + (b.sy - a.sy) * u,
    a.op + (b.op - a.op) * u,
  );
}

const Curve _easeInOut = Cubic(.42, 0, .58, 1);
const Curve _easeIn = Cubic(.42, 0, 1, 1);
const Curve _easeOut = Cubic(0, 0, .58, 1);
const Curve _easePop = Cubic(.34, 1.56, .64, 1);

Curve _curve(GlintEase ease) => switch (ease) {
  GlintEase.inOut => _easeInOut,
  GlintEase.easeIn => _easeIn,
  GlintEase.easeOut => _easeOut,
  GlintEase.pop => _easePop,
  GlintEase.linear => Curves.linear,
};

/// The motion of part [name] at loop fraction [p]: between the two keys around [p], eased by the left one.
_Pose _poseOf(GlintMoodSpec spec, String name, double p) {
  final List<GlintKey>? keys = spec.parts[name];
  if (keys == null) return _Pose.identity;
  for (int i = 0; i < keys.length - 1; i++) {
    final GlintKey a = keys[i];
    final GlintKey b = keys[i + 1];
    if (a.t <= p && p <= b.t) {
      final double u = b.t == a.t ? 0 : _curve(a.ease).transform((p - a.t) / (b.t - a.t));
      return _Pose.between(a, b, u);
    }
  }
  final GlintKey last = keys.last;
  return _Pose(last.tx, last.ty, last.rot, last.sx, last.sy, last.op);
}

// ---------------------------------------------------------------- painter

const double _box = 160;
const Rect _layerBounds = Rect.fromLTWH(-_box, -_box, _box * 3, _box * 3);

class _GlintPainter extends CustomPainter {
  const _GlintPainter(this.spec, this.p, {required this.love});

  final GlintMoodSpec spec;

  /// Loop fraction, 0 to 1.
  final double p;

  /// The love mood warms the ring.
  final bool love;

  /// Draws [draw] moved by part [name], at [origin], and faded by its opacity.
  void _part(Canvas canvas, String name, Offset origin, VoidCallback draw) {
    final _Pose pose = _poseOf(spec, name, p);
    final double op = pose.op.clamp(0.0, 1.0);
    if (op == 0) return;
    canvas.save();
    canvas.translate(origin.dx + pose.tx, origin.dy + pose.ty);
    canvas.rotate(pose.rot * math.pi / 180);
    canvas.scale(pose.sx, pose.sy);
    canvas.translate(-origin.dx, -origin.dy);
    if (op < 1) {
      _opacityPaint.color = Color.fromRGBO(0, 0, 0, op);
      canvas.saveLayer(_layerBounds, _opacityPaint);
    }
    draw();
    if (op < 1) canvas.restore();
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / _box);
    _part(canvas, 'scene', glintPartOrigin['scene']!, () {
      _part(canvas, 'ring', glintPartOrigin['ring']!, () => _drawRing(canvas));
      for (final GlintFx fx in spec.fx) {
        if (fx.behind) _drawFx(canvas, fx);
      }
      _part(canvas, 'body', glintPartOrigin['body']!, () => _drawBody(canvas));
      _part(canvas, 'fx', glintPartOrigin['fx']!, () {
        for (final GlintFx fx in spec.fx) {
          if (!fx.behind) _drawFx(canvas, fx);
        }
      });
    });
    canvas.restore();
  }

  void _drawRing(Canvas canvas) {
    final List<Paint> paints = love ? _warmRing : _coolRing;
    for (int i = 0; i < _ringSegmentPaths.length; i++) {
      canvas.drawPath(_ringSegmentPaths[i], paints[i]);
    }
  }

  void _drawBody(Canvas canvas) {
    canvas.drawPath(glintCrystalPath, _crystalRightPaint);
    canvas.save();
    canvas.clipPath(glintCrystalPath);
    canvas.drawRect(const Rect.fromLTRB(40, 40, glintCrystalSplitX, 125), _crystalLeftPaint);
    canvas.restore();
    canvas.drawLine(glintCrystalHighlight[0], glintCrystalHighlight[1], _crystalHighlightPaint);
    canvas.drawPath(glintCrystalPath, _crystalRimPaint);
    if (spec.parts.containsKey('fx:sheen')) _drawSheen(canvas);
    if (spec.face.cheeks) {
      for (final GlintShape cheek in glintCheeks) {
        _drawShape(canvas, cheek);
      }
    }
    for (final GlintShape brow in spec.face.brows) {
      _drawShape(canvas, brow);
    }
    for (final GlintShape mouth in spec.face.mouth) {
      _drawShape(canvas, mouth);
    }
    _part(canvas, 'eyes', glintPartOrigin['eyes']!, () {
      for (final GlintShape s in spec.face.eyes) {
        _drawShape(canvas, s);
      }
    });
  }

  void _drawSheen(Canvas canvas) {
    canvas.save();
    canvas.clipPath(glintCrystalPath);
    _part(canvas, 'fx:sheen', Offset.zero, () {
      canvas.drawPath(_sheenWidePath, _sheenWidePaint);
      canvas.drawPath(_sheenNarrowPath, _sheenNarrowPaint);
    });
    canvas.restore();
  }

  void _drawFx(Canvas canvas, GlintFx fx) {
    canvas.save();
    canvas.translate(fx.x, fx.y);
    _part(canvas, _fxPartNames.putIfAbsent(fx, () => 'fx:${fx.name}'), Offset.zero, () => _drawFxShape(canvas, fx));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlintPainter old) => old.spec != spec || old.p != p || old.love != love;
}

// ---------------------------------------------------------------- shapes

// These eight overlapping segments and their user-space gradients match glint2.html.
final List<Path> _ringSegmentPaths = [
  Path()
    ..moveTo(80, 25.7)
    ..arcToPoint(const Offset(93.48, 33.07), radius: const Radius.circular(16))
    ..lineTo(113.53, 64.4),
  Path()
    ..moveTo(113.26, 63.98)
    ..lineTo(133.05, 94.89)
    ..arcToPoint(const Offset(134.55, 105.64), radius: const Radius.circular(13)),
  Path()
    ..moveTo(134.69, 105.16)
    ..arcToPoint(const Offset(128.28, 113.34), radius: const Radius.circular(13))
    ..lineTo(107.03, 124.82),
  Path()
    ..moveTo(107.47, 124.58)
    ..lineTo(86.65, 135.82)
    ..arcToPoint(const Offset(79.5, 137.49), radius: const Radius.circular(14)),
  Path()
    ..moveTo(80, 137.5)
    ..arcToPoint(const Offset(73.35, 135.82), radius: const Radius.circular(14))
    ..lineTo(52.09, 124.34),
  Path()
    ..moveTo(52.53, 124.58)
    ..lineTo(31.72, 113.34)
    ..arcToPoint(const Offset(25.2, 104.67), radius: const Radius.circular(13)),
  Path()
    ..moveTo(25.31, 105.16)
    ..arcToPoint(const Offset(26.95, 94.89), radius: const Radius.circular(13))
    ..lineTo(47.01, 63.56),
  Path()
    ..moveTo(46.74, 63.98)
    ..lineTo(66.52, 33.07)
    ..arcToPoint(const Offset(80.5, 25.71), radius: const Radius.circular(16)),
];

const List<Offset> _ringGradientStarts = [
  Offset(80, 25.7),
  Offset(113.26, 63.98),
  Offset(134.69, 105.16),
  Offset(107.47, 124.58),
  Offset(80, 137.5),
  Offset(52.53, 124.58),
  Offset(25.31, 105.16),
  Offset(46.74, 63.98),
];
const List<Offset> _ringGradientEnds = [
  Offset(113.26, 63.98),
  Offset(134.69, 105.16),
  Offset(107.47, 124.58),
  Offset(80, 137.5),
  Offset(52.53, 124.58),
  Offset(25.31, 105.16),
  Offset(46.74, 63.98),
  Offset(80, 25.7),
];

final List<Paint> _coolRing = _ringPaints(glintRingNodeColors);
final List<Paint> _warmRing = _ringPaints([
  for (int i = 0; i < glintRingNodeColors.length; i++) glintRingWarmColors[i] ?? glintRingNodeColors[i],
]);

List<Paint> _ringPaints(List<Color> nodeColors) => [
  for (int i = 0; i < nodeColors.length; i++)
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = glintRingStroke
      ..strokeJoin = StrokeJoin.round
      ..shader = ui.Gradient.linear(_ringGradientStarts[i], _ringGradientEnds[i], [
        nodeColors[i],
        nodeColors[(i + 1) % nodeColors.length],
      ]),
];

final Path _sheenWidePath = Path()..addPolygon(glintSheenWide, true);
final Path _sheenNarrowPath = Path()..addPolygon(glintSheenNarrow, true);
final Paint _sheenWidePaint = Paint()..color = const Color(0xFFBFE6FF).withValues(alpha: .6);
final Paint _sheenNarrowPaint = Paint()..color = glintWhite.withValues(alpha: .85);
final Paint _crystalRightPaint = Paint()..color = glintCrystalRight;
final Paint _crystalLeftPaint = Paint()..color = glintCrystalLeft;
final Paint _crystalHighlightPaint = Paint()
  ..color = glintWhite.withValues(alpha: glintCrystalHighlightOpacity)
  ..strokeWidth = glintCrystalHighlightWidth
  ..strokeCap = StrokeCap.round;
final Paint _crystalRimPaint = Paint()
  ..style = PaintingStyle.stroke
  ..color = glintCrystalRim
  ..strokeWidth = glintCrystalRimWidth
  ..strokeJoin = StrokeJoin.round;
final Paint _opacityPaint = Paint();

final Map<GlintShape, Path> _shapePaths = {};
final Map<GlintFx, Path> _fxPaths = {};
final Map<GlintFx, String> _fxPartNames = {};
final Map<Color, Paint> _fillPaints = {};
final Map<(Color, double), Paint> _strokePaints = {};

Paint _fill(Color color) => _fillPaints.putIfAbsent(color, () => Paint()..color = color);

Paint _cachedStroke(Color color, double width) =>
    _strokePaints.putIfAbsent((color, width), () => _stroke(color, width));

Path _heartPath(GlintHeart shape) => _shapePaths.putIfAbsent(shape, () {
  final double cx = shape.cx;
  final double cy = shape.cy;
  final double k = shape.size;
  return Path()
    ..moveTo(cx, cy + k * 1.2)
    ..cubicTo(cx - k * 1.9, cy + k * .1, cx - k * 1.4, cy - k * 1.6, cx, cy - k * .6)
    ..cubicTo(cx + k * 1.4, cy - k * 1.6, cx + k * 1.9, cy + k * .1, cx, cy + k * 1.2)
    ..close();
});

void _drawShape(Canvas canvas, GlintShape shape) {
  switch (shape) {
    case GlintEllipse():
      canvas.drawOval(
        Rect.fromCenter(center: Offset(shape.cx, shape.cy), width: shape.rx * 2, height: shape.ry * 2),
        _fill(shape.color.withValues(alpha: shape.color.a * shape.opacity)),
      );
    case GlintHeart():
      canvas.drawPath(_heartPath(shape), _fill(shape.color));
    case GlintStroke():
      if (shape.fill != null) canvas.drawPath(shape.path, _fill(shape.fill!));
      canvas.drawPath(shape.path, _cachedStroke(shape.color, shape.width));
  }
}

Paint _stroke(Color color, double width) => Paint()
  ..style = PaintingStyle.stroke
  ..color = color
  ..strokeWidth = width
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

/// An effect at the origin, at size [GlintFx.size].
void _drawFxShape(Canvas canvas, GlintFx fx) {
  final double s = fx.size;
  final Color color = fx.color ?? glintWhite;
  final Paint fill = _fill(color);
  switch (fx.kind) {
    case GlintFxKind.spark:
      canvas.drawPath(
        _fxPaths.putIfAbsent(
          fx,
          () => Path()
            ..moveTo(0, -s)
            ..quadraticBezierTo(0, 0, s, 0)
            ..quadraticBezierTo(0, 0, 0, s)
            ..quadraticBezierTo(0, 0, -s, 0)
            ..quadraticBezierTo(0, 0, 0, -s)
            ..close(),
        ),
        fill,
      );
    case GlintFxKind.heart:
      canvas.drawPath(
        _fxPaths.putIfAbsent(
          fx,
          () => Path()
            ..moveTo(0, s * .9)
            ..cubicTo(-s * 1.6, -s * .1, -s * 1.1, -s * 1.4, 0, -s * .5)
            ..cubicTo(s * 1.1, -s * 1.4, s * 1.6, -s * .1, 0, s * .9)
            ..close(),
        ),
        fill,
      );
    case GlintFxKind.z:
      final double a = 3.5 * s;
      final double b = 4 * s;
      canvas.drawPath(
        _fxPaths.putIfAbsent(
          fx,
          () => Path()
            ..moveTo(-a, -b)
            ..relativeLineTo(2 * a, 0)
            ..relativeLineTo(-2 * a, 2 * b)
            ..relativeLineTo(2 * a, 0),
        ),
        _cachedStroke(color, 2),
      );
    case GlintFxKind.drop:
      canvas.save();
      canvas.scale(s);
      canvas.drawPath(
        _fxPaths.putIfAbsent(
          fx,
          () => Path()
            ..moveTo(0, -5.2)
            ..quadraticBezierTo(4.2, 0, 3.7, 2.6)
            ..arcToPoint(const Offset(-3.7, 2.6), radius: const Radius.circular(3.7))
            ..quadraticBezierTo(-4.2, 0, 0, -5.2)
            ..close(),
        ),
        fill,
      );
      canvas.restore();
    case GlintFxKind.bang:
      canvas.drawLine(Offset(s * -1.2, -3.6), Offset(s * .8, 5), _cachedStroke(color, 2.6));
      canvas.drawCircle(Offset(s * 1.4, 10.4), 1.5, fill);
    case GlintFxKind.rays:
      for (int i = 0; i < glintRayColors.length; i++) {
        final double a = (-50 + 20 * i) * math.pi / 180;
        final double dx = math.sin(a);
        final double dy = math.cos(a);
        canvas.drawLine(Offset(dx * 12, dy * 12), Offset(dx * 48, dy * 48), _cachedStroke(glintRayColors[i], 3));
      }
  }
}
