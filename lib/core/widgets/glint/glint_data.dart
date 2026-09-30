import 'dart:ui';

// Glint's design numbers: colours, ring, crystal, faces, effects and the keyframes of each mood.
// The geometry is in a 160 x 160 box. See glint.dart for how it is drawn.

// ---------------------------------------------------------------- colours (the logo's, fixed)

const Color glintCoral = Color(0xFFF77E7E);
const Color glintCyan = Color(0xFF4FE3EE);
const Color glintInk = Color(0xFF141418);
const Color glintLavender = Color(0xFF9FA6F5);
const Color glintMagenta = Color(0xFFE45BD6);
const Color glintMint = Color(0xFF7CF0C0);
const Color glintOrange = Color(0xFFF9A24E);
const Color glintPurple = Color(0xFFB65CF0);
const Color glintWhite = Color(0xFFFFFFFF);
const Color glintYellow = Color(0xFFEDE84E);

// ---------------------------------------------------------------- types

/// How a keyframe eases into the next one.
enum GlintEase { inOut, easeIn, easeOut, pop, linear }

/// One keyframe of a part's motion: [t] is the loop fraction (0 to 1).
///
/// Values match the CSS `translate(tx, ty) rotate(rot) scale(sx, sy)` of the design, and [op] is the opacity.
/// A channel left out is the identity. [ease] shapes the way to the next key.
class GlintKey {
  const GlintKey(
    this.t,
    this.ease, {
    this.tx = 0,
    this.ty = 0,
    this.rot = 0,
    double s = 1,
    double? sx,
    double? sy,
    this.op = 1,
  }) : sx = sx ?? s,
       sy = sy ?? s;

  final double t;
  final GlintEase ease;
  final double tx;
  final double ty;

  /// Degrees.
  final double rot;
  final double sx;
  final double sy;
  final double op;
}

/// A face or effect shape.
sealed class GlintShape {
  const GlintShape();
}

/// An ellipse, filled.
class GlintEllipse extends GlintShape {
  const GlintEllipse(this.cx, this.cy, this.rx, this.ry, this.color, [this.opacity = 1]);

  final double cx;
  final double cy;
  final double rx;
  final double ry;
  final Color color;
  final double opacity;
}

/// A small heart, filled: [size] is the design's `k`.
class GlintHeart extends GlintShape {
  const GlintHeart(this.cx, this.cy, this.size, this.color);

  final double cx;
  final double cy;
  final double size;
  final Color color;
}

/// A path with round caps and joins: stroked in [color], and filled if [fill] is set.
class GlintStroke extends GlintShape {
  const GlintStroke(this.path, this.color, this.width, {this.fill});

  final Path path;
  final Color color;
  final double width;
  final Color? fill;
}

/// The parts of a face. The eyes are a separate group so they can blink and glance.
class GlintFace {
  const GlintFace({required this.eyes, required this.brows, required this.cheeks, required this.mouth});

  final List<GlintShape> eyes;
  final List<GlintShape> brows;
  final bool cheeks;
  final List<GlintShape> mouth;
}

enum GlintFxKind { spark, heart, z, drop, bang, rays }

/// An effect: drawn at ([x], [y]) and moved by the part `fx:<name>`. [behind] puts it behind the crystal.
/// The rays have no colour of their own.
class GlintFx {
  const GlintFx(this.kind, this.name, this.x, this.y, this.size, this.color, {this.behind = false});

  final GlintFxKind kind;
  final String name;
  final double x;
  final double y;
  final double size;
  final Color? color;
  final bool behind;
}

/// One mood: its loop, face, effects and the motion of each part.
///
/// [parts] is keyed by `scene`, `body`, `eyes`, `ring`, `fx` or `fx:<name>`. A part that is not listed stays still.
class GlintMoodSpec {
  const GlintMoodSpec({
    required this.period,
    required this.stillAt,
    required this.face,
    this.fx = const [],
    required this.parts,
  });

  /// One loop, in seconds.
  final double period;

  /// The moment of the loop the still pose shows.
  final double stillAt;
  final GlintFace face;
  final List<GlintFx> fx;
  final Map<String, List<GlintKey>> parts;
}

/// A round part of the ring outline: the circle ([cx], [cy], [r]) from [start] for [sweep] radians.
class GlintArc extends GlintRingPiece {
  const GlintArc(this.cx, this.cy, this.r, this.start, this.sweep);

  final double cx;
  final double cy;
  final double r;
  final double start;
  final double sweep;
}

/// A straight part of the ring outline.
class GlintLine extends GlintRingPiece {
  const GlintLine(this.x0, this.y0, this.x1, this.y1);

  final double x0;
  final double y0;
  final double x1;
  final double y1;
}

sealed class GlintRingPiece {
  const GlintRingPiece();
}

// ---------------------------------------------------------------- ring and crystal

const double glintRingStroke = 10;
const Offset glintRingCenter = Offset(80, 81.6);

/// The ring's centre line: the hull of four circles (the logo's rounded kite), clockwise from the top.
/// Arcs and straight edges alternate, and the colours below sit at the middle of each of the eight pieces.
const List<GlintRingPiece> glintRingHull = [
  GlintArc(80, 41.7, 16, -2.572162, 2.002732),
  GlintLine(93.475333, 33.073563, 133.048708, 94.89102),
  GlintArc(122.1, 101.9, 13, -0.56943, 1.645047),
  GlintLine(128.277465, 113.338485, 86.652654, 135.818368),
  GlintArc(80, 123.5, 14, 1.075617, 0.990359),
  GlintLine(73.347346, 135.818368, 31.722535, 113.338485),
  GlintArc(37.9, 101.9, 13, 2.065976, 1.645047),
  GlintLine(26.951292, 94.89102, 66.524667, 33.073563),
];
const List<Color> glintRingNodeColors = [
  glintPurple,
  glintLavender,
  glintCyan,
  glintMint,
  glintYellow,
  glintOrange,
  glintCoral,
  glintMagenta,
];

