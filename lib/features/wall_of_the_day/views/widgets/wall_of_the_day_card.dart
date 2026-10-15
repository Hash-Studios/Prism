import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/animated/press_scale.dart';
import 'package:Prism/core/widgets/prism/prism_bits.dart';
import 'package:Prism/core/widgets/prism_image_tile.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/personalized_feed/views/widgets/feed_hero_card.dart';
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
    final ColorScheme cs = Theme.of(context).colorScheme;
    final String photographer = entity.photographer.trim();
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        FeedHeroCard(
          image: PrismImageTile(
            url: entity.thumbnailUrl,
            fallbackUrl: entity.url,
            memCacheWidth: (MediaQuery.sizeOf(context).width * MediaQuery.devicePixelRatioOf(context)).round(),
          ),
          semanticLabel: photographer.isEmpty ? 'Wall of the day' : 'Wall of the day by $photographer',
          title: photographer.isEmpty ? null : 'by $photographer',
          tag: ClipRRect(
            borderRadius: BorderRadius.circular(PrismRadius.pill),
            child: ColoredBox(
              color: cs.surfaceContainerHigh,
              child: const PrismTag(label: 'Wall of the day'),
            ),
          ),
          onTap: () {
            PrismHaptics.tap();
            _openWallpaper(context);
          },
        ),
        // A sibling of the card, not a child, so the card's own semantics do not swallow it.
        PositionedDirectional(
          top: 6,
          end: PrismSpace.sm,
          child: _PastPicksPill(onTap: () => _openArchive(context)),
        ),
      ],
    );
  }
}

/// Opens the archive of earlier picks. A 36 point pill on the image inside a 48 point tap target.
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
              child: MediaQuery.withClampedTextScaling(
                maxScaleFactor: 1.5,
                // On a wallpaper the theme does not apply: white on a dark translucent pill.
                child: DecoratedBox(
                  key: const ValueKey<String>('wotd-past-picks-pill'),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.38),
                    borderRadius: BorderRadius.circular(PrismRadius.pill),
                  ),
                  child: SizedBox(
                    height: 36,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(start: PrismSpace.sm, end: PrismSpace.xxs),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            'Past picks',
                            maxLines: 1,
                            style: PrismTextStyles.caption(
                              context,
                            ).copyWith(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                          const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.white),
                        ],
                      ),
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
