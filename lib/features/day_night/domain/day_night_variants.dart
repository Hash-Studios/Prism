import 'package:Prism/core/color/prism_palette.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/day_night/domain/entities/day_night_pair.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/variant_group.dart';
import 'package:flutter/painting.dart';

/// The colour of a stored main colour: a Prism palette id or a hex value such as "#663399".
Color? dayNightMainColor(String? stored) {
  final String value = stored?.trim().toLowerCase() ?? '';
  if (value.isEmpty) return null;
  final Color? palette = paletteColorById(value)?.color;
  if (palette != null) return palette;
  final String hex = value.replaceFirst('#', '');
  final int? rgb = hex.length == 6 ? int.tryParse(hex, radix: 16) : null;
  return rgb == null ? null : Color(0xFF000000 | rgb);
}

/// The lightest variant for day and the darkest for night, by the luminance of each wall's main colour.
/// Null when fewer than two variants have a main colour, or when all of them are equally light.
({DayNightWall day, DayNightWall night})? dayNightFromVariants(VariantGroup group) {
  final List<(DayNightWall, double)> lit = <(DayNightWall, double)>[
    for (final wall in group.walls)
      if (dayNightMainColor(wall.colors?.firstOrNull) case final Color color)
        (DayNightWall.fromFeedItem(PrismFeedItem(id: wall.id, wallpaper: wall)), color.computeLuminance()),
  ];
  if (lit.length < 2) return null;
  lit.sort((a, b) => b.$2.compareTo(a.$2));
  if (lit.first.$2 == lit.last.$2) return null;
  return (day: lit.first.$1, night: lit.last.$1);
}