/// The love mood warms the first four nodes.
const Map<int, Color> glintRingWarmColors = {
  0: Color(0xFFD05CE6),
  1: Color(0xFFF06EC0),
  2: Color(0xFFF77E8E),
  3: Color(0xFFF9968A),
};

const Color glintCrystalLeft = Color(0xFFF5F5F7);
const Color glintCrystalRight = Color(0xFFD9DBE8);
const Color glintCrystalRim = Color(0xFFC4C7D6);
const double glintCrystalRimWidth = 1;
const double glintCrystalSplitX = 80;
const List<Offset> glintCrystalHighlight = [Offset(77.9, 54), Offset(52.6, 97.9)];
const double glintCrystalHighlightWidth = 1.2;
const double glintCrystalHighlightOpacity = 0.6;

/// The four corners of the crystal, top and then clockwise. The outline rounds them by 3.
const List<Offset> glintCrystalCorners = [Offset(80, 46), Offset(113.3, 103.7), Offset(80, 117.8), Offset(46.7, 103.7)];

/// The crystal's outline.
final Path glintCrystalPath = Path()
  ..moveTo(77.4, 50.5)
  ..arcToPoint(const Offset(82.6, 50.5), radius: const Radius.circular(3))
  ..lineTo(111.6, 100.76)
  ..arcToPoint(const Offset(110.18, 105.02), radius: const Radius.circular(3))
  ..lineTo(81.17, 117.3)
  ..arcToPoint(const Offset(78.83, 117.3), radius: const Radius.circular(3))
  ..lineTo(49.82, 105.02)
  ..arcToPoint(const Offset(48.4, 100.76), radius: const Radius.circular(3))
  ..close();

/// The glint that sweeps over the crystal: a wide pale band with a narrow white one inside it.
const List<Offset> glintSheenWide = [Offset(70, 40), Offset(82, 40), Offset(64, 125), Offset(52, 125)];
const List<Offset> glintSheenNarrow = [Offset(74.5, 40), Offset(77.5, 40), Offset(59.5, 125), Offset(56.5, 125)];

/// Where the parts turn, scale and rotate from.
const Map<String, Offset> glintPartOrigin = {
  'scene': Offset(80, 80),
  'body': Offset(80, 117.8),
  'eyes': Offset(80, 86),
  'ring': Offset(80, 81.6),
  'fx': Offset(80, 80),
};

/// The cheeks the moods with `cheeks: true` share.
const List<GlintShape> glintCheeks = [
  GlintEllipse(63, 94, 3.5, 2, glintCoral, 0.45),
  GlintEllipse(97, 94, 3.5, 2, glintCoral, 0.45),
];

/// The colours of the six rays of the celebrate burst, left to right.
const List<Color> glintRayColors = [glintPurple, glintCoral, glintYellow, glintMint, glintCyan, glintLavender];

// ---------------------------------------------------------------- moods

/// Calm: 3.6s loop, still pose at 1.8s.
final GlintMoodSpec glintCalm = GlintMoodSpec(
  period: 3.6,
  stillAt: 1.8,
  face: GlintFace(
    eyes: [
      const GlintEllipse(70, 86, 3.4, 4.2, glintInk),
      const GlintEllipse(71.1, 84.6, 1.1, 1.1, glintWhite),
      const GlintEllipse(90, 86, 3.4, 4.2, glintInk),
      const GlintEllipse(91.1, 84.6, 1.1, 1.1, glintWhite),
    ],
    brows: [],
    cheeks: false,
    mouth: [
      GlintStroke(
        Path()
          ..moveTo(75, 96)
          ..quadraticBezierTo(80, 100.5, 85, 96),
        glintInk,
        2.2,
      ),
    ],
  ),
  parts: const {
    'body': [
      GlintKey(0, GlintEase.inOut),
      GlintKey(0.5, GlintEase.inOut, sx: 1.012, sy: 1.022),
      GlintKey(1, GlintEase.inOut),
    ],
    'ring': [
      GlintKey(0, GlintEase.inOut, op: 0.85),
      GlintKey(0.5, GlintEase.inOut),
      GlintKey(1, GlintEase.inOut, op: 0.85),
    ],
    'eyes': [
      GlintKey(0, GlintEase.inOut),
      GlintKey(0.84, GlintEase.inOut),
      GlintKey(0.89, GlintEase.inOut, sy: 0.08),
      GlintKey(0.94, GlintEase.inOut),
      GlintKey(1, GlintEase.inOut),
    ],
    'fx:sheen': [
      GlintKey(0, GlintEase.inOut, tx: -46, op: 0),
      GlintKey(0.56, GlintEase.inOut, tx: -46, op: 0),
      GlintKey(0.6, GlintEase.linear, tx: -32),
      GlintKey(0.76, GlintEase.inOut, tx: 62),
      GlintKey(0.79, GlintEase.inOut, tx: 70, op: 0),
      GlintKey(1, GlintEase.inOut, tx: 70, op: 0),
    ],
  },
);

