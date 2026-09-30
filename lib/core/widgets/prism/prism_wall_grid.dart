import 'package:Prism/core/widgets/animated/press_scale.dart';
import 'package:Prism/core/widgets/prism_image_tile.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// The one wallpaper grid layout. Every grid of wallpapers in the app uses these numbers, so the feed, search,
/// collections, favourites and profiles line up.
// ignore: avoid_classes_with_only_static_members
abstract final class PrismWallGrid {
  /// Gap between tiles.
  static const double spacing = 8;

  /// Left and right margin of a grid. Smaller than the text page margin so tiles stay large.
  static const double margin = 12;

  /// Corner radius of a tile.
  static const double radius = PrismRadius.sm;

  static const BorderRadius tileRadius = BorderRadius.all(Radius.circular(radius));

  static const EdgeInsets padding = EdgeInsets.symmetric(horizontal: margin);

  /// Grid delegate for a wallpaper grid. [columns] defaults to [wallpaperGridColumns] for the screen width.
  static SliverGridDelegate delegate(BuildContext context, {int? columns, double? aspectRatio}) {
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: columns ?? wallpaperGridColumns(MediaQuery.sizeOf(context).width),
      mainAxisSpacing: spacing,
      crossAxisSpacing: spacing,
      childAspectRatio: aspectRatio ?? PrismFeedLayout.gridTileAspectRatio,
    );
  }
}

/// One wallpaper in a grid: rounded image, hairline outline, press feedback and a slot for a badge.
class PrismWallTile extends StatelessWidget {
  const PrismWallTile({
    super.key,
    required this.url,
    this.fallbackUrl,
    this.heroTag,
    this.onTap,
    this.onLongPress,
    this.semanticLabel = 'Wallpaper',
    this.overlay,
    this.borderRadius = PrismWallGrid.tileRadius,
    this.memCacheHeight,
  });

  final String url;

  /// Tried when [url] fails, for example the full wallpaper after a broken thumbnail.
  final String? fallbackUrl;
  final String? heroTag;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String semanticLabel;

  /// Drawn above the image, for example a premium badge or a selection tick. It fills the tile: position its
  /// content with [Align] or [Positioned].
  final Widget? overlay;
  final BorderRadius borderRadius;
  final int? memCacheHeight;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return PressScale(
      scale: 0.97,
      enabled: onTap != null,
      child: Semantics(
        button: onTap != null,
        image: true,
        label: semanticLabel,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          onLongPress: onLongPress,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              PrismImageTile(
                url: url,
                fallbackUrl: fallbackUrl,
                heroTag: heroTag,
                borderRadius: borderRadius,
                memCacheHeight: memCacheHeight,
              ),
              // A pure white or black hairline keeps dark images from melting into the page.
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: borderRadius,
                    border: Border.all(color: (dark ? Colors.white : Colors.black).withValues(alpha: 0.08)),
                  ),
                ),
              ),
              ?overlay,
            ],
          ),
        ),
      ),
    );
  }
}
