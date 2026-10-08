enum MotionStyle {
  drift('Drift', 'Slow pan and zoom. Follows your home screen swipes.', isFree: true),
  breathe('Breathe', 'A gentle pulse, in and out.', isFree: false),
  ripple('Ripple', 'Water rings that spread from your touch.', isFree: false),
  shimmer('Shimmer', 'A soft sweep of light.', isFree: false);

  const MotionStyle(this.label, this.description, {required this.isFree});

  final String label;
  final String description;
  final bool isFree;
}

enum GradientStyle {
  aurora('Aurora', 'Soft ribbons of colour.', isFree: true),
  mesh('Mesh', 'Blended colour that slowly shifts.', isFree: true),
  waves('Waves', 'Layered waves that roll.', isFree: false),
  plasma('Plasma', 'Smooth, flowing colour.', isFree: false),
  starfield('Starfield', 'Twinkling stars on pure black.', isFree: false);

  const GradientStyle(this.label, this.description, {required this.isFree});

  final String label;
  final String description;
  final bool isFree;
}
