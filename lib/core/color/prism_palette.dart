import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:Prism/l10n/l10n.dart';

/// One of the twelve colours Prism uses to find wallpapers by colour.
///
/// [id] is the value stored in `walls.colors`. [hex] is six digits without `#`, and is the Wallhaven `colors` value.
/// [pexelsName] is the Pexels `color` value.
class PrismPaletteColor {
  const PrismPaletteColor({required this.id, required this.name, required this.hex, required this.pexelsName});

  final String id;
  final String name;
  final String hex;
  final String pexelsName;

  Color get color => Color(0xFF000000 | int.parse(hex, radix: 16));

  @override
  bool operator ==(Object other) => other is PrismPaletteColor && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'PrismPaletteColor($id)';
}

const List<PrismPaletteColor> prismPalette = <PrismPaletteColor>[
  PrismPaletteColor(id: 'red', name: 'Red', hex: 'cc0000', pexelsName: 'red'),
  PrismPaletteColor(id: 'orange', name: 'Orange', hex: 'ff6600', pexelsName: 'orange'),
  PrismPaletteColor(id: 'yellow', name: 'Yellow', hex: 'ffcc33', pexelsName: 'yellow'),
  PrismPaletteColor(id: 'green', name: 'Green', hex: '669900', pexelsName: 'green'),
  PrismPaletteColor(id: 'teal', name: 'Teal', hex: '66cccc', pexelsName: 'turquoise'),
  PrismPaletteColor(id: 'blue', name: 'Blue', hex: '0066cc', pexelsName: 'blue'),
  PrismPaletteColor(id: 'purple', name: 'Purple', hex: '663399', pexelsName: 'violet'),
  PrismPaletteColor(id: 'pink', name: 'Pink', hex: 'ea4c88', pexelsName: 'pink'),
  PrismPaletteColor(id: 'brown', name: 'Brown', hex: '663300', pexelsName: 'brown'),
  PrismPaletteColor(id: 'black', name: 'Black', hex: '000000', pexelsName: 'black'),
  PrismPaletteColor(id: 'grey', name: 'Grey', hex: '999999', pexelsName: 'gray'),
  PrismPaletteColor(id: 'white', name: 'White', hex: 'ffffff', pexelsName: 'white'),
];

/// Localized display label for a palette entry. The [PrismPaletteColor.id] remains the stable search key.
String prismPaletteColorDisplayName(PrismPaletteColor color, AppLocalizations l10n) => switch (color.id) {
  'red' => l10n.coreColorRed,
  'orange' => l10n.coreColorOrange,
  'yellow' => l10n.coreColorYellow,
  'green' => l10n.coreColorGreen,
  'teal' => l10n.coreColorTeal,
  'blue' => l10n.coreColorBlue,
  'purple' => l10n.coreColorPurple,
  'pink' => l10n.coreColorPink,
  'brown' => l10n.coreColorBrown,
  'black' => l10n.coreColorBlack,
  'grey' => l10n.coreColorGrey,
  'white' => l10n.coreColorWhite,
  _ => color.name,
};

/// The palette colour with [id], or `null` when there is none.
PrismPaletteColor? paletteColorById(String? id) {
  for (final PrismPaletteColor entry in prismPalette) {
    if (entry.id == id) {
      return entry;
    }
  }
  return null;
}

/// The palette colour closest to [color] by CIE76 distance in Lab space. Alpha is ignored.
PrismPaletteColor nearestPaletteColor(Color color) {
  final _Lab target = _Lab.fromColor(color);
  PrismPaletteColor best = prismPalette.first;
  double bestDistance = double.infinity;
  for (final PrismPaletteColor entry in prismPalette) {
    final double distance = target.distanceTo(_Lab.fromColor(entry.color));
    if (distance < bestDistance) {
      bestDistance = distance;
      best = entry;
    }
  }
  return best;
}

class _Lab {
  const _Lab(this.l, this.a, this.b);

  factory _Lab.fromColor(Color color) {
    final double r = _linear(color.r);
    final double g = _linear(color.g);
    final double b = _linear(color.b);
    final double x = (0.4124564 * r + 0.3575761 * g + 0.1804375 * b) / 0.95047;
    final double y = 0.2126729 * r + 0.7151522 * g + 0.0721750 * b;
    final double z = (0.0193339 * r + 0.1191920 * g + 0.9503041 * b) / 1.08883;
    final double fx = _pivot(x);
    final double fy = _pivot(y);
    final double fz = _pivot(z);
    return _Lab(116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz));
  }

  final double l;
  final double a;
  final double b;

  double distanceTo(_Lab other) {
    final double dl = l - other.l;
    final double da = a - other.a;
    final double db = b - other.b;
    return math.sqrt(dl * dl + da * da + db * db);
  }

  static double _linear(double channel) =>
      channel <= 0.04045 ? channel / 12.92 : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();

  static double _pivot(double t) => t > 0.008856 ? math.pow(t, 1 / 3).toDouble() : 7.787 * t + 16 / 116;
}
