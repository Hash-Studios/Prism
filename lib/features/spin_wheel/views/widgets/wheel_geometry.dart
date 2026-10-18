import 'dart:math' as math;

/// Every size of the wheel as a share of its diameter, so the machine scales with the screen.
class WheelGeometry {
  const WheelGeometry(this.diameter);

  final double diameter;

  @override
  bool operator ==(Object other) => other is WheelGeometry && other.diameter == diameter;

  @override
  int get hashCode => diameter.hashCode;

  double get radius => diameter / 2;

  /// The gold ring, outer edge to inner edge.
  double get bezelWidth => diameter * 0.078;

  /// The dark ring between the bezel and the face.
  double get ringWidth => diameter * 0.03;

  /// Radius of the wheel face.
  double get faceRadius => radius - bezelWidth - ringWidth;

  /// Radius of the circle the bulbs sit on.
  double get bulbOrbit => radius - bezelWidth / 2;

  double get bulbRadius => bezelWidth * 0.225;

  /// Radius of the hub.
  double get hubRadius => faceRadius * 0.23;

  /// Radius the pegs sit on, near the rim of the face.
  double get pegOrbit => faceRadius * 0.945;

  double get pegRadius => faceRadius * 0.03;

  /// Where the pointer's tip rests, from the centre. It reaches the pegs.
  double get tipRadius => faceRadius * 0.9;

  /// The radial span of a slice label, from the hub to just inside the pegs.
  double get labelInner => faceRadius * 0.35;
  double get labelOuter => faceRadius * 0.83;

  /// How far the plinth reaches up behind the wheel, as a share of the diameter.
  double get plinthOverlap => diameter * 0.2;

  /// Width of the label of one slice at its inner end, where the slice is narrowest.
  double labelWidthAt(double radius, int count) => 2 * radius * math.sin(math.pi / count);
}
