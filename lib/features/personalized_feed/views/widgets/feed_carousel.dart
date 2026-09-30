import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/url_launcher_compat.dart';
import 'package:Prism/core/widgets/prism/prism_wall_grid.dart';
import 'package:Prism/core/widgets/prism_image_tile.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/personalized_feed/views/widgets/feed_hero_card.dart';
import 'package:Prism/features/personalized_feed/views/widgets/feed_wall_tile.dart';
import 'package:Prism/features/wall_of_the_day/wall_of_the_day.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:auto_route/auto_route.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Height of one carousel card: the card is inset by the grid margin and about 0.56 as tall as it is wide.
double feedCarouselCardHeight(BuildContext context) =>
    (MediaQuery.sizeOf(context).width - 2 * PrismWallGrid.margin) * 0.56;

/// The home carousel: Wall of the Day, the promo banner and the first wallpapers, with page dots under the card.
class FeedCarousel extends StatefulWidget {
  const FeedCarousel({super.key, required this.previewWalls});

  final List<PrismFeedItem> previewWalls;

  @override
  State<FeedCarousel> createState() => _FeedCarouselState();
}

class _FeedCarouselState extends State<FeedCarousel> {
  int _current = 0;

  void _openBanner() {
    unawaited(
      analytics.track(
        const SurfaceActionTappedEvent(
          surface: AnalyticsSurfaceValue.homeWallpaperGrid,
          action: AnalyticsActionValue.bannerTapped,
          sourceContext: 'personalized_feed_carousel_banner',
        ),
      ),
    );
    openPrismLink(context, app_state.bannerURL);
  }

  void _openWall(PrismFeedItem wall, int feedIndex) {
    unawaited(
      analytics.track(
        SurfaceActionTappedEvent(
          surface: AnalyticsSurfaceValue.homeWallpaperGrid,
          action: AnalyticsActionValue.carouselItemOpened,
          sourceContext: 'personalized_feed_carousel',
          itemType: ItemTypeValue.wallpaper,
          itemId: wall.id,
          index: feedIndex,
        ),
      ),
    );
    context.router.push(WallpaperDetailRoute(entity: wall));
  }

  @override
  Widget build(BuildContext context) {
    final bool hasWotd = context.select((WotdBloc bloc) => bloc.state.entity != null);
    final String bannerImage = app_state.topImageLink;
    final String bannerTitle = app_state.bannerTextOn ? app_state.bannerText : '';
    final List<Widget> pages = <Widget>[
      if (hasWotd) const WallOfTheDayCard(),
      if (bannerImage.trim().isNotEmpty)
        FeedHeroCard(
          image: PrismImageTile(url: bannerImage),
          semanticLabel: bannerTitle.isEmpty ? 'Announcement' : bannerTitle,
          title: bannerTitle,
          onTap: _openBanner,
        ),
      for (int i = 0; i < widget.previewWalls.length; i++) _previewCard(widget.previewWalls[i], i),
    ];
    if (pages.isEmpty) return const SizedBox.shrink();
    final int current = _current.clamp(0, pages.length - 1);
    final bool moving = pages.length > 1;
    final double height = feedCarouselCardHeight(context);
    return Column(
      children: <Widget>[
        CarouselSlider.builder(
          itemCount: pages.length,
          options: CarouselOptions(
            height: height,
            viewportFraction: 1.0,
            autoPlay: moving && !context.reduceMotion,
            autoPlayInterval: const Duration(seconds: 5),
            autoPlayCurve: PrismCurves.move,
            enableInfiniteScroll: moving,
            onPageChanged: (int index, CarouselPageChangedReason reason) {
              if (mounted) setState(() => _current = index);
            },
          ),
          itemBuilder: (BuildContext context, int i, int realIndex) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: PrismWallGrid.margin),
            child: pages[i],
          ),
        ),
        if (moving) _CarouselDots(current: current, count: pages.length),
      ],
    );
  }

  Widget _previewCard(PrismFeedItem wall, int feedIndex) {
    final String? author = wall.wallpaper.core.authorName?.trim();
    final String category = wall.wallpaper.core.category?.trim() ?? '';
    return FeedHeroCard(
      image: PrismImageTile(url: wall.wallpaper.thumbnailUrl),
      semanticLabel: wall.semanticLabel,
      title: category.isEmpty ? 'Wallpaper' : category,
      subtitle: author == null || author.isEmpty ? null : 'by $author',
      badge: isPremiumFeedItem(wall) ? const PremiumStarBadge() : null,
      onTap: () => _openWall(wall, feedIndex),
    );
  }
}

class _CarouselDots extends StatelessWidget {
  const _CarouselDots({required this.current, required this.count});

  final int current;
  final int count;

  @override
  Widget build(BuildContext context) {
    final Color ink = Theme.of(context).colorScheme.onSurface;
    return ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.only(top: PrismSpace.sm),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            for (int i = 0; i < count; i++)
              AnimatedContainer(
                duration: context.motion(PrismDurations.fast),
                curve: PrismCurves.enter,
                width: 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: current == i ? ink : ink.withValues(alpha: 0.25),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
