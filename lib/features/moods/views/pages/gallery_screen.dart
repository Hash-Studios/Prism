import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/glint/glint_state.dart';
import 'package:Prism/core/widgets/home/wallpapers/loading.dart';
import 'package:Prism/core/widgets/prism/prism_page.dart';
import 'package:Prism/features/moods/domain/repositories/mood_repository.dart';
import 'package:Prism/features/moods/views/widgets/wall_ids_grid.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

/// The comma-separated wall ids of a gallery link, trimmed and without repeats.
List<String> galleryWallIds(String raw) =>
    raw.split(',').map((id) => id.trim()).where((id) => id.isNotEmpty).toSet().toList(growable: false);

/// The exact walls of a gallery push, in the order the push sent them.
@RoutePage()
class GalleryScreen extends StatefulWidget {
  const GalleryScreen({
    super.key,
    @QueryParam('ids') this.ids = '',
    @QueryParam('title') this.title = '',
    @QueryParam('source') this.source = 'link',
  });

  /// Comma-separated wall ids.
  final String ids;

  /// The page title, for example the push title. The default title is used when it is empty.
  final String title;

  /// Where the user opened the page, for example 'push' or 'link'. For analytics.
  final String source;

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  Future<List<PrismWallpaper>>? _walls;

  @override
  void initState() {
    super.initState();
    _load();
    final int count = galleryWallIds(widget.ids).length;
    unawaited(analytics.track(GalleryOpenedEvent(source: widget.source, wallCount: count)));
  }

  void _load() {
    setState(() {
      _walls = getIt<MoodRepository>().fetchMoodWalls(galleryWallIds(widget.ids), keepOrder: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final String title = widget.title.trim();
    return PrismPage(
      title: title.isEmpty ? l10n.galleryScreenTitle : title,
      body: FutureBuilder<List<PrismWallpaper>>(
        future: _walls,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return GlintState(
              kind: GlintStateKind.error,
              title: l10n.moodLoadError,
              body: l10n.wallpaperCheckConnection,
              actionLabel: l10n.wallpaperTryAgain,
              onAction: _load,
            );
          }
          final List<PrismWallpaper>? walls = snapshot.data;
          if (walls == null) return const LoadingCards(useFeedLayout: true);
          if (walls.isEmpty) {
            return GlintState(kind: GlintStateKind.empty, title: l10n.galleryEmptyTitle, body: l10n.galleryEmptyBody);
          }
          return WallIdsGrid(walls: walls);
        },
      ),
    );
  }
}
