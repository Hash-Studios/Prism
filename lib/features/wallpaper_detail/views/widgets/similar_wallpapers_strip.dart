import 'package:Prism/core/cache/prism_image_cache.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// "More like this" strip. It stays hidden while loading and when nothing similar exists.
class SimilarWallpapersStrip extends StatefulWidget {
  const SimilarWallpapersStrip({required this.entity, required this.loader, required this.onOpen, super.key});

  final FeedItemEntity entity;
  final Future<List<FeedItemEntity>> Function(FeedItemEntity entity) loader;
  final ValueChanged<FeedItemEntity> onOpen;

  @override
  State<SimilarWallpapersStrip> createState() => _SimilarWallpapersStripState();
}

class _SimilarWallpapersStripState extends State<SimilarWallpapersStrip> {
  static const double _tileWidth = 92;
  static const double _tileHeight = 150;

  late Future<List<FeedItemEntity>> _future = _load();

  Future<List<FeedItemEntity>> _load() async {
    try {
      return await widget.loader(widget.entity);
    } catch (_) {
      return const <FeedItemEntity>[];
    }
  }

  @override
  void didUpdateWidget(SimilarWallpapersStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entity != widget.entity) {
      _future = _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<FeedItemEntity>>(
      future: _future,
      builder: (context, snapshot) {
        final List<FeedItemEntity> items = snapshot.data ?? const <FeedItemEntity>[];
        if (items.isEmpty) return const SizedBox.shrink();
        final ThemeData theme = Theme.of(context);
        final double dpr = MediaQuery.devicePixelRatioOf(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('More like this', style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.secondary)),
            const SizedBox(height: 8),
            SizedBox(
              height: _tileHeight,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final FeedItemEntity item = items[index];
                  return Semantics(
                    button: true,
                    label: item.semanticLabel,
                    child: SizedBox(
                      key: ValueKey<String>(item.id),
                      width: _tileWidth,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          fit: StackFit.expand,
                          children: <Widget>[
                            CachedNetworkImage(
                              imageUrl: item.thumbnailUrl,
                              cacheManager: PrismImageCache.instance,
                              fit: BoxFit.cover,
                              memCacheWidth: (_tileWidth * dpr).round(),
                              placeholder: (_, _) =>
                                  ColoredBox(color: theme.colorScheme.secondary.withValues(alpha: 0.1)),
                              errorWidget: (_, _, _) =>
                                  ColoredBox(color: theme.colorScheme.secondary.withValues(alpha: 0.1)),
                            ),
                            Material(
                              color: Colors.transparent,
                              child: InkWell(onTap: () => widget.onOpen(item)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
