import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/analytics/trackers/wallpaper_impression.dart';
import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/url_launcher_compat.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/prism_image_tile.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/drops/domain/entities/drop_entity.dart';
import 'package:Prism/features/drops/views/widgets/drop_carousel_slide.dart';
import 'package:Prism/features/personalized_feed/views/widgets/feed_hero_card.dart';
import 'package:Prism/features/personalized_feed/views/widgets/feed_wall_tile.dart';
import 'package:Prism/features/trending/views/widgets/boosted_tag.dart';
import 'package:Prism/features/wall_of_the_day/wall_of_the_day.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:auto_route/auto_route.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// How many carousel cards sit side by side for a screen [width]: one on a phone, two on a tablet, so each card stays
/// about 480 wide.
int feedCarouselColumns(double width) => (width / 480).floor().clamp(1, 3);

/// Height of one carousel page: the page is as wide as the screen divided by [feedCarouselColumns], less the
/// [PrismFeedLayout.gridSpacing] margin on both sides, and 0.6 times as tall as it is wide.
double feedCarouselCardHeight(BuildContext context) {
  final double width = MediaQuery.sizeOf(context).width;
  return (width / feedCarouselColumns(width) - 2 * PrismFeedLayout.gridSpacing) * 0.6;
}

/// The home carousel: Wall of the Day, the live Drop, boosted walls, the promo banner and the first wallpapers as
/// rounded pages, with page dots over the bottom of the image.
class FeedCarousel extends StatefulWidget {
  const FeedCarousel({
    super.key,
    required this.previewWalls,
    this.boostedWalls = const <PrismWallpaper>[],
    this.liveDrop,
    this.onWallShown,
  });

  final List<PrismFeedItem> previewWalls;

  /// Walls with a live boost. They follow the Wall of the Day, so a boost buys one of the first views of the home.
  final List<PrismWallpaper> boostedWalls;

  /// The live Drop. It gets a page right after the Wall of the Day while the Drops flag is on.
  final DropEntity? liveDrop;

  /// Called after a preview wallpaper meets the visibility and dwell threshold.
  final ValueChanged<PrismFeedItem>? onWallShown;

  @override
  State<FeedCarousel> createState() => _FeedCarouselState();
}

class _FeedCarouselState extends State<FeedCarousel> {
  int _current = 0;
  final CarouselSliderController _controller = CarouselSliderController();

  bool _showsDrop(DropEntity? drop) =>
      drop != null && EconomyConfig.notifier.value.flags.dropsEnabled && drop.isLiveAt(DateTime.now());

  int get _dropIndex => context.read<WotdBloc>().state.entity != null ? 1 : 0;