/// Happy: 1.2s loop, still pose at 1.05s.
final GlintMoodSpec glintHappy = GlintMoodSpec(
  period: 1.2,
  stillAt: 1.05,
  face: GlintFace(
    eyes: [
      GlintStroke(
        Path()
          ..moveTo(65.5, 88.4)
          ..quadraticBezierTo(70, 79.4, 74.5, 88.4),
        glintInk,
        2.6,
      ),
      GlintStroke(
        Path()
          ..moveTo(85.5, 88.4)
          ..quadraticBezierTo(90, 79.4, 94.5, 88.4),
        glintInk,
        2.6,
      ),
    ],
    brows: [],
    cheeks: true,
    mouth: [
      GlintStroke(
        Path()
          ..moveTo(73, 95)
          ..quadraticBezierTo(80, 96.5, 87, 95)
          ..quadraticBezierTo(86, 104.5, 80, 104.5)
          ..quadraticBezierTo(74, 104.5, 73, 95)
          ..close(),
        glintInk,
        1.4,
        fill: glintInk,
      ),
      GlintStroke(
        Path()
          ..moveTo(76.6, 102.4)
          ..quadraticBezierTo(80, 99.6, 83.4, 102.4)
          ..quadraticBezierTo(80, 105, 76.6, 102.4)
          ..close(),
        glintCoral,
        0.1,
        fill: glintCoral,
      ),
    ],
  ),
  fx: [
    const GlintFx(GlintFxKind.spark, 's1', 43, 52, 4, glintYellow),
    const GlintFx(GlintFxKind.spark, 's2', 119, 47, 3.4, glintCyan),
  ],
  parts: const {
    'body': [
      GlintKey(0, GlintEase.inOut),
      GlintKey(0.12, GlintEase.easeOut, sx: 1.1, sy: 0.88),
      GlintKey(0.36, GlintEase.easeIn, ty: -12, sx: 0.94, sy: 1.09),
      GlintKey(0.6, GlintEase.pop, sx: 1.12, sy: 0.86),
      GlintKey(0.76, GlintEase.inOut, sx: 0.98, sy: 1.02),
      GlintKey(0.88, GlintEase.inOut),
      GlintKey(1, GlintEase.inOut),
    ],
    'ring': [
      GlintKey(0, GlintEase.inOut),
      GlintKey(0.56, GlintEase.inOut),
      GlintKey(0.62, GlintEase.easeOut, s: 1.04),
      GlintKey(0.85, GlintEase.inOut),
      GlintKey(1, GlintEase.inOut),
    ],
    'fx:s1': [
      GlintKey(0, GlintEase.inOut, s: 0, op: 0),
      GlintKey(0.32, GlintEase.inOut, s: 0, op: 0),
      GlintKey(0.4, GlintEase.pop, rot: 20, s: 1.2),
      GlintKey(0.52, GlintEase.inOut, rot: 45),
      GlintKey(0.72, GlintEase.inOut, rot: 90, s: 0.2, op: 0),
      GlintKey(1, GlintEase.inOut, rot: 90, s: 0, op: 0),
    ],
    'fx:s2': [
      GlintKey(0, GlintEase.inOut, s: 0, op: 0),
      GlintKey(0.36, GlintEase.inOut, s: 0, op: 0),
      GlintKey(0.44, GlintEase.pop, rot: -20, s: 1.2),
      GlintKey(0.56, GlintEase.inOut, rot: -45),
      GlintKey(0.76, GlintEase.inOut, rot: -90, s: 0.2, op: 0),
      GlintKey(1, GlintEase.inOut, rot: -90, s: 0, op: 0),
    ],
  },
);

