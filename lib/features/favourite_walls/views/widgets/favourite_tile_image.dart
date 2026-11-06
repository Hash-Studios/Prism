import 'dart:async';
import 'dart:io';

import 'package:Prism/core/cache/prism_full_image_cache.dart';
import 'package:Prism/core/cache/prism_image_cache.dart';
import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/router/wallpaper_detail_route.dart';
import 'package:Prism/core/utils/url_utils.dart';
import 'package:Prism/core/widgets/pulse_placeholder.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// A favourite's picture. Some thumbnails are small (a Wallhaven thumbnail is about 300 pixels tall), so when the full
/// picture is already on the device, from the detail screen, the tile shows it at its own size. It never downloads one.
class FavouriteTileImage extends StatefulWidget {
  const FavouriteTileImage({
    super.key,
    required this.thumbnailUrl,
    required this.fullUrl,
    required this.onUnavailable,
    this.allowFullUrlFallback = false,
    this.heroTag,
    this.cachedFullUrl = '',
  });

  final String thumbnailUrl;
  final String fullUrl;
  final VoidCallback onUnavailable;
  final bool allowFullUrlFallback;
  final String? heroTag;

  /// The link the detail screen caches the full picture under (`WallpaperDisplaySource.full`). Empty skips the lookup.
  final String cachedFullUrl;

  @override
  State<FavouriteTileImage> createState() => _FavouriteTileImageState();
}

class _FavouriteTileImageState extends State<FavouriteTileImage> {
  File? _cachedFull;
  bool _checkingFull = false;

  @override
  void initState() {
    super.initState();
    unawaited(_lookUp());
  }

  @override
  void didUpdateWidget(FavouriteTileImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cachedFullUrl == widget.cachedFullUrl) return;
    _cachedFull = null;
    unawaited(_lookUp());
  }

  Future<void> _lookUp() async {
    final String url = widget.cachedFullUrl;
    _checkingFull = isValidNetworkUrl(url);
    if (!_checkingFull) return;
    File? file;
    try {
      file = (await PrismFullImageCache.instance.getFileFromCache(url))?.file;
    } catch (_) {
      file = null;
    }
    if (!mounted || url != widget.cachedFullUrl) return;
    setState(() {
      _cachedFull = file;
      _checkingFull = false;
    });
  }

  Widget _image(BuildContext context, String url, {String? fallback}) => CachedNetworkImage(
    key: ValueKey<String>(url),
    imageUrl: url,
    cacheManager: PrismImageCache.instance,
    fit: BoxFit.cover,
    fadeInDuration: context.motion(PrismDurations.fast),
    fadeInCurve: PrismCurves.enter,
    fadeOutDuration: context.motion(PrismDurations.fast),
    placeholder: (_, _) => const PulseFill(),
    errorWidget: (context, _, _) =>
        fallback != null && fallback.isNotEmpty && fallback != url ? _image(context, fallback) : _unavailable(context),
  );

  Widget _unavailable(BuildContext context) {
    if (_checkingFull) return const PulseFill();
    final ThemeData theme = Theme.of(context);
    final FavouriteTileImage current = widget;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && identical(widget, current) && !_checkingFull) current.onUnavailable();
    });
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(JamIcons.picture, color: theme.hintColor, size: 24),
            const SizedBox(height: 4),
            Text(context.l10n.wallpaperUnavailable, style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String? fallback = widget.allowFullUrlFallback ? widget.fullUrl : null;
    final String primary = widget.thumbnailUrl.trim().isNotEmpty ? widget.thumbnailUrl : fallback ?? '';
    // Built only when shown: the unavailable state reports itself.
    Widget thumb() => primary.trim().isEmpty ? _unavailable(context) : _image(context, primary, fallback: fallback);
    final File? full = _cachedFull;
    Widget tile = SizedBox.expand(
      child: full == null
          ? thumb()
          : LayoutBuilder(
              // Decoded to the tile's height in pixels, like the feed grid, so a large original costs no more memory.
              builder: (context, constraints) => Image.file(
                full,
                fit: BoxFit.cover,
                cacheHeight: constraints.hasBoundedHeight
                    ? (constraints.maxHeight * MediaQuery.devicePixelRatioOf(context)).round().clamp(1, 4096)
                    : null,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => thumb(),
              ),
            ),
    );
    if (widget.heroTag != null && !context.reduceMotion) {
      tile = Hero(tag: widget.heroTag!, createRectTween: wallpaperHeroRectTween, child: tile);
    }
    return tile;
  }
}
