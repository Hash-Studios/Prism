import 'dart:async';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/prism_image_tile.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/trending/biz/bloc/trending_bloc.j.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Loads the trending list for [TrendingStrip]. It has no error UI: when the list is empty or fails, nothing shows.
class TrendingStripSection extends StatelessWidget {
  const TrendingStripSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<TrendingBloc>(
      create: (_) => getIt<TrendingBloc>()..add(const TrendingEvent.started()),
      child: const TrendingStrip(),
    );
  }
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
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 16, end: 4),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Trending this week',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PrismTextStyles.editorialTitle(context),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      PrismHaptics.tap();
                      unawaited(context.router.push(const TrendingRoute()));
                    },
                    child: const Text('See all'),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: _tileHeight,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: walls.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) => _StripTile(wall: walls[index], index: index),
              ),
            ),
            const SizedBox(height: 8),
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
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String heroTag = prismHeroTag(Scrollable.maybeOf(context) ?? context, index, wall.id);
    final int decodeHeight = (TrendingStrip._tileHeight * MediaQuery.devicePixelRatioOf(context)).round();
    return Semantics(
      button: true,
      label: wallpaperSemanticLabel(wall.core.authorName),
      excludeSemantics: true,
      child: SizedBox(
        width: TrendingStrip._tileWidth,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            PrismImageTile(
              url: wall.thumbnailUrl,
              fallbackUrl: wall.fullUrl,
              memCacheHeight: decodeHeight,
              heroTag: heroTag,
              borderRadius: BorderRadius.circular(12),
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                splashColor: scheme.secondary.withValues(alpha: 0.3),
                highlightColor: scheme.secondary.withValues(alpha: 0.1),
                enableFeedback: false,
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
            ),
          ],
        ),
      ),
    );
  }
}
