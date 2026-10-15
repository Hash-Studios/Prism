import 'dart:io';
import 'dart:ui' show lerpDouble;

import 'package:Prism/core/cache/prism_full_image_cache.dart';
import 'package:Prism/core/cache/prism_image_cache.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/wallpaper_detail/biz/wallpaper_detail_rules.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/accent_contrast.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// The full-bleed wallpaper: the thumbnail first, then the full image on top. A thin bar along the top edge shows
/// the full image's download progress. With a [tint] the whole image takes that hue, and a new tint slides over from
/// the one on screen. A [localFile] (opened from Downloads) is shown in place of the network image.
class DetailWallpaperImage extends StatelessWidget {
  const DetailWallpaperImage({
    super.key,
    required this.entity,
    required this.accent,
    required this.tint,
    required this.paletteLoading,
    this.localFile,
  });

  final FeedItemEntity entity;

  /// The palette accent. It only picks the colour of the failure mark.
  final Color? accent;

  /// The colour variation in use, or null while the original shows.
  final Color? tint;
  final bool paletteLoading;
  final File? localFile;

  Widget _progress(DownloadProgress progress) {
    final double? value = progress.progress;
    if (value == null) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.topCenter,
      child: LinearProgressIndicator(
        value: value,
        minHeight: 2,
        color: Colors.white,
        backgroundColor: Colors.transparent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final String thumb = entity.thumbnailUrl.trim();
    final String full = entity.fullUrl.trim();
    final int cacheWidth = previewCacheWidth(MediaQuery.sizeOf(context).width, MediaQuery.devicePixelRatioOf(context));
    final bool useProgressive = thumb.isNotEmpty && full.isNotEmpty && full != thumb;
    final Color markColor = paletteLoading || accent == null ? cs.onSurface : onColor(accent!);
    final Widget failed = Center(child: Icon(Icons.broken_image_rounded, color: markColor));
    Widget fullImage(String url) => CachedNetworkImage(
      cacheManager: PrismFullImageCache.instance,
      imageUrl: url,
      memCacheWidth: cacheWidth,
      fit: BoxFit.cover,
      fadeInDuration: context.motion(useProgressive ? PrismDurations.base : PrismDurations.fast),
      fadeOutDuration: useProgressive ? Duration.zero : context.motion(PrismDurations.fast),
      imageBuilder: (context, imageProvider) => SizedBox.expand(
        child: Image(image: imageProvider, fit: BoxFit.cover),
      ),
      progressIndicatorBuilder: (context, url, downloadProgress) => _progress(downloadProgress),
      errorWidget: (context, url, error) => useProgressive ? const SizedBox.shrink() : failed,
    );

    Widget imageLayer;
    final File? file = localFile;
    if (file != null) {
      imageLayer = Image.file(
        file,
        fit: BoxFit.cover,
        cacheWidth: cacheWidth,
        errorBuilder: (_, _, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.broken_image_rounded, color: markColor),
              const SizedBox(height: PrismSpace.xs),
              Text('Downloaded wallpaper is unavailable', style: PrismTextStyles.body(context)),
            ],
          ),
        ),
      );
    } else if (useProgressive) {
      imageLayer = Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            cacheManager: PrismImageCache.instance,
            imageUrl: thumb,
            memCacheWidth: cacheWidth,
            fadeInDuration: context.motion(PrismDurations.fast),
            fadeOutDuration: context.motion(PrismDurations.fast),
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            placeholder: (context, url) => ColoredBox(color: cs.surfaceContainerHigh),
            errorWidget: (context, url, error) => failed,
          ),
          fullImage(full),
        ],
      );
    } else {
      final String url = full.isNotEmpty ? full : thumb;
      imageLayer = url.isEmpty ? failed : fullImage(url);
    }

    return SizedBox.expand(
      child: HueTint(tint: tint, duration: context.motion(const Duration(milliseconds: 220)), child: imageLayer),
    );
  }
}

/// The tint [t] of the way from [a] to [b]. Colours blend in HSL space and the hue takes the short way round. A blend in
/// RGB passes through grey between opposite hues, and a grey tint takes the colour out of the wallpaper. With no tint
/// at one end, the other fades in or out.
@visibleForTesting
Color? lerpHueTint(Color? a, Color? b, double t) {
  if (a == null || b == null) return Color.lerp(a, b, t);
  final HSLColor from = HSLColor.fromColor(a);
  final HSLColor to = HSLColor.fromColor(b);
  final double sweep = ((to.hue - from.hue + 540) % 360) - 180;
  return HSLColor.fromAHSL(
    lerpDouble(from.alpha, to.alpha, t)!,
    (from.hue + sweep * t) % 360,
    lerpDouble(from.saturation, to.saturation, t)!,
    lerpDouble(from.lightness, to.lightness, t)!,
  ).toColor();
}

class _HueTintTween extends Tween<Color?> {
  _HueTintTween({super.begin, super.end});

  @override
  Color? lerp(double t) => lerpHueTint(begin, end, t);
}

/// Shows [child] with the hue of [tint]. A new tint slides over from the one on screen, and no tint fades the hue out.
class HueTint extends StatefulWidget {
  const HueTint({super.key, required this.tint, required this.duration, required this.child});

  final Color? tint;
  final Duration duration;
  final Widget child;

  @override
  State<HueTint> createState() => _HueTintState();
}

class _HueTintState extends State<HueTint> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: widget.duration)..value = 1;
  late _HueTintTween _tween = _HueTintTween(begin: widget.tint, end: widget.tint);

  Color? get _shown => _tween.transform(Curves.easeOutCubic.transform(_controller.value));

  @override
  void didUpdateWidget(HueTint oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tint == widget.tint) return;
    _tween = _HueTintTween(begin: _shown, end: widget.tint);
    _controller
      ..duration = widget.duration
      ..forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: RepaintBoundary(child: widget.child),
      builder: (BuildContext context, Widget? child) {
        final Color? tint = _shown;
        return tint == null ? child! : ColorFiltered(colorFilter: ColorFilter.mode(tint, BlendMode.hue), child: child);
      },
    );
  }
}
