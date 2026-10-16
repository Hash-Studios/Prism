import 'dart:async';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/trending/biz/bloc/trending_bloc.j.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Loads the trending list for [TrendingStrip]. It has no error UI: when the list is empty or fails, nothing shows.
/// Give it a `GlobalKey<TrendingStripSectionState>` to reload the list from outside, for example on pull to refresh.
class TrendingStripSection extends StatefulWidget {
  const TrendingStripSection({super.key});

  @override
  State<TrendingStripSection> createState() => TrendingStripSectionState();
}

class TrendingStripSectionState extends State<TrendingStripSection> {
  late final TrendingBloc _bloc = getIt<TrendingBloc>()..add(const TrendingEvent.started());

  void refresh() => _bloc.add(const TrendingEvent.refreshRequested());

  @override
  void dispose() {
    unawaited(_bloc.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocProvider<TrendingBloc>.value(value: _bloc, child: const TrendingStrip());
}

/// "Trending this week" on the home feed: a row of the top Prism wallpapers, with "See all".
class TrendingStrip extends StatelessWidget {
  const TrendingStrip({super.key});

  static const int maxItems = 12;
  static const double _tileWidth = 104;
  static const double _tileHeight = 184;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TrendingBloc, TrendingState>(
      buildWhen: (previous, current) => previous.week.walls != current.week.walls,
      builder: (context, state) {
        final List<PrismWallpaper> walls = state.week.walls.take(maxItems).toList(growable: false);
        if (walls.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            PrismSectionHeader(
              title: 'Trending this week',
              actionLabel: 'See all',
              onAction: () {
                PrismHaptics.tap();
                unawaited(context.router.push(const TrendingRoute()));
              },
              padding: const EdgeInsetsDirectional.fromSTEB(
                PrismWallGrid.margin + 4,
                PrismSpace.lg,
                PrismWallGrid.margin - 4,
                PrismSpace.xs,
              ),
            ),
            SizedBox(
              height: _tileHeight,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: PrismWallGrid.padding,
                itemCount: walls.length,
                separatorBuilder: (_, _) => const SizedBox(width: PrismWallGrid.spacing),
                itemBuilder: (context, index) => _StripTile(wall: walls[index], index: index),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StripTile extends StatelessWidget {
  const _StripTile({required this.wall, required this.index});

  final PrismWallpaper wall;
  final int index;

  @override
  Widget build(BuildContext context) {
    final String heroTag = prismHeroTag(Scrollable.maybeOf(context) ?? context, index, wall.id);
    final int decodeHeight = (TrendingStrip._tileHeight * MediaQuery.devicePixelRatioOf(context)).round();
    return SizedBox(
      width: TrendingStrip._tileWidth,
      child: PrismWallTile(
        url: wall.thumbnailUrl,
        fallbackUrl: wall.fullUrl,
        memCacheHeight: decodeHeight,
        heroTag: heroTag,
        semanticLabel: wallpaperSemanticLabel(wall.core.authorName),
        onTap: () {
          PrismHaptics.tap();
          unawaited(
            context.router.push(
              WallpaperDetailRoute(
                entity: PrismFeedItem(id: wall.id, wallpaper: wall),
                heroTag: heroTag,
              ),
            ),
          );
        },
      ),
    );
  }
}