/// Celebrate: 2.2s loop, still pose at 1.72s.
final GlintMoodSpec glintCelebrate = GlintMoodSpec(
  period: 2.2,
  stillAt: 1.72,
  face: GlintFace(
    eyes: [
      GlintStroke(
        Path()
          ..moveTo(65.5, 88.4)
          ..quadraticBezierTo(70, 79.4, 74.5, 88.4),
        glintInk,
        2.6,
      ),
      GlintStroke(
        Path()
          ..moveTo(85.5, 88.4)
          ..quadraticBezierTo(90, 79.4, 94.5, 88.4),
        glintInk,
        2.6,
      ),
    ],
    brows: [
      GlintStroke(
        Path()
          ..moveTo(65.5, 77)
          ..quadraticBezierTo(70, 73.5, 74.5, 75.5),
        glintInk,
        2,
      ),
      GlintStroke(
        Path()
          ..moveTo(85.5, 75.5)
          ..quadraticBezierTo(90, 73.5, 94.5, 77),
        glintInk,
        2,
      ),
    ],
    cheeks: true,
    mouth: [
      GlintStroke(
        Path()
          ..moveTo(71.5, 94.5)
          ..quadraticBezierTo(80, 96.5, 88.5, 94.5)
          ..quadraticBezierTo(88, 108.2, 80, 108.2)
          ..quadraticBezierTo(72, 108.2, 71.5, 94.5)
          ..close(),
        glintInk,
        1.4,
        fill: glintInk,
      ),
      GlintStroke(
        Path()
          ..moveTo(75.2, 104.6)
          ..quadraticBezierTo(80, 100.6, 84.8, 104.6)
          ..quadraticBezierTo(80, 108.8, 75.2, 104.6)
          ..close(),
        glintCoral,
        0.1,
        fill: glintCoral,
      ),
    ],
  ),
  fx: [
    const GlintFx(GlintFxKind.rays, 'rays', 80, 117.8, 0, null),
    const GlintFx(GlintFxKind.spark, 's1', 26, 58, 6, glintYellow),
    const GlintFx(GlintFxKind.spark, 's2', 134, 62, 5.5, glintCyan),
    const GlintFx(GlintFxKind.spark, 's3', 120, 28, 4.6, glintMagenta),
    const GlintFx(GlintFxKind.spark, 's4', 28, 126, 4.6, glintMint),
  ],
  parts: const {
    'scene': [GlintKey(0, GlintEase.inOut, ty: 6, s: 0.78), GlintKey(1, GlintEase.inOut, ty: 6, s: 0.78)],
    'body': [
      GlintKey(0, GlintEase.inOut),
      GlintKey(0.12, GlintEase.easeOut, sx: 1.14, sy: 0.82),
      GlintKey(0.2, GlintEase.easeOut, ty: -8, sx: 0.9, sy: 1.16),
      GlintKey(0.36, GlintEase.inOut, ty: -38, sx: 0.96, sy: 1.06),
      GlintKey(0.44, GlintEase.easeIn, ty: -38),
      GlintKey(0.58, GlintEase.pop, sx: 1.18, sy: 0.78),
      GlintKey(0.68, GlintEase.inOut, sx: 0.98, sy: 1.03),
      GlintKey(0.76, GlintEase.inOut),
      GlintKey(1, GlintEase.inOut),
    ],
    'ring': [
      GlintKey(0, GlintEase.inOut),
      GlintKey(0.2, GlintEase.easeOut, s: 0.97),
      GlintKey(0.36, GlintEase.pop, s: 1.05),
      GlintKey(0.56, GlintEase.inOut),
      GlintKey(0.6, GlintEase.easeOut, s: 1.06),
      GlintKey(0.78, GlintEase.inOut),
      GlintKey(1, GlintEase.inOut),
    ],
    'fx:rays': [
      GlintKey(0, GlintEase.inOut, ty: -24, s: 0.3, op: 0),
      GlintKey(0.26, GlintEase.pop, ty: -24, s: 0.3, op: 0),
      GlintKey(0.36, GlintEase.inOut, ty: -38),
      GlintKey(0.44, GlintEase.easeIn, ty: -38),
      GlintKey(0.56, GlintEase.easeOut, ty: -2, op: 0.8),
      GlintKey(0.72, GlintEase.inOut, s: 1.15, op: 0),
      GlintKey(1, GlintEase.inOut, ty: -24, s: 0.3, op: 0),
    ],
    'fx:s1': [
      GlintKey(0, GlintEase.inOut, s: 0, op: 0),
      GlintKey(0.3, GlintEase.pop, s: 0, op: 0),
      GlintKey(0.38, GlintEase.inOut, rot: 45, s: 1.3),
      GlintKey(0.46, GlintEase.inOut, rot: 90),
      GlintKey(0.86, GlintEase.inOut, rot: 90, s: 1.12),
      GlintKey(0.98, GlintEase.easeIn, rot: 135, s: 0, op: 0),
      GlintKey(1, GlintEase.inOut, s: 0, op: 0),
    ],
    'fx:s2': [
      GlintKey(0, GlintEase.inOut, s: 0, op: 0),
      GlintKey(0.38, GlintEase.pop, s: 0, op: 0),
      GlintKey(0.46, GlintEase.inOut, rot: 45, s: 1.3),
      GlintKey(0.54, GlintEase.inOut, rot: 90),
      GlintKey(0.86, GlintEase.inOut, rot: 90, s: 1.12),
      GlintKey(0.98, GlintEase.easeIn, rot: 135, s: 0, op: 0),
      GlintKey(1, GlintEase.inOut, s: 0, op: 0),
    ],
    'fx:s3': [
      GlintKey(0, GlintEase.inOut, s: 0, op: 0),
      GlintKey(0.46, GlintEase.pop, s: 0, op: 0),
      GlintKey(0.54, GlintEase.inOut, rot: 45, s: 1.3),
      GlintKey(0.62, GlintEase.inOut, rot: 90),
      GlintKey(0.86, GlintEase.inOut, rot: 90, s: 1.12),
      GlintKey(0.98, GlintEase.easeIn, rot: 135, s: 0, op: 0),
      GlintKey(1, GlintEase.inOut, s: 0, op: 0),
    ],
    'fx:s4': [
      GlintKey(0, GlintEase.inOut, s: 0, op: 0),
      GlintKey(0.54, GlintEase.pop, s: 0, op: 0),
      GlintKey(0.62, GlintEase.inOut, rot: 45, s: 1.3),
      GlintKey(0.7, GlintEase.inOut, rot: 90),
      GlintKey(0.86, GlintEase.inOut, rot: 90, s: 1.12),
      GlintKey(0.98, GlintEase.easeIn, rot: 135, s: 0, op: 0),
      GlintKey(1, GlintEase.inOut, s: 0, op: 0),
    ],
  },
);