  @override
  void didUpdateWidget(FeedCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_showsDrop(widget.liveDrop) && !_showsDrop(oldWidget.liveDrop)) {
      // A new page shifts the ones after it. Keep the user on the page they are looking at.
      final int target = _current >= _dropIndex ? _current + 1 : _current;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _controller.jumpToPage(target);
      });
    }
  }

  void _openDrop() {
    PrismHaptics.tap();
    unawaited(context.router.push(const DropsRoute()));
  }

  void _openBanner() {
    PrismHaptics.tap();
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

  void _openWall(PrismFeedItem wall, int feedIndex, String sourceContext) {
    PrismHaptics.tap();
    unawaited(
      analytics.track(
        SurfaceActionTappedEvent(
          surface: AnalyticsSurfaceValue.homeWallpaperGrid,
          action: AnalyticsActionValue.carouselItemOpened,
          sourceContext: sourceContext,
          itemType: ItemTypeValue.wallpaper,
          itemId: wall.id,
          index: feedIndex,
          requestId: WallpaperImpressionScope.maybeOf(context)?.requestId,
          provider: wall.source.name,
        ),
      ),
    );
    context.router.push(
      WallpaperDetailRoute(entity: wall, requestId: WallpaperImpressionScope.maybeOf(context)?.requestId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasWotd = context.select((WotdBloc bloc) => bloc.state.entity != null);
    final String bannerImage = app_state.topImageLink;
    final String bannerTitle = app_state.bannerTextOn ? app_state.bannerText : '';
    final double height = feedCarouselCardHeight(context);
    final double width = MediaQuery.sizeOf(context).width;
    final int columns = feedCarouselColumns(width);
    final int memCacheHeight = (height * MediaQuery.devicePixelRatioOf(context)).round();
    final List<Widget> pages = <Widget>[
      if (hasWotd) const WallOfTheDayCard(),
      if (_showsDrop(widget.liveDrop))
        DropCarouselSlide(
          drop: widget.liveDrop!,
          now: DateTime.now(),
          memCacheHeight: memCacheHeight,
          onTap: _openDrop,
        ),
      for (int i = 0; i < widget.boostedWalls.length; i++) _boostedCard(widget.boostedWalls[i], i, memCacheHeight),
      if (bannerImage.trim().isNotEmpty)
        FeedHeroCard(
          image: PrismImageTile(url: bannerImage, memCacheHeight: memCacheHeight),
          semanticLabel: bannerTitle.isEmpty ? 'Announcement' : bannerTitle,
          title: bannerTitle,
          onTap: _openBanner,
        ),
      for (int i = 0; i < widget.previewWalls.length; i++) _previewCard(widget.previewWalls[i], i, memCacheHeight),
    ];
    if (pages.isEmpty) return const SizedBox.shrink();
    final int current = _current.clamp(0, pages.length - 1);
    final bool moving = pages.length > 1;
    // The Home tab stays built under other tabs and pushed routes. Only turn pages that someone can see.
    final bool visible = TickerMode.valuesOf(context).enabled && (ModalRoute.of(context)?.isCurrent ?? true);
    return Stack(
      children: <Widget>[
        CarouselSlider.builder(
          carouselController: _controller,
          itemCount: pages.length,
          options: CarouselOptions(
            height: height,
            viewportFraction: 1 / columns,
            padEnds: columns == 1,
            autoPlay: moving && !context.reduceMotion && visible,
            autoPlayInterval: const Duration(seconds: 5),
            autoPlayCurve: PrismCurves.move,
            enableInfiniteScroll: moving,
            onPageChanged: (int index, CarouselPageChangedReason reason) {
              if (mounted) setState(() => _current = index);
            },
          ),
          itemBuilder: (BuildContext context, int i, int realIndex) =>
              Padding(padding: PrismFeedLayout.gridPadding, child: pages[i]),
        ),
        if (moving)
          Positioned(
            left: 0,
            right: width - width / columns,
            bottom: PrismSpace.sm,
            child: FeedCarouselDots(current: current, count: pages.length),
          ),
      ],
    );
  }

  Widget _boostedCard(PrismWallpaper wall, int index, int memCacheHeight) => _wallCard(
    PrismFeedItem(id: wall.id, wallpaper: wall),
    index,
    memCacheHeight,
    source: 'personalized_feed_carousel_boosted',
    tag: const BoostedTag(),
  );

  Widget _previewCard(PrismFeedItem wall, int feedIndex, int memCacheHeight) => _wallCard(
    wall,
    feedIndex,
    memCacheHeight,
    source: 'personalized_feed_carousel',
    onVisible: () => widget.onWallShown?.call(wall),
  );

  Widget _wallCard(
    PrismFeedItem wall,
    int index,
    int memCacheHeight, {
    required String source,
    Widget? tag,
    VoidCallback? onVisible,
  }) {
    return WallpaperImpression(
      itemId: wall.id,
      provider: wall.source.name,
      surface: AnalyticsSurfaceValue.homeWallpaperGrid,
      source: source,
      index: index,
      onVisible: onVisible,
      child: FeedHeroCard(
        image: PrismImageTile(
          url: wall.wallpaper.thumbnailUrl,
          fallbackUrl: wall.wallpaper.fullUrl,
          memCacheHeight: memCacheHeight,
        ),
        semanticLabel: wall.semanticLabel,
        tag: tag,
        badge: isPremiumFeedItem(wall) ? const PremiumStarBadge() : null,
        onTap: () => _openWall(wall, index, source),
      ),
    );
  }
}

/// The page dots, drawn in white with a soft shadow so they read over any image. They never take a touch, so swipes
/// and taps reach the page under them.
class FeedCarouselDots extends StatelessWidget {
  const FeedCarouselDots({required this.current, required this.count});

  final int current;
  final int count;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: IgnorePointer(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            for (int i = 0; i < count; i++)
              AnimatedContainer(
                duration: context.motion(PrismDurations.fast),
                curve: PrismCurves.enter,
                width: current == i ? 16 : 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(PrismRadius.pill),
                  color: Colors.white.withValues(alpha: current == i ? 1 : 0.5),
                  boxShadow: <BoxShadow>[
                    BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 4, offset: const Offset(0, 1)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
