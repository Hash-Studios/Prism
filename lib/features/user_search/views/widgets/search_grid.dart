import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/analytics/trackers/wallpaper_impression.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/widgets/depth_tag.dart';
import 'package:Prism/core/widgets/home/feed_scroll.dart';
import 'package:Prism/core/widgets/home/wallpapers/see_more_button.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/category_feed/views/widgets/wallpaper_quick_actions.dart';
import 'package:Prism/features/user_search/data/search_filters.dart';
import 'package:Prism/features/user_search/data/wallpaper_search_service.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

String? _authorName(FeedItemEntity wallpaper) => wallpaper.when(
  prism: (_, wall) => wall.core.authorName,
  wallhaven: (_, _) => null,
  pexels: (_, wall) => wall.core.authorName,
);

class SearchGrid extends StatefulWidget {
  const SearchGrid({
    super.key,
    required this.query,
    required this.provider,
    required this.initialResults,
    this.prismResults = const <FeedItemEntity>[],
    this.filters = const SearchFilters(),
    this.isLocal = false,
    this.searchId,
    this.trackInitialResults = true,
  });

  final String query;
  final SearchProviderValue provider;
  final List<FeedItemEntity> initialResults;

  /// Prism catalogue walls that match [query]. Shown first, in a "From Prism" row.
  final List<FeedItemEntity> prismResults;
  final SearchFilters filters;
  final bool isLocal;
  final String? searchId;
  final bool trackInitialResults;

  @override
  State<SearchGrid> createState() => _SearchGridState();
}

class _SearchGridState extends State<SearchGrid> {
  final WallpaperSearchService _search = getIt<WallpaperSearchService>();
  late List<FeedItemEntity> _results = widget.initialResults;
  bool seeMoreLoader = false;
  late bool _hasMore = _hasExternalResults;
  bool _loadMoreFailed = false;
  int _currentPage = 1;
  int _loadGeneration = 0;
  late WallpaperImpressionSession _impressions = WallpaperImpressionSession(requestId: widget.searchId);

  bool get _hasExternalResults => !widget.isLocal && widget.provider != SearchProviderValue.prism;

  int get _queryLength => widget.query.trim().length;

  int get _resultCount => _results.length + widget.prismResults.length;

  void _trackResultsLoaded({required int page, required EventResultValue result, String? reason}) {
    analytics.track(
      SearchResultsLoadedEvent(
        provider: widget.provider,
        queryLength: _queryLength,
        resultCount: result == EventResultValue.cancelled ? 0 : _resultCount,
        page: page,
        result: result,
        searchId: widget.searchId,
        reason: reason,
      ),
    );
  }

  EventResultValue get _loadedResult => _resultCount > 0 ? EventResultValue.success : EventResultValue.empty;

