import 'dart:math' show max;

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/wall_remix/data/wall_remix_repository.dart';
import 'package:Prism/features/wall_remix/domain/wall_remix.dart';
import 'package:Prism/features/wall_remix/views/widgets/remix_credit_row.dart';
import 'package:Prism/features/wallpaper_detail/views/wallpaper_feed.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

/// The approved remixes of [original] by other creators, as a row of tiles that opens the detail screen and swipes
/// through them. It shows nothing while it loads, when there are none the viewer may open, or when the lookup fails.
class RemixesSection extends StatefulWidget {
  const RemixesSection({required this.original, this.repository, this.viewer, super.key});

  final PrismWallpaper original;
  final WallRemixRepository? repository;
  final WallViewer? viewer;

  @override
  State<RemixesSection> createState() => _RemixesSectionState();
}

class _RemixesSectionState extends State<RemixesSection> {
  static const double _tileWidth = 96;
  static const double _tileHeight = 160;

  List<PrismWallpaper> _visible = const <PrismWallpaper>[];
  bool _tracked = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final WallRemixRepository repository = widget.repository ?? getIt<WallRemixRepository>();
    try {
      final WallViewer viewer = widget.viewer ?? await currentWallViewer(repository);
      final String docId = widget.original.firestoreDocumentId?.trim() ?? '';
      final List<PrismWallpaper> rows = await repository.fetchRemixes(docId);
      if (!mounted) return;
      final List<PrismWallpaper> visible = visibleRemixes(rows, original: widget.original, viewer: viewer);
      setState(() => _visible = visible);
      if (visible.isNotEmpty && !_tracked) {
        _tracked = true;
        analytics.track(RemixesGridOpenedEvent(count: visible.length));
      }
    } catch (_) {
      if (mounted) setState(() => _visible = const <PrismWallpaper>[]);
    }
  }

  void _open(BuildContext context, int index) {
    final PrismWallpaper wall = _visible[index];
    context.router.push(
      WallpaperDetailRoute(
        entity: FeedItemEntity.prism(id: wall.id, wallpaper: wall),
        heroTag: prismHeroTag(this, index, wall.id),
        feed: WallpaperFeed(
          grid: context,
          tiles: [
            for (final (int i, PrismWallpaper item) in _visible.indexed)
              (
                item: FeedItemEntity.prism(id: item.id, wallpaper: item),
                index: i,
                heroTag: prismHeroTag(this, i, item.id),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_visible.isEmpty) return const SizedBox.shrink();
    final AppLocalizations l10n = context.l10n;
    final ColorScheme cs = Theme.of(context).colorScheme;
    final int total = max(widget.original.remixCount, _visible.length);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Semantics(header: true, child: Text(l10n.wallRemixesTitle, style: PrismTextStyles.rowTitle(context))),
            const SizedBox(width: 8),
            Text(
              l10n.wallRemixesCount(total),
              style: PrismTextStyles.caption(context).copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: _tileHeight + 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _visible.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (BuildContext context, int index) {
              final PrismWallpaper wall = _visible[index];
              final String creator = _nonBlank(wall.core.authorName) ?? l10n.wallRemixUnknownCreator;
              final String label = l10n.wallRemixOpenRemixLabel(creator);
              return Semantics(
                button: true,
                label: label,
                onTap: () => _open(context, index),
                excludeSemantics: true,
                child: Tooltip(
                  message: label,
                  child: PressScale(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _open(context, index),
                      child: SizedBox(
                        width: _tileWidth,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            SizedBox(
                              width: _tileWidth,
                              height: _tileHeight,
                              child: PrismImageTile(
                                url: wall.thumbnailUrl,
                                heroTag: prismHeroTag(this, index, wall.id),
                                borderRadius: BorderRadius.circular(PrismRadius.sm),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              creator,
                              style: PrismTextStyles.caption(context),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

String? _nonBlank(String? value) => value == null || value.trim().isEmpty ? null : value.trim();