/// Love: 1.6s loop, still pose at 0.72s.
final GlintMoodSpec glintLove = GlintMoodSpec(
  period: 1.6,
  stillAt: 0.72,
  face: GlintFace(
    eyes: [const GlintHeart(70, 86, 3.6, glintMagenta), const GlintHeart(90, 86, 3.6, glintMagenta)],
    brows: [],
    cheeks: true,
    mouth: [
      GlintStroke(
        Path()
          ..moveTo(74.5, 95.5)
          ..quadraticBezierTo(80, 101.5, 85.5, 95.5),
        glintInk,
        2.2,
      ),
    ],
  ),
  fx: [
    const GlintFx(GlintFxKind.heart, 'h1', 70, 72, 4.6, glintMagenta, behind: true),
    const GlintFx(GlintFxKind.heart, 'h2', 90, 74, 4.2, glintCoral, behind: true),
    const GlintFx(GlintFxKind.heart, 'h3', 80, 66, 3.8, glintMagenta, behind: true),
  ],
  parts: const {
    'body': [
      GlintKey(0, GlintEase.inOut, tx: 1.330858, ty: -0.040661, rot: -3.5),
      GlintKey(0.5, GlintEase.inOut, tx: -1.330858, ty: -0.040661, rot: 3.5),
      GlintKey(1, GlintEase.inOut, tx: 1.330858, ty: -0.040661, rot: -3.5),
    ],
    'eyes': [
      GlintKey(0, GlintEase.inOut),
      GlintKey(0.1, GlintEase.easeOut, s: 1.2),
      GlintKey(0.22, GlintEase.inOut),
      GlintKey(0.5, GlintEase.inOut),
      GlintKey(0.6, GlintEase.easeOut, s: 1.2),
      GlintKey(0.72, GlintEase.inOut),
      GlintKey(1, GlintEase.inOut),
    ],
    'ring': [
      GlintKey(0, GlintEase.inOut, op: 0.92),
      GlintKey(0.1, GlintEase.easeOut, s: 1.02),
      GlintKey(0.22, GlintEase.inOut, op: 0.92),
      GlintKey(0.5, GlintEase.inOut, op: 0.92),
      GlintKey(0.6, GlintEase.easeOut, s: 1.02),
      GlintKey(0.72, GlintEase.inOut, op: 0.92),
      GlintKey(1, GlintEase.inOut, op: 0.92),
    ],
    'fx:h1': [
      GlintKey(0, GlintEase.linear, op: 0),
      GlintKey(0.1, GlintEase.linear),
      GlintKey(0.8, GlintEase.linear, tx: -14, ty: -34),
      GlintKey(1, GlintEase.linear, tx: -17, ty: -42, op: 0),
    ],
    'fx:h2': [
      GlintKey(0, GlintEase.linear, tx: 4.8, ty: -11.657143),
      GlintKey(0.46, GlintEase.linear, tx: 14, ty: -34),
      GlintKey(0.66, GlintEase.linear, op: 0),
      GlintKey(0.76, GlintEase.linear),
      GlintKey(1, GlintEase.linear, tx: 4.8, ty: -11.657143),
    ],
    'fx:h3': [
      GlintKey(0, GlintEase.linear, tx: 1.628571, ty: -19.542857),
      GlintKey(0.13, GlintEase.linear, tx: 2, ty: -24),
      GlintKey(0.33, GlintEase.linear, op: 0),
      GlintKey(0.43, GlintEase.linear),
      GlintKey(1, GlintEase.linear, tx: 1.628571, ty: -19.542857),
    ],
  },
);

/// Surprised: 1.4s loop, still pose at 0.59s.
final GlintMoodSpec glintSurprised = GlintMoodSpec(
  period: 1.4,
  stillAt: 0.59,
  face: GlintFace(
    eyes: [
      const GlintEllipse(70, 86, 4, 5, glintInk),
      const GlintEllipse(71.3, 84.6, 1.5, 1.5, glintWhite),
      const GlintEllipse(90, 86, 4, 5, glintInk),
      const GlintEllipse(91.3, 84.6, 1.5, 1.5, glintWhite),
    ],
    brows: [
      GlintStroke(
        Path()
          ..moveTo(65.5, 76)
          ..quadraticBezierTo(70, 72, 74.5, 74.5),
        glintInk,
        2,
      ),
      GlintStroke(
        Path()
          ..moveTo(85.5, 74.5)
          ..quadraticBezierTo(90, 72, 94.5, 76),
        glintInk,
        2,
      ),
    ],
    cheeks: false,
    mouth: [const GlintEllipse(80, 99, 2.7, 3.5, glintInk)],
  ),
  fx: [
    const GlintFx(GlintFxKind.bang, 'b1', 55, 26, -1, glintOrange),
    const GlintFx(GlintFxKind.bang, 'b2', 105, 26, 1, glintOrange),
  ],
  parts: const {
    'body': [
      GlintKey(0, GlintEase.inOut),
      GlintKey(0.08, GlintEase.easeOut, sx: 1.05, sy: 0.94),
      GlintKey(0.16, GlintEase.pop, ty: -4, sx: 0.9, sy: 1.1),
      GlintKey(0.3, GlintEase.inOut, ty: -3, sx: 0.97, sy: 1.06),
      GlintKey(0.6, GlintEase.easeIn, ty: -3, sx: 0.97, sy: 1.06),
      GlintKey(0.66, GlintEase.pop, sx: 1.05, sy: 0.96),
      GlintKey(0.74, GlintEase.inOut),
      GlintKey(1, GlintEase.inOut),
    ],
    'eyes': [
      GlintKey(0, GlintEase.inOut),
      GlintKey(0.12, GlintEase.inOut),
      GlintKey(0.18, GlintEase.pop, s: 1.2),
      GlintKey(0.3, GlintEase.inOut, s: 1.08),
      GlintKey(0.62, GlintEase.inOut, s: 1.08),
      GlintKey(0.74, GlintEase.inOut),
      GlintKey(1, GlintEase.inOut),
    ],
    'ring': [
      GlintKey(0, GlintEase.inOut),
      GlintKey(0.12, GlintEase.inOut),
      GlintKey(0.18, GlintEase.easeOut, s: 1.07),
      GlintKey(0.34, GlintEase.inOut),
      GlintKey(1, GlintEase.inOut),
    ],
    'fx:b1': [
      GlintKey(0, GlintEase.inOut, s: 0.2, op: 0),
      GlintKey(0.14, GlintEase.pop, s: 0.2, op: 0),
      GlintKey(0.22, GlintEase.inOut, rot: -8, s: 1.15),
      GlintKey(0.3, GlintEase.inOut),
      GlintKey(0.6, GlintEase.inOut),
      GlintKey(0.76, GlintEase.inOut, s: 0.8, op: 0),
      GlintKey(1, GlintEase.inOut, s: 0.2, op: 0),
    ],
    'fx:b2': [
      GlintKey(0, GlintEase.inOut, s: 0.2, op: 0),
      GlintKey(0.16, GlintEase.pop, s: 0.2, op: 0),
      GlintKey(0.24, GlintEase.inOut, rot: 8, s: 1.15),
      GlintKey(0.32, GlintEase.inOut),
      GlintKey(0.6, GlintEase.inOut),
      GlintKey(0.76, GlintEase.inOut, s: 0.8, op: 0),
      GlintKey(1, GlintEase.inOut, s: 0.2, op: 0),
    ],
  },
);

