import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// A network image decoded at the size it is shown, so a large generation does not sit in memory at full size.
class AiDecodedImage extends StatelessWidget {
  const AiDecodedImage({
    super.key,
    required this.url,
    required this.logicalWidth,
    required this.logicalHeight,
    this.filterQuality = FilterQuality.medium,
  });

  final String url;
  final double logicalWidth;
  final double logicalHeight;
  final FilterQuality filterQuality;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final double dpr = MediaQuery.devicePixelRatioOf(context);
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      memCacheWidth: (logicalWidth * dpr).round().clamp(32, 4096),
      memCacheHeight: (logicalHeight * dpr).round().clamp(32, 4096),
      filterQuality: filterQuality,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      errorWidget: (_, _, _) => ColoredBox(
        color: cs.surfaceContainerHighest,
        child: Center(child: Icon(Icons.broken_image_rounded, color: cs.onSurface.withValues(alpha: 0.3))),
      ),
    );
  }
}