  Future<void> _requestNextPage() async {
    if (seeMoreLoader || !_hasMore) {
      return;
    }
    setState(() {
      seeMoreLoader = true;
      _loadMoreFailed = false;
    });
    final int nextPage = _currentPage + 1;
    final int generation = _loadGeneration;
    analytics.track(
      SearchPaginationRequestedEvent(
        provider: widget.provider,
        queryLength: _queryLength,
        page: nextPage,
        searchId: widget.searchId,
      ),
    );
    try {
      final more = await _search.fetchPage(widget.provider, widget.query, refresh: false, filters: widget.filters);
      if (!mounted || generation != _loadGeneration) {
        _trackResultsLoaded(page: nextPage, result: EventResultValue.cancelled, reason: 'superseded');
        return;
      }
      setState(() {
        _results = <FeedItemEntity>[..._results, ...more];
        _currentPage = nextPage;
        _hasMore = more.isNotEmpty;
      });
      _trackResultsLoaded(page: nextPage, result: _loadedResult);
    } catch (error, stackTrace) {
      if (!mounted || generation != _loadGeneration) {
        _trackResultsLoaded(page: nextPage, result: EventResultValue.cancelled, reason: 'superseded');
        return;
      }
      logger.e('Failed to load search results page.', error: error, stackTrace: stackTrace);
      if (mounted && generation == _loadGeneration) {
        setState(() => _loadMoreFailed = true);
      }
      _trackResultsLoaded(page: nextPage, result: EventResultValue.failure);
    } finally {
      if (mounted && generation == _loadGeneration) {
        setState(() {
          seeMoreLoader = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.trackInitialResults) _trackResultsLoaded(page: 1, result: _loadedResult);
    });
  }

  Future<void> refreshList() async {
    if (!_hasExternalResults) {
      return;
    }
    final int generation = ++_loadGeneration;
    setState(() => seeMoreLoader = false);
    try {
      final fresh = await _search.fetchPage(widget.provider, widget.query, refresh: true, filters: widget.filters);
      if (!mounted || generation != _loadGeneration) {
        return;
      }
      setState(() {
        if (fresh.isNotEmpty) {
          _results = fresh;
        }
        _currentPage = 1;
        _hasMore = fresh.isNotEmpty;
        _loadMoreFailed = false;
      });
      _trackResultsLoaded(page: 1, result: _loadedResult);
    } catch (error, stackTrace) {
      if (!mounted || generation != _loadGeneration) return;
      logger.e('Failed to refresh search results.', error: error, stackTrace: stackTrace);
      toasts.error("Couldn't refresh. Pull down to try again.");
      _trackResultsLoaded(page: 1, result: EventResultValue.failure);
    }
  }

  void _openWallpaper(FeedItemEntity wallpaper, int index) {
    analytics.track(
      SearchResultOpenedEvent(
        provider: widget.provider,
        itemType: ItemTypeValue.wallpaper,
        itemId: wallpaper.id,
        index: index,
        queryLength: _queryLength,
        searchId: widget.searchId,
      ),
    );
    context.router.push(
      WallpaperDetailRoute(
        entity: wallpaper,
        analyticsSurface: AnalyticsSurfaceValue.searchWallpaperScreen,
        requestId: widget.searchId,
        heroTag: prismHeroTag(this, index, wallpaper.id),
      ),
    );
  }

  void _openPrismWallpaper(FeedItemEntity wallpaper, int index) {
    analytics.track(
      SearchResultOpenedEvent(
        provider: SearchProviderValue.prism,
        itemType: ItemTypeValue.wallpaper,
        itemId: wallpaper.id,
        index: index,
        queryLength: _queryLength,
        searchId: widget.searchId,
      ),
    );
    context.router.push(
      WallpaperDetailRoute(
        entity: wallpaper,
        analyticsSurface: AnalyticsSurfaceValue.searchWallpaperScreen,
        requestId: widget.searchId,
        heroTag: prismHeroTag(widget.prismResults, index, wallpaper.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool showFooter = _hasMore && _results.length >= 24;
    final int columns = wallpaperGridColumns(MediaQuery.sizeOf(context).width);
    final int decodeHeight = gridTileDecodeHeight(context, crossAxisCount: columns);
    return RefreshIndicator(
      color: cs.primary,
      backgroundColor: cs.surfaceContainerHigh,
      onRefresh: () {
        PrismHaptics.impact();
        return refreshList();
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification scrollInfo) {
          // The "From Prism" row scrolls sideways inside this list. Only the results list asks for more.
          if (scrollInfo.depth != 0) return false;
          if (!_loadMoreFailed && isNearFeedEnd(scrollInfo.metrics)) {
            unawaited(_requestNextPage());
          }
          return false;
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          scrollCacheExtent: const ScrollCacheExtent.viewport(1.5),
          slivers: <Widget>[
            if (widget.isLocal)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(PrismSpace.md, PrismSpace.sm, PrismSpace.md, PrismSpace.xs),
                  child: Text('Saved on this device', style: Theme.of(context).textTheme.labelMedium),
                ),
              ),
            if (widget.prismResults.isNotEmpty)
              SliverToBoxAdapter(
                child: _FromPrismRow(results: widget.prismResults, onOpen: _openPrismWallpaper, session: _impressions),
              ),
            SliverPadding(
              padding: PrismWallGrid.padding.copyWith(top: PrismSpace.xxs, bottom: PrismSpace.bottomBarClearance),
              sliver: SliverGrid(
                gridDelegate: PrismWallGrid.delegate(context),
                delegate: SliverChildBuilderDelegate((context, index) {
                  if (showFooter && index == _results.length) {
                    return SeeMoreButton(seeMoreLoader: seeMoreLoader, failed: _loadMoreFailed, func: _requestNextPage);
                  }
                  final FeedItemEntity wallpaper = _results[index];
                  return WallpaperImpression(
                    itemId: wallpaper.id,
                    provider: wallpaper.source.name,
                    surface: AnalyticsSurfaceValue.searchWallpaperScreen,
                    source: 'search_results',
                    index: index,
                    session: _impressions,
                    child: PrismWallTile(
                      key: ValueKey<String>(wallpaper.id),
                      url: wallpaper.thumbnailUrl,
                      fallbackUrl: wallpaper.fullUrl,
                      memCacheHeight: decodeHeight,
                      heroTag: prismHeroTag(this, index, wallpaper.id),
                      semanticLabel: wallpaperSemanticLabel(_authorName(wallpaper)),
                      overlay: depthTagFor(depthTierOf(wallpaper)),
                      onTap: () {
                        PrismHaptics.tap();
                        _openWallpaper(wallpaper, index);
                      },
                      onLongPress: () {
                        PrismHaptics.impact();
                        unawaited(showWallpaperQuickActions(context, wallpaper, requestId: widget.searchId));
                      },
                    ),
                  );
                }, childCount: _results.length + (showFooter ? 1 : 0)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Prism catalogue walls that match the query, as a sideways row above the provider results.
class _FromPrismRow extends StatelessWidget {
  const _FromPrismRow({required this.results, required this.onOpen, required this.session});
  final WallpaperImpressionSession session;

  final List<FeedItemEntity> results;
  final void Function(FeedItemEntity wallpaper, int index) onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const PrismSectionHeader(
          title: 'From Prism',
          small: true,
          padding: EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.xs, PrismSpace.page, PrismSpace.xs),
        ),
        SizedBox(
          height: 176,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: PrismWallGrid.padding,
            itemCount: results.length,
            separatorBuilder: (_, _) => const SizedBox(width: PrismWallGrid.spacing),
            itemBuilder: (context, index) {
              final FeedItemEntity wallpaper = results[index];
              return AspectRatio(
                aspectRatio: 0.5,
                child: WallpaperImpression(
                  itemId: wallpaper.id,
                  provider: wallpaper.source.name,
                  surface: AnalyticsSurfaceValue.searchWallpaperScreen,
                  source: 'search_prism_results',
                  index: index,
                  session: session,
                  child: PrismWallTile(
                    key: ValueKey<String>('prism-${wallpaper.id}'),
                    url: wallpaper.thumbnailUrl,
                    fallbackUrl: wallpaper.fullUrl,
                    memCacheHeight: 400,
                    heroTag: prismHeroTag(results, index, wallpaper.id),
                    semanticLabel: wallpaperSemanticLabel(_authorName(wallpaper)),
                    overlay: depthTagFor(depthTierOf(wallpaper)),
                    onTap: () {
                      PrismHaptics.tap();
                      onOpen(wallpaper, index);
                    },
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: PrismSpace.xs),
      ],
    );
  }
}