/// Curious: 2.4s loop, still pose at 0.67s.
final GlintMoodSpec glintCurious = GlintMoodSpec(
  period: 2.4,
  stillAt: 0.67,
  face: GlintFace(
    eyes: [
      const GlintEllipse(70, 86, 3.4, 4.4, glintInk),
      const GlintEllipse(71.1, 84.6, 1.3, 1.3, glintWhite),
      const GlintEllipse(90, 86, 3.4, 4.4, glintInk),
      const GlintEllipse(91.1, 84.6, 1.3, 1.3, glintWhite),
    ],
    brows: [
      GlintStroke(
        Path()
          ..moveTo(66, 79.5)
          ..lineTo(73, 79.5),
        glintInk,
        2,
      ),
      GlintStroke(
        Path()
          ..moveTo(86.5, 75.5)
          ..quadraticBezierTo(90.5, 71.5, 95, 74.5),
        glintInk,
        2,
      ),
    ],
    cheeks: false,
    mouth: [
      GlintStroke(
        Path()
          ..moveTo(76.5, 99)
          ..quadraticBezierTo(81, 96.5, 85.5, 98.6),
        glintInk,
        2.2,
      ),
    ],
  ),
  fx: [const GlintFx(GlintFxKind.spark, 's1', 25.3, 105.2, 4.8, glintWhite)],
  parts: const {
    'body': [
      GlintKey(0, GlintEase.inOut),
      GlintKey(0.2, GlintEase.inOut, tx: 2.27872, ty: -0.119423, rot: -6),
      GlintKey(0.44, GlintEase.inOut, tx: 2.27872, ty: -0.119423, rot: -6),
      GlintKey(0.66, GlintEase.inOut, tx: -2.27872, ty: -0.119423, rot: 6),
      GlintKey(0.86, GlintEase.inOut, tx: -2.27872, ty: -0.119423, rot: 6),
      GlintKey(1, GlintEase.inOut),
    ],
    'eyes': [
      GlintKey(0, GlintEase.inOut),
      GlintKey(0.14, GlintEase.inOut, tx: -1.7),
      GlintKey(0.4, GlintEase.inOut, tx: -1.7),
      GlintKey(0.6, GlintEase.inOut, tx: 1.7),
      GlintKey(0.84, GlintEase.inOut, tx: 1.7),
      GlintKey(0.98, GlintEase.inOut),
      GlintKey(1, GlintEase.inOut),
    ],
    'fx:s1': [
      GlintKey(0, GlintEase.inOut, s: 0, op: 0),
      GlintKey(0.04, GlintEase.pop, s: 0, op: 0),
      GlintKey(0.1, GlintEase.inOut, s: 1.2),
      GlintKey(0.2, GlintEase.inOut, tx: 13.5, ty: -14.5),
      GlintKey(0.3, GlintEase.inOut, tx: 27.9, ty: -29.4, s: 1.1),
      GlintKey(0.4, GlintEase.inOut, tx: 27.9, ty: -29.4, s: 0.8, op: 0),
      GlintKey(0.5, GlintEase.inOut, tx: 27.9, ty: -29.4, s: 0, op: 0),
      GlintKey(0.56, GlintEase.pop, tx: 27.9, ty: -29.4, s: 0, op: 0),
      GlintKey(0.62, GlintEase.inOut, tx: 27.9, ty: -29.4, s: 1.2),
      GlintKey(0.72, GlintEase.inOut, tx: 54, ty: -8),
      GlintKey(0.82, GlintEase.inOut, tx: 80, ty: -8, s: 1.1),
      GlintKey(0.92, GlintEase.inOut, tx: 110, s: 0, op: 0),
      GlintKey(1, GlintEase.inOut, s: 0, op: 0),
    ],
  },
);

/// Proud: 2.0s loop, still pose at 1.1s.
final GlintMoodSpec glintProud = GlintMoodSpec(
  period: 2,
  stillAt: 1.1,
  face: GlintFace(
    eyes: [
      GlintStroke(
        Path()
          ..moveTo(65.5, 85.5)
          ..quadraticBezierTo(70, 89.4, 74.5, 85.5),
        glintInk,
        2.6,
      ),
      GlintStroke(
        Path()
          ..moveTo(85.5, 85.5)
          ..quadraticBezierTo(90, 89.4, 94.5, 85.5),
        glintInk,
        2.6,
      ),
    ],
    brows: [],
    cheeks: true,
    mouth: [
      GlintStroke(
        Path()
          ..moveTo(74.5, 97)
          ..quadraticBezierTo(80.5, 101.5, 87, 94.6),
        glintInk,
        2.2,
      ),
      GlintStroke(
        Path()
          ..moveTo(87, 94.6)
          ..lineTo(88.2, 93.4),
        glintInk,
        1.6,
      ),
    ],
  ),
  fx: [const GlintFx(GlintFxKind.spark, 's1', 80, 40, 5, glintYellow)],
  parts: const {
    'body': [
      GlintKey(0, GlintEase.inOut),
      GlintKey(0.2, GlintEase.inOut, sx: 0.985, sy: 1.05),
      GlintKey(0.8, GlintEase.inOut, sx: 0.985, sy: 1.05),
      GlintKey(1, GlintEase.inOut),
    ],
    'eyes': [
      GlintKey(0, GlintEase.inOut),
      GlintKey(0.2, GlintEase.inOut, ty: -0.6),
      GlintKey(0.8, GlintEase.inOut, ty: -0.6),
      GlintKey(1, GlintEase.inOut),
    ],
    'ring': [
      GlintKey(0, GlintEase.inOut, op: 0.9),
      GlintKey(0.3, GlintEase.inOut),
      GlintKey(0.8, GlintEase.inOut),
      GlintKey(1, GlintEase.inOut, op: 0.9),
    ],
    'fx:sheen': [
      GlintKey(0, GlintEase.inOut, tx: -46, op: 0),
      GlintKey(0.34, GlintEase.inOut, tx: -46, op: 0),
      GlintKey(0.38, GlintEase.linear, tx: -32),
      GlintKey(0.58, GlintEase.inOut, tx: 62),
      GlintKey(0.62, GlintEase.inOut, tx: 70, op: 0),
      GlintKey(1, GlintEase.inOut, tx: 70, op: 0),
    ],
    'fx:s1': [
      GlintKey(0, GlintEase.inOut, s: 0, op: 0),
      GlintKey(0.46, GlintEase.pop, s: 0, op: 0),
      GlintKey(0.54, GlintEase.inOut, rot: 30, s: 1.35),
      GlintKey(0.62, GlintEase.inOut, rot: 45),
      GlintKey(0.82, GlintEase.easeIn, rot: 60),
      GlintKey(0.92, GlintEase.inOut, rot: 90, s: 0, op: 0),
      GlintKey(1, GlintEase.inOut, s: 0, op: 0),
    ],
  },
);

