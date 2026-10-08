import 'package:Prism/core/cache/prism_image_cache.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/widgets/pulse_placeholder.dart';
import 'package:Prism/logger/logger.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Hero tag for a wallpaper tile. It is unique per grid ([scope]), position and wallpaper, so the same wallpaper
/// shown twice never shares a tag.
String prismHeroTag(Object scope, int index, String id) => 'wall-${identityHashCode(scope)}-$index-$id';

/// Decode height, in physical pixels, for a grid tile that spans one of [crossAxisCount] equal columns of the screen
/// and has the given [aspectRatio] (width / height).
int gridTileDecodeHeight(BuildContext context, {required int crossAxisCount, double aspectRatio = 0.5}) {
  final double tileWidth = MediaQuery.sizeOf(context).width / crossAxisCount;
  return (tileWidth / aspectRatio * MediaQuery.devicePixelRatioOf(context)).round();
}

/// A grid image that fades in over the [PulseFill] skeleton. Fills its parent.
class PrismImageTile extends StatefulWidget {
  const PrismImageTile({
    super.key,
    required this.url,
    this.fallbackUrl,
    this.memCacheHeight,
    this.memCacheWidth,
    this.heroTag,
    this.borderRadius,
  });

  final String url;

  /// Tries the full wallpaper after a thumbnail failure, then offers retry if both fail.
  final String? fallbackUrl;
  final int? memCacheHeight;
  final int? memCacheWidth;
  final String? heroTag;
  final BorderRadius? borderRadius;

  @override
  State<PrismImageTile> createState() => _PrismImageTileState();
}

class _PrismImageTileState extends State<PrismImageTile> {
  int _attempt = 0;
  bool _retrying = false;

  Future<void> _retry() async {
    PrismHaptics.tap();
    setState(() => _retrying = true);
    try {
      for (final url in {widget.url, widget.fallbackUrl}.whereType<String>().where((url) => url.isNotEmpty)) {
        await CachedNetworkImage.evictFromCache(url, cacheManager: PrismImageCache.instance);
      }
    } catch (error, stackTrace) {
      logger.w('Could not clear the wallpaper image cache for retry', error: error, stackTrace: stackTrace);
    } finally {
      if (mounted) {
        setState(() {
          _retrying = false;
          _attempt++;
        });
      }
    }
  }

  Widget _image(BuildContext context, String url, {String? fallback}) => CachedNetworkImage(
    key: ValueKey((url, _attempt)),
    imageUrl: url,
    cacheManager: PrismImageCache.instance,
    fit: BoxFit.cover,
    fadeInDuration: context.motion(const Duration(milliseconds: 180)),
    fadeInCurve: Curves.easeOut,
    fadeOutDuration: context.motion(const Duration(milliseconds: 180)),
    memCacheHeight: widget.memCacheHeight,
    memCacheWidth: widget.memCacheWidth,
    placeholder: (_, _) => PulseFill(borderRadius: widget.borderRadius),
    errorWidget: (context, _, _) => fallback != null && fallback.isNotEmpty && fallback != url
        ? _image(context, fallback)
        : ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Align(
              alignment: AlignmentDirectional.bottomEnd,
              child: IconButton(
                tooltip: 'Retry image',
                onPressed: _retrying ? null : _retry,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ),
          ),
  );

  @override
  Widget build(BuildContext context) {
    final url = widget.url.trim().isNotEmpty ? widget.url : widget.fallbackUrl ?? '';
    Widget tile = url.trim().isEmpty
        ? PulseFill(borderRadius: widget.borderRadius)
        : _image(context, url, fallback: widget.fallbackUrl);
    tile = SizedBox.expand(child: tile);
    if (widget.borderRadius != null) tile = ClipRRect(borderRadius: widget.borderRadius!, child: tile);
    return widget.heroTag == null || context.reduceMotion ? tile : Hero(tag: widget.heroTag!, child: tile);
  }
}
