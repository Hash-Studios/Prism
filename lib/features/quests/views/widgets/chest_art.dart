import 'dart:math' as math;

import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/quests/domain/quest_board.dart';
import 'package:Prism/features/spin_wheel/views/widgets/wheel_palette.dart';
import 'package:flutter/material.dart';

/// The painted chest. [lid] runs 0 (shut) to 1 (wide open), [glow] 0 to 1 is the light behind it.
class ChestArt extends StatelessWidget {
  const ChestArt({super.key, required this.size, this.lid = 0, this.glow = 0, this.locked = false});

  final double size;
  final double lid;
  final double glow;

  /// Draws the padlock on the front.
  final bool locked;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(
      painter: _ChestPainter(lid: lid, glow: glow, locked: locked),
    ),
  );
}

/// The chest on the quest board for [stage]: locked, ready (it glows and wobbles), or opened.
class LiveChest extends StatefulWidget {
  const LiveChest({super.key, required this.stage, required this.size});

  final ChestStage stage;
  final double size;

  @override
  State<LiveChest> createState() => _LiveChestState();
}

class _LiveChestState extends State<LiveChest> with TickerProviderStateMixin {
  static const Duration _cycle = Duration(milliseconds: 2400);

  /// The wobble runs from 25 % to 42 % of a cycle: 400 ms, then the chest rests.
  static const double _wobbleStart = 0.25;
  static const double _wobbleEnd = _wobbleStart + 400 / 2400;
  static const double _wobbleAngle = 4 * math.pi / 180;

  /// Ray wedges repeat every 30 degrees, so one cycle turns them one wedge and the loop has no seam.
  static const double _raysPerCycle = math.pi / 6;

  late final AnimationController _c = AnimationController(vsync: this, duration: _cycle);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(LiveChest oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.stage == ChestStage.ready && !context.reduceMotion) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  static double _wobble(double f) {
    if (f < _wobbleStart || f > _wobbleEnd) return 0;
    final double p = (f - _wobbleStart) / (_wobbleEnd - _wobbleStart);
    return math.sin(p * 6 * math.pi) * (1 - p) * _wobbleAngle;
  }

