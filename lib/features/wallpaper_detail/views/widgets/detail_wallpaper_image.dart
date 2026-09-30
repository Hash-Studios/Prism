import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/accent_contrast.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// The full-bleed wallpaper: the thumbnail first, then the full image on top. A thin bar along the top edge shows
/// the full image's download progress. With a [tinted] accent the whole image takes that hue.
class DetailWallpaperImage extends StatelessWidget {
  const DetailWallpaperImage({
    super.key,
    required this.entity,
    required this.accent,
    required this.tinted,
    required this.paletteLoading,
  });

  final FeedItemEntity entity;
  final Color? accent;
  final bool tinted;
  final bool paletteLoading;

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
    final bool useProgressive = thumb.isNotEmpty && full.isNotEmpty && full != thumb;
    final Color markColor = paletteLoading || accent == null ? cs.onSurface : onColor(accent!);
    final Widget failed = Center(child: Icon(Icons.broken_image_rounded, color: markColor));
    Widget fullImage(String url) => CachedNetworkImage(
      imageUrl: url,
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
    if (useProgressive) {
      imageLayer = Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: thumb,
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

    if (tinted && accent != null) {
      imageLayer = ColorFiltered(colorFilter: ColorFilter.mode(accent!, BlendMode.hue), child: imageLayer);
    }
    return SizedBox.expand(child: imageLayer);
  }
}
