import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/premium_wall_utils.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/utils/url_launcher_compat.dart';
import 'package:Prism/core/widgets/glint/glint_state.dart';
import 'package:Prism/core/widgets/home/feed_scroll.dart';
import 'package:Prism/core/widgets/home/premium_corner_banner.dart';
import 'package:Prism/core/widgets/home/refreshable_glint_state.dart';
import 'package:Prism/core/widgets/home/wallpapers/carousel_dots.dart';
import 'package:Prism/core/widgets/home/wallpapers/loading.dart';
import 'package:Prism/core/widgets/prism_image_tile.dart';
import 'package:Prism/core/widgets/prism_sheet.dart';
import 'package:Prism/core/widgets/pulse_placeholder.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/category_feed/views/widgets/wallpaper_tile.dart';
import 'package:Prism/features/navigation/views/widgets/personalized_feed_settings_bottom_sheet.dart';
import 'package:Prism/features/personalized_feed/biz/bloc/personalized_feed_bloc.j.dart';
import 'package:Prism/features/personalized_feed/views/widgets/empty_card.dart';
import 'package:Prism/features/wall_of_the_day/wall_of_the_day.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PersonalizedFeedScreen extends StatefulWidget {
  const PersonalizedFeedScreen({super.key, this.onTuneTap});

  final VoidCallback? onTuneTap;

  @override
  State<PersonalizedFeedScreen> createState() => _PersonalizedFeedScreenState();
}

class _PersonalizedFeedScreenState extends State<PersonalizedFeedScreen> with AutomaticKeepAliveClientMixin {
  static const int _carouselPreviewCount = PrismFeedLayout.carouselPreviewCount;