/// Worried: 1.8s loop, still pose at 0.27s.
final GlintMoodSpec glintWorried = GlintMoodSpec(
  period: 1.8,
  stillAt: 0.27,
  face: GlintFace(
    eyes: [
      const GlintEllipse(70, 85.7, 3.9, 4.9, glintInk),
      const GlintEllipse(71.1, 84.3, 1.2, 1.2, glintWhite),
      const GlintEllipse(90, 85.7, 3.9, 4.9, glintInk),
      const GlintEllipse(91.1, 84.3, 1.2, 1.2, glintWhite),
    ],
    brows: [
      GlintStroke(
        Path()
          ..moveTo(66, 78.4)
          ..lineTo(72.8, 74.2),
        glintInk,
        2,
      ),
      GlintStroke(
        Path()
          ..moveTo(87.2, 74.2)
          ..lineTo(94, 78.4),
        glintInk,
        2,
      ),
    ],
    cheeks: false,
    mouth: [
      GlintStroke(
        Path()
          ..moveTo(72.5, 99)
          ..quadraticBezierTo(75, 96.4, 77.5, 99)
          ..quadraticBezierTo(80, 101.6, 82.5, 99)
          ..quadraticBezierTo(85, 96.4, 87.5, 99),
        glintInk,
        2.1,
      ),
    ],
  ),
  fx: [const GlintFx(GlintFxKind.drop, 'd1', 100.5, 62, 1, glintCyan)],
  parts: const {
    'body': [
      GlintKey(0, GlintEase.inOut, ty: 0.6, sy: 0.985),
      GlintKey(0.3, GlintEase.linear, ty: 0.6, sy: 0.985),
      GlintKey(0.33, GlintEase.linear, tx: 1.6, ty: 0.6, sy: 0.985),
      GlintKey(0.36, GlintEase.linear, tx: -1.6, ty: 0.6, sy: 0.985),
      GlintKey(0.39, GlintEase.linear, tx: 1.6, ty: 0.6, sy: 0.985),
      GlintKey(0.42, GlintEase.linear, tx: -1.6, ty: 0.6, sy: 0.985),
      GlintKey(0.45, GlintEase.linear, tx: 1.6, ty: 0.6, sy: 0.985),
      GlintKey(0.48, GlintEase.linear, tx: -1.6, ty: 0.6, sy: 0.985),
      GlintKey(0.51, GlintEase.inOut, ty: 0.6, sy: 0.985),
      GlintKey(0.66, GlintEase.linear, ty: 0.6, sy: 0.985),
      GlintKey(0.69, GlintEase.linear, tx: 1.6, ty: 0.6, sy: 0.985),
      GlintKey(0.72, GlintEase.linear, tx: -1.6, ty: 0.6, sy: 0.985),
      GlintKey(0.75, GlintEase.linear, tx: 1.6, ty: 0.6, sy: 0.985),
      GlintKey(0.78, GlintEase.linear, tx: -1.6, ty: 0.6, sy: 0.985),
      GlintKey(0.81, GlintEase.linear, tx: 1.6, ty: 0.6, sy: 0.985),
      GlintKey(0.84, GlintEase.linear, tx: -1.6, ty: 0.6, sy: 0.985),
      GlintKey(0.87, GlintEase.inOut, ty: 0.6, sy: 0.985),
      GlintKey(1, GlintEase.inOut, ty: 0.6, sy: 0.985),
    ],
    'eyes': [
      GlintKey(0, GlintEase.inOut),
      GlintKey(0.34, GlintEase.inOut),
      GlintKey(0.4, GlintEase.inOut, tx: -1.2),
      GlintKey(0.58, GlintEase.inOut, tx: -1.2),
      GlintKey(0.64, GlintEase.inOut, tx: 1.2),
      GlintKey(0.9, GlintEase.inOut, tx: 1.2),
      GlintKey(0.96, GlintEase.inOut),
      GlintKey(1, GlintEase.inOut),
    ],
    'ring': [
      GlintKey(0, GlintEase.inOut),
      GlintKey(0.5, GlintEase.linear),
      GlintKey(0.54, GlintEase.linear, op: 0.55),
      GlintKey(0.59, GlintEase.linear),
      GlintKey(0.63, GlintEase.linear, op: 0.6),
      GlintKey(0.68, GlintEase.inOut),
      GlintKey(1, GlintEase.inOut),
    ],
    'fx:d1': [
      GlintKey(0, GlintEase.inOut, s: 0.4, op: 0),
      GlintKey(0.06, GlintEase.easeOut),
      GlintKey(0.3, GlintEase.inOut, ty: 2),
      GlintKey(0.72, GlintEase.easeIn, ty: 20, op: 0.9),
      GlintKey(0.84, GlintEase.inOut, ty: 26, s: 0.9, op: 0),
      GlintKey(1, GlintEase.inOut, s: 0.4, op: 0),
    ],
  },
);

