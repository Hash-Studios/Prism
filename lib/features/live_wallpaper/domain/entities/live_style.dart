enum MotionStyle {
  drift,
  breathe,
  ripple,
  shimmer;

  const MotionStyle();

  bool get isFree => this == MotionStyle.drift;
}

enum GradientStyle {
  aurora,
  mesh,
  waves,
  plasma,
  starfield;

  const GradientStyle();

  bool get isFree => this == GradientStyle.aurora || this == GradientStyle.mesh;
}
