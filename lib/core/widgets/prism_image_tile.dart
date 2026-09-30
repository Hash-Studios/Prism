import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/widgets/pulse_placeholder.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Hero tag for a wallpaper tile. It is unique per grid ([scope]), position and wallpaper, so the same wallpaper
/// shown twice never shares a tag.
String prismHeroTag(Object scope, int index, String id) => 'wall-${identityHashCode(scope)}-$index-$id';

/// A grid image that fades in over the [PulseFill] skeleton. Fills its parent.
class PrismImageTile extends StatelessWidget {
  const PrismImageTile({super.key, required this.url, this.heroTag, this.borderRadius});

  final String url;
  final String? heroTag;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    Widget tile = url.trim().isEmpty
        ? PulseFill(borderRadius: borderRadius)
        : CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            fadeInDuration: context.motion(const Duration(milliseconds: 180)),
            fadeInCurve: Curves.easeOut,
            fadeOutDuration: context.motion(const Duration(milliseconds: 180)),
            placeholder: (_, _) => PulseFill(borderRadius: borderRadius),
            errorWidget: (_, _, _) => PulseFill(borderRadius: borderRadius),
          );
    tile = SizedBox.expand(child: tile);
    if (borderRadius != null) tile = ClipRRect(borderRadius: borderRadius!, child: tile);
    return heroTag == null || context.reduceMotion ? tile : Hero(tag: heroTag!, child: tile);
  }
}
