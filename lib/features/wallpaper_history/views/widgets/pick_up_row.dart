import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/session/data/app_session_tracker.dart';
import 'package:Prism/features/wallpaper_history/data/history_wall_stores.dart';
import 'package:Prism/features/wallpaper_history/data/wallpaper_history_store.dart';
import 'package:Prism/features/wallpaper_history/domain/entities/history_wall.dart';
import 'package:Prism/features/wallpaper_history/domain/recently_viewed_rules.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

/// The pick-up walls for this session, read once when Home opens. A wall the user saved, set or downloaded is left
/// out, so are walls viewed in this session.
List<HistoryWall> pickUpWallsForSession({DateTime? now}) {
  if (!getIt.isRegistered<RecentlyViewedStore>() || !getIt.isRegistered<SyncedHistoryStore>()) {
    return const <HistoryWall>[];
  }
  final Set<String> used = <String>{
    ...getIt<SyncedHistoryStore>().items().map((wall) => wall.key),
    if (getIt.isRegistered<WallpaperHistoryStore>())
      ...appliedHistoryForSync(getIt<WallpaperHistoryStore>()).map((wall) => wall.key),
  };
  final FavoritesLocalDataSource? favourites = getIt.isRegistered<FavoritesLocalDataSource>()
      ? getIt<FavoritesLocalDataSource>()
      : null;
  final String userId = app_state.prismUser.id;
  return pickUpWalls(
    viewedNewestFirst: getIt<RecentlyViewedStore>().items(),
    sessionStart: now ?? DateTime.now(),
    returningSession: AppSessionTracker.instance.sessionNumber > 1,
    kept: (wall) => used.contains(wall.key) || (favourites?.isWallFavourite(userId, wall.id) ?? false),
  );
}

/// "Pick up where you left off" on Home: walls the user opened before and did not keep. Nothing when [walls] is empty.
class PickUpRow extends StatefulWidget {
  const PickUpRow({super.key, required this.walls});

  final List<HistoryWall> walls;

  @override
  State<PickUpRow> createState() => _PickUpRowState();
}

class _PickUpRowState extends State<PickUpRow> {
  static const double _visibleCards = 3.4;

  @override
  void initState() {
    super.initState();
    if (widget.walls.isNotEmpty) unawaited(analytics.track(PickUpRowSeenEvent(count: widget.walls.length)));
  }

  void _open(int index) {
    final HistoryWall wall = widget.walls[index];
    PrismHaptics.tap();
    unawaited(analytics.track(PickUpTileOpenedEvent(provider: wall.source.wireValue, position: index)));
    unawaited(
      context.router.push(WallpaperDetailRoute(wallId: wall.id, source: wall.source, thumbnailUrl: wall.thumbnailUrl)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<HistoryWall> walls = widget.walls;
    if (walls.isEmpty) return const SizedBox.shrink();
    final AppLocalizations l10n = context.l10n;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final double cardWidth = (MediaQuery.sizeOf(context).width - PrismFeedLayout.gridSpacing * 3) / _visibleCards;
    final double cardHeight = cardWidth / PrismFeedLayout.gridTileAspectRatio;
    final int decodeWidth = (cardWidth * MediaQuery.devicePixelRatioOf(context)).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            PrismFeedLayout.gridSpacing + 4,
            PrismSpace.md,
            PrismFeedLayout.gridSpacing + 4,
            PrismSpace.sm,
          ),
          child: Semantics(
            header: true,
            child: Text(
              l10n.pickUpTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: PrismTextStyles.sectionTitle(context),
            ),
          ),
        ),
        SizedBox(
          height: cardHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: PrismFeedLayout.gridPadding,
            itemCount: walls.length,
            separatorBuilder: (_, _) => const SizedBox(width: PrismFeedLayout.gridSpacing),
            itemBuilder: (context, index) => SizedBox(
              key: ValueKey<String>('pick-up-${walls[index].key}'),
              width: cardWidth,
              child: Semantics(
                button: true,
                image: true,
                label: l10n.pickUpTileLabel(index + 1, walls.length),
                child: PressScale(
                  scale: 0.97,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _open(index),
                    child: ClipRRect(
                      borderRadius: PrismWallGrid.tileRadius,
                      child: Stack(
                        fit: StackFit.expand,
                        children: <Widget>[
                          ColoredBox(color: scheme.surfaceContainerHigh),
                          PrismImageTile(url: walls[index].thumbnailUrl, memCacheWidth: decodeWidth),
                          IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: PrismWallGrid.tileRadius,
                                border: Border.all(color: scheme.onSurface.withValues(alpha: 0.08)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: PrismFeedLayout.gridSpacing),
      ],
    );
  }
}