  late final PersonalizedFeedBloc _bloc;
  final ScrollController _scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _bloc = getIt<PersonalizedFeedBloc>();
    personalizedFeedSettingsRevision.addListener(_onFeedSettingsChanged);
    _bloc.add(const PersonalizedFeedEvent.started());
  }

  void _onFeedSettingsChanged() {
    if (mounted) {
      _bloc.add(const PersonalizedFeedEvent.refreshRequested());
    }
  }

  @override
  void dispose() {
    personalizedFeedSettingsRevision.removeListener(_onFeedSettingsChanged);
    _scrollController.dispose();
    _bloc.close();
    super.dispose();
  }

  void _maybeFetchMore(PersonalizedFeedBloc bloc, ScrollMetrics metrics) {
    if (metrics.maxScrollExtent <= 0) {
      return;
    }
    final state = bloc.state;
    if (state.isFetchingMore ||
        !state.hasMore ||
        state.status == LoadStatus.loading ||
        state.actionStatus == ActionStatus.failure) {
      return;
    }

    if (isNearFeedEnd(metrics)) {
      bloc.add(const PersonalizedFeedEvent.fetchMoreRequested());
    }
  }

  /// Reloads the feed and completes when the new items arrive, so the pull-to-refresh spinner lasts as long as the load.
  Future<void> _refresh(PersonalizedFeedBloc bloc) async {
    PrismHaptics.impact();
    final Future<PersonalizedFeedState> settled = bloc.stream.firstWhere((s) => s.status != LoadStatus.loading);
    bloc.add(const PersonalizedFeedEvent.refreshRequested());
    final PersonalizedFeedState result = await settled.timeout(
      const Duration(seconds: 30),
      onTimeout: () => bloc.state,
    );
    if (mounted && result.actionStatus == ActionStatus.failure && result.items.isNotEmpty) {
      toasts.error("Couldn't refresh your feed.");
    }
  }

  Future<void> _showTileActions(FeedItemEntity item) async {
    PrismHaptics.impact();
    final bool? lessLikeThis = await showPrismSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) => SafeArea(
        child: ListTile(
          leading: const Icon(Icons.visibility_off_outlined),
          title: const Text('Show less like this'),
          subtitle: const Text("You'll see fewer walls like this."),
          onTap: () => Navigator.of(sheetContext).pop(true),
        ),
      ),
    );
    if (lessLikeThis != true || !mounted) {
      return;
    }
    _bloc.add(PersonalizedFeedEvent.lessLikeThisRequested(item));
    toasts.success("Got it. You'll see fewer like this.");
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return BlocProvider.value(
      value: _bloc,
      child: BlocBuilder<PersonalizedFeedBloc, PersonalizedFeedState>(
        buildWhen: (prev, curr) =>
            prev.status != curr.status ||
            !identical(prev.items, curr.items) ||
            prev.actionStatus != curr.actionStatus ||
            prev.isFetchingMore != curr.isFetchingMore ||
            prev.hasMore != curr.hasMore,
        builder: (context, state) {
          final bloc = context.read<PersonalizedFeedBloc>();
          if (state.status == LoadStatus.initial || (state.status == LoadStatus.loading && state.items.isEmpty)) {
            return const LoadingCards();
          }

          if (state.status == LoadStatus.failure && state.items.isEmpty) {
            return RefreshableGlintState(
              kind: GlintStateKind.error,
              title: "Couldn't load your feed",
              body: 'Check your connection and try again.',
              actionLabel: 'Retry',
              onAction: () => unawaited(_refresh(bloc)),
              onRefresh: () => _refresh(bloc),
            );
          }

          final prismItems = state.items.whereType<PrismFeedItem>();
          final previewWalls = prismItems.take(_carouselPreviewCount).toList(growable: false);
          final previewSet = prismItems.take(_carouselPreviewCount).toSet();
          final visibleItems = state.items.where((item) => !previewSet.contains(item)).toList(growable: false);
          final crossAxisCount = wallpaperGridColumns(MediaQuery.sizeOf(context).width);
          final tileMemCacheHeight = gridTileDecodeHeight(context, crossAxisCount: crossAxisCount);

          return RefreshIndicator(
            onRefresh: () => _refresh(bloc),
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification.depth == 0) {
                  _maybeFetchMore(bloc, notification.metrics);
                }
                return false;
              },
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                slivers: [
                  // Carousel: WallOfTheDay + banner + wallpaper previews
                  SliverToBoxAdapter(child: _FeedCarousel(previewWalls: previewWalls)),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(start: 16, end: 4),
                      child: Row(
                        children: [
                          Expanded(child: Text('For you', style: PrismTextStyles.editorialTitle(context))),
                          IconButton(
                            onPressed: widget.onTuneTap == null
                                ? null
                                : () {
                                    PrismHaptics.tap();
                                    widget.onTuneTap!();
                                  },
                            tooltip: 'Tune your feed',
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.tune_rounded),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      childAspectRatio: PrismFeedLayout.gridTileAspectRatio,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => GestureDetector(
                        key: ValueKey<String>(visibleItems[index].id),
                        onLongPress: () => unawaited(_showTileActions(visibleItems[index])),
                        child: WallpaperTile(
                          item: visibleItems[index],
                          index: index,
                          crossAxisCount: crossAxisCount,
                          memCacheHeight: tileMemCacheHeight,
                        ),
                      ),
                      childCount: visibleItems.length,
                    ),
                  ),
                  SliverToBoxAdapter(child: _bottomState(context, state)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _bottomState(BuildContext context, PersonalizedFeedState state) {
    if (state.items.isEmpty) {
      return GlintState(
        kind: GlintStateKind.empty,
        title: 'Shape this feed',
        body: 'Follow creators or choose interests so we can surface more of what you like.',
        actionLabel: widget.onTuneTap == null ? null : 'Tune your feed',
        onAction: widget.onTuneTap,
      );
    }

    if (state.actionStatus == ActionStatus.failure && !state.isFetchingMore) {
      return Padding(
        padding: PrismFeedLayout.contentStatePadding,
        child: Center(
          child: TextButton(
            onPressed: () {
              PrismHaptics.tap();
              context.read<PersonalizedFeedBloc>().add(const PersonalizedFeedEvent.fetchMoreRequested());
            },
            child: const Text("Couldn't load more. Tap to retry"),
          ),
        ),
      );
    }

    if (state.isFetchingMore) {
      return Padding(
        padding: PrismFeedLayout.loadingStatePadding,
        child: SizedBox(
          height: 120,
          child: PulsePlaceholder(
            builder: (context, _) => const Row(
              children: <Widget>[
                Expanded(child: PulseFill()),
                SizedBox(width: 8),
                Expanded(child: PulseFill()),
                SizedBox(width: 8),
                Expanded(child: PulseFill()),
              ],
            ),
          ),
        ),
      );
    }

    if (state.hasMore) {
      return const SizedBox(height: PrismFeedLayout.endOfPageSpacerHeight);
    }

    return const Padding(
      padding: PrismFeedLayout.contentStatePadding,
      child: PersonalizedFeedEditorialNote(
        title: "You're caught up",
        detail: 'Pull down to refresh — new picks will land here.',
      ),
    );
  }
}

class _FeedCarousel extends StatefulWidget {
  const _FeedCarousel({required this.previewWalls});

  final List<PrismFeedItem> previewWalls;

  @override
  State<_FeedCarousel> createState() => _FeedCarouselState();
}

class _FeedCarouselState extends State<_FeedCarousel> {
  int _current = 0;

  @override
  Widget build(BuildContext context) {
    final previewWalls = widget.previewWalls;
    final bool hasWotd = context.watch<WotdBloc>().state.entity != null;
    final int slideOffset = hasWotd ? 2 : 1;
    final int slideCount = slideOffset + previewWalls.length;
    final height = MediaQuery.of(context).size.width * PrismFeedLayout.carouselHeightRatio;
    return SizedBox(
      height: height,
      child: Stack(
        alignment: AlignmentDirectional.bottomEnd,
        children: [
          CarouselSlider.builder(
            itemCount: slideCount,
            options: CarouselOptions(
              height: height,
              viewportFraction: 1.0,
              autoPlay: !context.reduceMotion,
              autoPlayInterval: const Duration(seconds: 5),
              onPageChanged: (index, reason) {
                if (mounted) setState(() => _current = index);
              },
            ),
            itemBuilder: (BuildContext context, int i, int rI) {
              if (hasWotd && i == 0) {
                return const SizedBox.expand(child: WallOfTheDayCard());
              }
              if (i == slideOffset - 1) {
                return GestureDetector(
                  onTap: () {
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
                  },
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      PrismImageTile(url: app_state.topImageLink),
                      Center(
                        child: ColoredBox(
                          color: app_state.bannerTextOn
                              ? Theme.of(
                                  context,
                                ).colorScheme.scrim.withValues(alpha: PrismOverlay.carouselBannerScrimAlpha)
                              : Colors.transparent,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              app_state.bannerTextOn ? app_state.bannerText.toUpperCase() : "",
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              // High-contrast on arbitrary photography under [ColorScheme.scrim].
                              style: PrismTextStyles.carouselBannerHeadline(context),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }
              final int feedIndex = i - slideOffset;
              final PrismFeedItem wall = previewWalls[feedIndex];
              return Semantics(
                button: true,
                label: wall.semanticLabel,
                child: GestureDetector(
                  onTap: () {
                    PrismHaptics.tap();
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
                  },
                  child: PremiumCornerBanner(
                    isPremiumWall: isPremiumWall(
                      app_state.premiumCollections,
                      wall.wallpaper.collections ?? const <String>[],
                    ),
                    child: SizedBox.expand(
                      child: PrismImageTile(url: wall.thumbnailUrl, fallbackUrl: wall.fullUrl),
                    ),
                  ),
                ),
              );
            },
          ),
          CarouselDots(current: _current.clamp(0, slideCount - 1), count: slideCount),
        ],
      ),
    );
  }
}
