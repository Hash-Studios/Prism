import 'package:Prism/core/cache/prism_image_cache.dart';
import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/widgets/pulse_placeholder.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// A favourite grid image. It tries the thumbnail, then the full image. When both fail it shows "Unavailable"
/// and calls [onUnavailable], so the grid can offer a one-tap remove.
class FavouriteTileImage extends StatelessWidget {
  const FavouriteTileImage({
    super.key,
    required this.thumbnailUrl,
    required this.fullUrl,
    required this.onUnavailable,
    this.heroTag,
  });

  final String thumbnailUrl;
  final String fullUrl;
  final VoidCallback onUnavailable;
  final String? heroTag;

  Widget _image(BuildContext context, String url, {String? fallback}) => CachedNetworkImage(
    key: ValueKey<String>(url),
    imageUrl: url,
    cacheManager: PrismImageCache.instance,
    fit: BoxFit.cover,
    fadeInDuration: context.motion(const Duration(milliseconds: 180)),
    fadeInCurve: Curves.easeOut,
    fadeOutDuration: context.motion(const Duration(milliseconds: 180)),
    placeholder: (_, _) => const PulseFill(),
    errorWidget: (context, _, _) =>
        fallback != null && fallback.isNotEmpty && fallback != url ? _image(context, fallback) : _unavailable(context),
  );

  Widget _unavailable(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) => onUnavailable());
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(JamIcons.picture, color: theme.hintColor, size: 24),
            const SizedBox(height: 4),
            Text('Unavailable', style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String primary = thumbnailUrl.trim().isNotEmpty ? thumbnailUrl : fullUrl;
    Widget tile = SizedBox.expand(
      child: primary.trim().isEmpty ? _unavailable(context) : _image(context, primary, fallback: fullUrl),
    );
    if (heroTag != null && !context.reduceMotion) tile = Hero(tag: heroTag!, child: tile);
    return tile;
  }
}
