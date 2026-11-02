enum MotionStyle {
  drift,
  breathe,
  ripple,
  shimmer,

  /// "3D": moves the photo in depth with the wall's depth map. Shown only for walls that have one.
  depth;

  const MotionStyle();

  bool get isFree => this == MotionStyle.drift;

  bool get needsDepthMap => this == MotionStyle.depth;
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
