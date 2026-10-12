import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/animated/press_scale.dart';
import 'package:Prism/core/widgets/prism_glass.dart';
import 'package:Prism/core/widgets/prism_image_tile.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/wall_of_the_day/biz/bloc/wotd_bloc.j.dart';
import 'package:Prism/features/wall_of_the_day/domain/entities/wall_of_the_day_entity.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class WallOfTheDayCard extends StatefulWidget {
  const WallOfTheDayCard({super.key});

  @override
  State<WallOfTheDayCard> createState() => _WallOfTheDayCardState();
}

class _WallOfTheDayCardState extends State<WallOfTheDayCard> {
  // The home carousel rebuilds this card on every loop, so count one view per wall per app session.
  static final Set<String> _viewedWallIds = <String>{};

  void _fireImpression(WallOfTheDayEntity entity) {
    if (!_viewedWallIds.add(entity.wallId)) return;
    unawaited(analytics.track(WotdViewedEvent(wallId: entity.wallId)));
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WotdBloc, WotdState>(
      builder: (context, state) {
        final entity = state.entity;
        if (entity == null) return const SizedBox.shrink();
        _fireImpression(entity);
        return _WotdCardContent(entity: entity);
      },
    );
  }
}

class _WotdCardContent extends StatelessWidget {
  const _WotdCardContent({required this.entity});

  final WallOfTheDayEntity entity;

  void _openWallpaper(BuildContext context) {
    unawaited(analytics.track(WotdOpenedEvent(wallId: entity.wallId, source: 'card_tap')));
    final PrismWallpaper? wallpaper = entity.wallpaper;
    context.router.push(
      wallpaper != null
          ? WallpaperDetailRoute(
              entity: PrismFeedItem(id: wallpaper.id, wallpaper: wallpaper),
            )
          : WallpaperDetailRoute(
              wallId: entity.wallId,
              source: entity.source == WallpaperSource.unknown ? WallpaperSource.prism : entity.source,
              thumbnailUrl: entity.thumbnailUrl.isNotEmpty ? entity.thumbnailUrl : entity.url,
            ),
    );
  }

  void _openArchive(BuildContext context) {
    PrismHaptics.tap();
    context.router.push(const WotdArchiveRoute());
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: () {
          PrismHaptics.tap();
          _openWallpaper(context);
        },
        child: SizedBox.expand(
          child: Stack(
            fit: StackFit.expand,
            children: [
              PrismImageTile(
                url: entity.thumbnailUrl,
                fallbackUrl: entity.url,
                memCacheWidth: (MediaQuery.sizeOf(context).width * MediaQuery.devicePixelRatioOf(context)).round(),
              ),
              const _BottomScrim(),
              Positioned(
                left: _sidePadding,
                right: _sidePadding,
                bottom: _bottomPadding,
                child: Row(
                  children: [
                    Expanded(child: _Caption(photographer: entity.photographer)),
                    const SizedBox(width: 12),
                    _PastPicksPill(onTap: () => _openArchive(context)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The carousel dots take the bottom 30 px of every slide, so the caption row starts above them.
const double _sidePadding = 16;
const double _bottomPadding = 34;

class _BottomScrim extends StatelessWidget {
  const _BottomScrim();

  @override
  Widget build(BuildContext context) {
    final Color scrim = Theme.of(context).colorScheme.scrim;
    return IgnorePointer(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: FractionallySizedBox(
          widthFactor: 1,
          heightFactor: 0.45,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [scrim.withValues(alpha: 0), scrim.withValues(alpha: 0.2), scrim.withValues(alpha: 0.55)],
                stops: const [0, 0.5, 1],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption({required this.photographer});

  final String photographer;

  @override
  Widget build(BuildContext context) {
    final List<Shadow> shadows = [
      Shadow(color: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.4), blurRadius: 6),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'WALL OF THE DAY',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: PrismTextStyles.eyebrow(
            context,
          ).copyWith(color: PrismColors.onPrimary.withValues(alpha: 0.82), shadows: shadows),
        ),
        if (photographer.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            'by $photographer',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: PrismFonts.fraunces,
              fontSize: 20,
              fontWeight: FontWeight.w500,
              fontVariations: const [FontVariation('wght', 500)],
              height: 1.2,
              color: PrismColors.onPrimary,
              shadows: shadows,
            ),
          ),
        ],
      ],
    );
  }
}

class _PastPicksPill extends StatelessWidget {
  const _PastPicksPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      label: 'See past walls of the day',
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: PressScale(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: PrismGlass(
                borderRadius: 18,
                glassColor: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.3),
                child: SizedBox(
                  height: 36,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(start: 14, end: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Past picks',
                          maxLines: 1,
                          style: PrismTextStyles.caption(
                            context,
                          ).copyWith(fontSize: 13, fontWeight: FontWeight.w600, color: PrismColors.onPrimary),
                        ),
                        const SizedBox(width: 2),
                        const Icon(Icons.chevron_right_rounded, size: 18, color: PrismColors.onPrimary),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
