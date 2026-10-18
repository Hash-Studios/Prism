import 'package:flutter/painting.dart';

/// The three shades of the user accent that the box takes.
class ChestAccent {
  const ChestAccent({required this.light, required this.mid, required this.dark});

  final Color light;
  final Color mid;
  final Color dark;
}

/// Shades of [primary] for the box, or null when [primary] is near grey. A grey accent (AMOLED white, Frost) would turn
/// the box into a grey slab, so the box keeps the purple it was drawn in.
ChestAccent? chestAccentOf(Color primary) {
  if (HSLColor.fromColor(primary).saturation < 0.25) return null;
  return ChestAccent(
    light: Color.lerp(primary, const Color(0xFFFFFFFF), 0.35)!,
    mid: primary,
    dark: Color.lerp(primary, const Color(0xFF000000), 0.35)!,
  );
}
