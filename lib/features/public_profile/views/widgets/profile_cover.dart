import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/widgets/glint/cover_mosaic.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// The cover art of a profile: a picked [file], the user's image at [url], or, with no custom cover, soft wallpaper
/// art. It fills its parent.
///
/// The soft art is a heavily blurred, slightly darkened wallpaper: [artUrl] (a wallpaper the page has already loaded,
/// such as the latest upload), else a bundled cover chosen by [seed] (the user id), so a profile always opens on the
/// same art.
class ProfileCover extends StatelessWidget {
  const ProfileCover({super.key, this.url, this.file, this.seed = '', this.artUrl});

  final String? url;
  final File? file;
  final String seed;
  final String? artUrl;

  /// True when [url] points at a real image, so a custom cover can be shown or removed.
  static bool hasCover(String? url) => Uri.tryParse(url?.trim() ?? '')?.hasAuthority ?? false;

  /// The bundled cover for [seed]. `String.hashCode` is not stable across runs, so this hashes the code units.
  @visibleForTesting
  static String fallbackAsset(String seed) {
    int hash = 0;
    for (final int unit in seed.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return kCoverMosaicAssets[hash % kCoverMosaicAssets.length];
  }

  @override
  Widget build(BuildContext context) {
    if (file != null) return Image.file(file!, fit: BoxFit.cover, width: double.infinity, height: double.infinity);
    final ColorScheme cs = Theme.of(context).colorScheme;
    // Blurred, so a small decode is enough.
    final Widget bundled = Image.asset(
      fallbackAsset(seed),
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      cacheWidth: 240,
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => ColoredBox(color: cs.surfaceContainerHigh),
    );
    final Widget art = ExcludeSemantics(
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 28, sigmaY: 28, tileMode: TileMode.clamp),
            child: hasCover(artUrl)
                ? CachedNetworkImage(
                    imageUrl: artUrl!.trim(),
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    memCacheWidth: 240,
                    fadeInDuration: context.motion(PrismDurations.fast),
                    placeholder: (_, _) => bundled,
                    errorWidget: (_, _, _) => bundled,
                  )
                : bundled,
          ),
          ColoredBox(color: cs.scrim.withValues(alpha: 0.16)),
        ],
      ),
    );
    if (!hasCover(url)) return art;
    return CachedNetworkImage(
      imageUrl: url!.trim(),
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      fadeInDuration: context.motion(PrismDurations.fast),
      placeholder: (_, _) => art,
      errorWidget: (_, _, _) => art,
    );
  }
}