/// Sad: 3.2s loop, still pose at 1.9s.
final GlintMoodSpec glintSad = GlintMoodSpec(
  period: 3.2,
  stillAt: 1.9,
  face: GlintFace(
    eyes: [
      const GlintEllipse(70, 87.2, 3.4, 3.9, glintInk),
      const GlintEllipse(71, 85.8, 1.5, 1.5, glintWhite),
      const GlintEllipse(90, 87.2, 3.4, 3.9, glintInk),
      const GlintEllipse(91, 85.8, 1.5, 1.5, glintWhite),
    ],
    brows: [
      GlintStroke(
        Path()
          ..moveTo(65, 81.6)
          ..lineTo(72.4, 78),
        glintInk,
        2.2,
      ),
      GlintStroke(
        Path()
          ..moveTo(87.6, 78)
          ..lineTo(95, 81.6),
        glintInk,
        2.2,
      ),
    ],
    cheeks: false,
    mouth: [
      GlintStroke(
        Path()
          ..moveTo(75.5, 100.6)
          ..quadraticBezierTo(80, 95.8, 84.5, 100.6),
        glintInk,
        2.2,
      ),
    ],
  ),
  fx: [const GlintFx(GlintFxKind.drop, 'd1', 66.6, 92.5, 0.62, glintCyan)],
  parts: const {
    'body': [
      GlintKey(0, GlintEase.inOut, ty: 4, sy: 0.96),
      GlintKey(0.45, GlintEase.inOut, ty: 4.9, sx: 1.01, sy: 0.945),
      GlintKey(1, GlintEase.inOut, ty: 4, sy: 0.96),
    ],
    'eyes': [
      GlintKey(0, GlintEase.inOut),
      GlintKey(0.58, GlintEase.inOut),
      GlintKey(0.64, GlintEase.inOut, sy: 0.15),
      GlintKey(0.72, GlintEase.inOut),
      GlintKey(1, GlintEase.inOut),
    ],
    'ring': [GlintKey(0, GlintEase.inOut, op: 0.45), GlintKey(1, GlintEase.inOut, op: 0.45)],
    'fx:d1': [
      GlintKey(0, GlintEase.inOut, s: 0, op: 0),
      GlintKey(0.2, GlintEase.easeOut, s: 0, op: 0),
      GlintKey(0.32, GlintEase.easeIn),
      GlintKey(0.5, GlintEase.easeIn),
      GlintKey(0.76, GlintEase.inOut, ty: 15, op: 0.9),
      GlintKey(0.84, GlintEase.inOut, ty: 18, s: 0.9, op: 0),
      GlintKey(1, GlintEase.inOut, s: 0, op: 0),
    ],
  },
);

/// Sleepy: 4.0s loop, still pose at 2.0s.
final GlintMoodSpec glintSleepy = GlintMoodSpec(
  period: 4,
  stillAt: 2,
  face: GlintFace(
    eyes: [
      GlintStroke(
        Path()
          ..moveTo(65.5, 85.5)
          ..quadraticBezierTo(70, 90.6, 74.5, 85.5),
        glintInk,
        2.4,
      ),
      GlintStroke(
        Path()
          ..moveTo(85.5, 85.5)
          ..quadraticBezierTo(90, 90.6, 94.5, 85.5),
        glintInk,
        2.4,
      ),
    ],
    brows: [],
    cheeks: false,
    mouth: [const GlintEllipse(80, 98.6, 1.5, 1.2, glintInk)],
  ),
  fx: [
    const GlintFx(GlintFxKind.z, 'z1', 100, 58, 1, glintLavender),
    const GlintFx(GlintFxKind.z, 'z2', 106, 50, 1.25, glintLavender),
  ],
  parts: const {
    'body': [
      GlintKey(0, GlintEase.inOut, tx: 3.033974, ty: -0.212156, rot: -8),
      GlintKey(0.5, GlintEase.inOut, tx: 3.033974, ty: -0.212156, rot: -8, sx: 1.01, sy: 1.025),
      GlintKey(0.62, GlintEase.inOut, tx: 3.033974, ty: -0.212156, rot: -8, sy: 1.02),
      GlintKey(0.82, GlintEase.easeOut, tx: 4.532475, ty: -0.476382, rot: -12),
      GlintKey(0.87, GlintEase.inOut, tx: 3.033974, ty: -0.212156, rot: -8),
      GlintKey(1, GlintEase.inOut, tx: 3.033974, ty: -0.212156, rot: -8),
    ],
    'ring': [GlintKey(0, GlintEase.inOut, op: 0.35), GlintKey(1, GlintEase.inOut, op: 0.35)],
    'fx:z1': [
      GlintKey(0, GlintEase.linear, op: 0),
      GlintKey(0.2, GlintEase.linear, tx: 2, ty: -4),
      GlintKey(0.75, GlintEase.linear, tx: 10, ty: -20),
      GlintKey(1, GlintEase.linear, tx: 13, ty: -26, op: 0),
    ],
    'fx:z2': [
      GlintKey(0, GlintEase.linear, tx: 4.909091, ty: -9.818182),
      GlintKey(0.35, GlintEase.linear, tx: 10, ty: -20),
      GlintKey(0.6, GlintEase.linear, op: 0),
      GlintKey(0.8, GlintEase.linear, tx: 2, ty: -4),
      GlintKey(1, GlintEase.linear, tx: 4.909091, ty: -9.818182),
    ],
  },
);