  Widget _ready(BuildContext context, Widget? _) {
    final double f = _c.isAnimating ? _c.value : 0;
    return Transform.rotate(
      angle: _wobble(f),
      alignment: const Alignment(0, 2 * _baseBottom - 1),
      child: SizedBox.square(
        dimension: widget.size,
        child: CustomPaint(
          painter: _ChestPainter(
            lid: 0,
            glow: 0.8 + 0.2 * math.sin(2 * math.pi * f),
            locked: false,
            raysTurn: f * _raysPerCycle,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => switch (widget.stage) {
    ChestStage.locked => ChestArt(size: widget.size, locked: true),
    ChestStage.opened => ChestArt(size: widget.size, lid: 1),
    ChestStage.ready => RepaintBoundary(
      child: AnimatedBuilder(animation: _c, builder: _ready),
    ),
  };
}

/// Where the foot of the chest sits in its box, as a fraction of the box height.
const double _baseBottom = 0.84;

/// The fixed colours of the chest. It is an illustration like the coin, so it never follows the accent.
class _ChestColors {
  factory _ChestColors() {
    final HSLColor warning = HSLColor.fromColor(PrismColors.warning);
    Color wood(double lightness, [double saturation = 0.55]) =>
        warning.withHue((warning.hue - 12) % 360).withSaturation(saturation).withLightness(lightness).toColor();
    return _ChestColors._(
      gold: WheelGold(),
      plankLit: wood(0.52),
      plank: wood(0.42),
      plankDark: wood(0.3),
      ink: wood(0.14),
      interior: wood(0.08, 0.5),
    );
  }

  _ChestColors._({
    required this.gold,
    required this.plankLit,
    required this.plank,
    required this.plankDark,
    required this.ink,
    required this.interior,
  });

  final WheelGold gold;
  final Color plankLit;
  final Color plank;
  final Color plankDark;

  /// The outline of every part, a dark wood.
  final Color ink;

  /// The dark inside of the open chest.
  final Color interior;
}

final _ChestColors _colors = _ChestColors();

class _ChestPainter extends CustomPainter {
  const _ChestPainter({required this.lid, required this.glow, required this.locked, this.raysTurn = 0});

  final double lid;
  final double glow;
  final bool locked;

  /// The turn of the rays, in radians.
  final double raysTurn;

  static const double _openAngle = 20 * math.pi / 180;
  static const double _liftShare = 0.35;

  /// The mouth of the open chest sits at the centre of the box, so a burst from the centre leaves the chest.
  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width;
    final double cx = s / 2;
    final Rect base = Rect.fromLTRB(cx - s * 0.32, s * _baseBottom - s * 0.27, cx + s * 0.32, s * _baseBottom);
    final double open = lid.clamp(0.0, 1.0);
    if (glow > 0) _rays(canvas, s);
    _shadow(canvas, s, base);
    if (open > 0) _interior(canvas, s, base, open);
    _base(canvas, s, base);
    _lid(canvas, s, base);
    if (locked) _padlock(canvas, s, base);
  }

  Paint _outline(double s, [double scale = 1]) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = s * 0.03 * scale
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round
    ..color = _colors.ink;

  Shader _goldDown(Rect r) => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[_colors.gold.light, _colors.gold.base, _colors.gold.deep],
    stops: const <double>[0, 0.45, 1],
  ).createShader(r);

  void _rays(Canvas canvas, double s) {
    final Offset heart = Offset(s / 2, s * 0.5);
    final double radius = s * 0.5 * (0.7 + 0.3 * glow);
    final Path wedges = Path();
    for (int i = 0; i < 12; i++) {
      wedges
        ..moveTo(heart.dx, heart.dy)
        ..arcTo(Rect.fromCircle(center: heart, radius: radius), raysTurn + i * math.pi / 6, math.pi / 12, false)
        ..close();
    }
    canvas.drawPath(
      wedges,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            _colors.gold.light.withValues(alpha: 0.7 * glow),
            _colors.gold.light.withValues(alpha: 0),
          ],
          stops: const <double>[0.25, 1],
        ).createShader(Rect.fromCircle(center: heart, radius: radius)),
    );
    canvas.drawCircle(
      heart,
      s * 0.42,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            _colors.gold.glint.withValues(alpha: 0.55 * glow),
            _colors.gold.light.withValues(alpha: 0.25 * glow),
            _colors.gold.light.withValues(alpha: 0),
          ],
          stops: const <double>[0, 0.4, 1],
        ).createShader(Rect.fromCircle(center: heart, radius: s * 0.42)),
    );
  }

  void _shadow(Canvas canvas, double s, Rect base) {
    canvas.drawOval(
      Rect.fromCenter(center: Offset(s / 2, base.bottom + s * 0.012), width: s * 0.74, height: s * 0.075),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.24)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.02),
    );
  }

  void _interior(Canvas canvas, double s, Rect base, double open) {
    final WheelGold gold = _colors.gold;
    final double light = Curves.easeOut.transform(open);
    final RRect mouth = RRect.fromLTRBR(
      base.left + s * 0.03,
      base.top - s * 0.11,
      base.right - s * 0.03,
      base.top + s * 0.03,
      Radius.circular(s * 0.045),
    );
    canvas.drawRRect(mouth, Paint()..color = _colors.interior);
    canvas.drawRRect(
      mouth,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, 0.9),
          radius: 0.8,
          colors: <Color>[
            gold.glint.withValues(alpha: light),
            gold.base.withValues(alpha: 0.7 * light),
            gold.deep.withValues(alpha: 0),
          ],
          stops: const <double>[0, 0.45, 1],
        ).createShader(mouth.outerRect),
    );
    canvas.drawRRect(mouth, _outline(s, 0.8));

    final Offset lip = Offset(s / 2, mouth.top + s * 0.03);
    canvas.drawCircle(
      lip,
      s * 0.28,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            gold.glint.withValues(alpha: 0.85 * light),
            gold.light.withValues(alpha: 0.35 * light),
            gold.light.withValues(alpha: 0),
          ],
          stops: const <double>[0, 0.35, 1],
        ).createShader(Rect.fromCircle(center: lip, radius: s * 0.28)),
    );

    final double rise = Curves.easeOut.transform(((open - 0.3) / 0.7).clamp(0.0, 1.0));
    if (rise <= 0) return;
    const List<(double, double)> heap = <(double, double)>[
      (-0.13, 0.05),
      (0.13, 0.05),
      (0, 0.015),
      (-0.07, 0.07),
      (0.07, 0.07),
    ];
    for (final (double dx, double dy) in heap) {
      _coinTop(canvas, s, Offset(s / 2 + dx * s, mouth.top + (dy + 0.045 + 0.08 * (1 - rise)) * s));
    }
  }

  void _coinTop(Canvas canvas, double s, Offset center) {
    final Rect disc = Rect.fromCenter(center: center, width: s * 0.15, height: s * 0.075);
    canvas.drawOval(disc, Paint()..shader = _goldDown(disc));
    canvas.drawOval(disc.deflate(s * 0.014), Paint()..color = _colors.gold.light);
    canvas.drawOval(disc, _outline(s, 0.45));
  }

  void _band(Canvas canvas, double s, Rect r) {
    canvas.drawRect(
      r,
      Paint()
        ..shader = LinearGradient(
          colors: <Color>[_colors.gold.base, _colors.gold.highlight, _colors.gold.light, _colors.gold.deep],
          stops: const <double>[0, 0.3, 0.6, 1],
        ).createShader(r),
    );
    final Paint edge = _outline(s, 0.45)..strokeCap = StrokeCap.butt;
    canvas.drawLine(r.topLeft, r.bottomLeft, edge);
    canvas.drawLine(r.topRight, r.bottomRight, edge);
  }

  void _base(Canvas canvas, double s, Rect base) {
    final double cx = s / 2;
    final RRect body = RRect.fromRectAndCorners(
      base,
      topLeft: Radius.circular(s * 0.02),
      topRight: Radius.circular(s * 0.02),
      bottomLeft: Radius.circular(s * 0.05),
      bottomRight: Radius.circular(s * 0.05),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[_colors.plank, _colors.plankDark],
        ).createShader(base),
    );
    canvas.save();
    canvas.clipRRect(body);
    for (int i = 1; i <= 2; i++) {
      final double y = base.top + base.height * i / 3;
      canvas.drawLine(
        Offset(base.left, y),
        Offset(base.right, y),
        Paint()
          ..color = _colors.ink.withValues(alpha: 0.65)
          ..strokeWidth = s * 0.016,
      );
      canvas.drawLine(
        Offset(base.left, y + s * 0.014),
        Offset(base.right, y + s * 0.014),
        Paint()
          ..color = _colors.plankLit.withValues(alpha: 0.5)
          ..strokeWidth = s * 0.01,
      );
    }
    for (final double dx in <double>[-s * 0.215, s * 0.215]) {
      _band(canvas, s, Rect.fromCenter(center: Offset(cx + dx, base.center.dy), width: s * 0.085, height: base.height));
    }
    canvas.restore();
    canvas.drawRRect(body, _outline(s));

    for (final bool left in <bool>[true, false]) {
      final double edge = left ? base.left : base.right;
      final double x0 = left ? edge - s * 0.015 : edge - s * 0.1;
      final Rect cap = Rect.fromLTRB(x0, base.bottom - s * 0.115, x0 + s * 0.115, base.bottom + s * 0.015);
      final RRect capShape = RRect.fromRectAndCorners(
        cap,
        topLeft: Radius.circular(s * 0.02),
        topRight: Radius.circular(s * 0.02),
        bottomLeft: Radius.circular(left ? s * 0.05 : s * 0.02),
        bottomRight: Radius.circular(left ? s * 0.02 : s * 0.05),
      );
      canvas.drawRRect(capShape, Paint()..shader = _goldDown(cap));
      canvas.drawRRect(capShape, _outline(s, 0.7));
      canvas.drawCircle(cap.center, s * 0.012, Paint()..color = _colors.gold.dark);
    }

    if (!locked) _plate(canvas, s, base);
  }

  void _plate(Canvas canvas, double s, Rect base) {
    final Rect r = Rect.fromCenter(center: Offset(s / 2, base.top + s * 0.095), width: s * 0.13, height: s * 0.15);
    final RRect shape = RRect.fromRectAndRadius(r, Radius.circular(s * 0.035));
    canvas.drawRRect(shape, Paint()..shader = _goldDown(r));
    canvas.drawRRect(shape, _outline(s, 0.7));
    _keyhole(canvas, s, r.center.translate(0, -s * 0.008), s * 0.019);
  }

  void _keyhole(Canvas canvas, double s, Offset center, double radius) {
    final Paint hole = Paint()..color = _colors.ink;
    canvas.drawCircle(center, radius, hole);
    canvas.drawPath(
      Path()
        ..moveTo(center.dx - radius * 0.6, center.dy)
        ..lineTo(center.dx + radius * 0.6, center.dy)
        ..lineTo(center.dx + radius * 0.9, center.dy + radius * 2.2)
        ..lineTo(center.dx - radius * 0.9, center.dy + radius * 2.2)
        ..close(),
      hole,
    );
  }

  Path _domePath(double w, double side, double dome) {
    final double r = w / 2;
    return Path()
      ..moveTo(-r, 0)
      ..lineTo(-r, -side)
      ..arcTo(Rect.fromLTRB(-r, -side - dome, r, -side + dome), math.pi, math.pi, false)
      ..lineTo(r, 0)
      ..close();
  }

  void _lid(Canvas canvas, double s, Rect base) {
    final double w = s * 0.7;
    final double r = w / 2;
    final double side = s * 0.075;
    final double dome = s * 0.2;
    final double chestHeight = base.height + side + dome;
    canvas.save();
    canvas.translate(s / 2, base.top + s * 0.012);
    canvas.translate(0, -lid * _liftShare * chestHeight);
    canvas.rotate(-lid * _openAngle);

    final Path shape = _domePath(w, side, dome);
    final Rect bounds = Rect.fromLTRB(-r, -side - dome, r, 0);
    canvas.drawPath(
      shape,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[_colors.plankLit, _colors.plank, _colors.plankDark],
          stops: const <double>[0, 0.5, 1],
        ).createShader(bounds),
    );
    canvas.save();
    canvas.clipPath(shape);
    canvas.drawArc(
      Rect.fromLTRB(-r, -side - dome * 0.62, r, -side + dome * 0.62),
      math.pi,
      math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.016
        ..color = _colors.ink.withValues(alpha: 0.5),
    );
    for (final double dx in <double>[-s * 0.215, s * 0.215]) {
      _band(canvas, s, Rect.fromLTRB(dx - s * 0.0425, -side - dome, dx + s * 0.0425, 0));
    }
    final Rect trim = Rect.fromLTRB(-r, -s * 0.05, r, 0);
    canvas.drawRect(trim, Paint()..shader = _goldDown(trim));
    canvas.drawLine(trim.topLeft, trim.topRight, _outline(s, 0.55)..strokeCap = StrokeCap.butt);
    canvas.restore();

    canvas.drawArc(
      Rect.fromLTRB(-r + s * 0.05, -side - dome + s * 0.04, r - s * 0.05, -side + dome - s * 0.04),
      math.pi + 0.3,
      0.7,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.022
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.3),
    );
    canvas.drawPath(shape, _outline(s));
    canvas.restore();
  }

  void _padlock(Canvas canvas, double s, Rect base) {
    final double cx = s / 2;
    final Rect body = Rect.fromCenter(center: Offset(cx, base.top + s * 0.065), width: s * 0.17, height: s * 0.14);
    final RRect shape = RRect.fromRectAndRadius(body, Radius.circular(s * 0.035));
    final Path shackle = Path()
      ..moveTo(cx - s * 0.04, body.top + s * 0.01)
      ..lineTo(cx - s * 0.04, body.top - s * 0.035)
      ..arcTo(
        Rect.fromCenter(center: Offset(cx, body.top - s * 0.035), width: s * 0.08, height: s * 0.09),
        math.pi,
        math.pi,
        false,
      )
      ..lineTo(cx + s * 0.04, body.top + s * 0.01);
    canvas.drawPath(shackle, _outline(s, 2.1)..strokeCap = StrokeCap.butt);
    canvas.drawPath(
      shackle,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.03
        ..color = _colors.gold.light,
    );
    canvas.drawRRect(shape, Paint()..shader = _goldDown(body));
    canvas.drawRRect(shape, _outline(s));
    canvas.drawLine(
      Offset(body.left + s * 0.03, body.top + s * 0.022),
      Offset(body.right - s * 0.03, body.top + s * 0.022),
      Paint()
        ..strokeWidth = s * 0.014
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.4),
    );
    _keyhole(canvas, s, body.center.translate(0, -s * 0.008), s * 0.019);
  }

  @override
  bool shouldRepaint(_ChestPainter old) =>
      old.lid != lid || old.glow != glow || old.locked != locked || old.raysTurn != raysTurn;
}
