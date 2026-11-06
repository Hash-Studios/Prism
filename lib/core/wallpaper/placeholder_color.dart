import 'package:Prism/core/color/prism_palette.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:flutter/painting.dart';

/// How far a wall's colour moves toward the page surface, so a grid of colour blocks stays calm.
const double _mute = 0.25;

final RegExp _hexColour = RegExp(r'^#?[0-9a-fA-F]{6}$');

/// The block a tile of [item] shows while its picture loads: the wall's dominant colour, mixed a quarter of the way
/// toward [surface]. The hue stays. Null when the wall has no known colour; the caller then keeps its grey pulse.
Color? placeholderColorOf(FeedItemEntity item, Color surface) {
  final Color? colour = switch (item) {
    PrismFeedItem(:final wallpaper) => paletteColorById(wallpaper.colors?.firstOrNull)?.color,
    WallhavenFeedItem(:final wallpaper) => _parseHex(wallpaper.colors?.firstOrNull),
    PexelsFeedItem() => null,
  };
  return colour == null ? null : Color.lerp(colour, surface, _mute);
}

/// A Wallhaven colour such as `#663300`.
Color? _parseHex(String? value) {
  final String hex = value?.trim() ?? '';
  if (!_hexColour.hasMatch(hex)) return null;
  return Color(0xFF000000 | int.parse(hex.replaceFirst('#', ''), radix: 16));
}
