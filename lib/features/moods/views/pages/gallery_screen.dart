import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/widgets/glint/glint_state.dart';
import 'package:Prism/core/widgets/home/wallpapers/loading.dart';
import 'package:Prism/core/widgets/prism/prism_page.dart';
import 'package:Prism/features/moods/biz/gallery_walls_cubit.dart';
import 'package:Prism/features/moods/domain/repositories/mood_repository.dart';
import 'package:Prism/features/moods/views/widgets/wall_ids_grid.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The comma-separated wall ids of a gallery link, trimmed and without repeats.
List<String> galleryWallIds(String raw) =>
    raw.split(',').map((id) => id.trim()).where((id) => id.isNotEmpty).toSet().toList(growable: false);

/// The exact walls of a gallery push, in the order the push sent them.
@RoutePage()
class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key, @QueryParam('ids') this.ids = '', @QueryParam('source') this.source = 'link'});

  /// Comma-separated wall ids.
  final String ids;

  /// Where the user opened the page, for example 'push' or 'link'. For analytics.
  final String source;

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  late final GalleryWallsCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = GalleryWallsCubit(getIt<MoodRepository>())..load(galleryWallIds(widget.ids));
    _trackOpened();
  }

  @override
  void didUpdateWidget(GalleryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ids != widget.ids) unawaited(_cubit.load(galleryWallIds(widget.ids)));
    if (oldWidget.ids != widget.ids || oldWidget.source != widget.source) _trackOpened();
  }

  @override
  void dispose() {
    unawaited(_cubit.close());
    super.dispose();
  }

  void _trackOpened() {
    unawaited(analytics.track(GalleryOpenedEvent(source: widget.source, wallCount: galleryWallIds(widget.ids).length)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PrismPage(
      title: l10n.galleryScreenTitle,
      body: BlocBuilder<GalleryWallsCubit, GalleryWallsState>(
        bloc: _cubit,
        builder: (_, state) {
          return switch (state) {
            GalleryWallsLoading() => const LoadingCards(useFeedLayout: true),
            GalleryWallsFailed() => GlintState(
              kind: GlintStateKind.error,
              title: l10n.moodLoadError,
              body: l10n.wallpaperCheckConnection,
              actionLabel: l10n.wallpaperTryAgain,
              onAction: () => unawaited(_cubit.load(galleryWallIds(widget.ids))),
            ),
            GalleryWallsLoaded(:final walls) when walls.isEmpty => GlintState(
              kind: GlintStateKind.empty,
              title: l10n.galleryEmptyTitle,
              body: l10n.galleryEmptyBody,
            ),
            GalleryWallsLoaded(:final walls) => WallIdsGrid(walls: walls),
          };
        },
      ),
    );
  }
}
