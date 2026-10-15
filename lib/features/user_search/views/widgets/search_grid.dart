import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/widgets/home/feed_scroll.dart';
import 'package:Prism/core/widgets/home/wallpapers/see_more_button.dart';
import 'package:Prism/core/widgets/prism_image_tile.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/category_feed/views/widgets/wallpaper_quick_actions.dart';
import 'package:Prism/features/user_search/data/search_filters.dart';
import 'package:Prism/features/user_search/data/wallpaper_search_service.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/app_tokens.dart';
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
  });

  final String query;
  final SearchProviderValue provider;
  final List<FeedItemEntity> initialResults;

  /// Prism catalogue walls that match [query]. Shown first, in a "From Prism" row.
  final List<FeedItemEntity> prismResults;
  final SearchFilters filters;

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

  bool get _hasExternalResults => widget.provider != SearchProviderValue.prism;

  int get _queryLength => widget.query.trim().length;

  void _trackResultsLoaded({required int page, required EventResultValue result}) {
    analytics.track(
      SearchResultsLoadedEvent(
        provider: widget.provider,
        queryLength: _queryLength,
        resultCount: _results.length,
        page: page,
        result: result,
      ),
    );
  }

  EventResultValue get _loadedResult => _results.isNotEmpty ? EventResultValue.success : EventResultValue.empty;

  Future<void> _requestNextPage() async {
    if (seeMoreLoader || !_hasMore) {
      return;
    }
    setState(() {
      seeMoreLoader = true;
      _loadMoreFailed = false;
    });
    final int nextPage = _currentPage + 1;
    analytics.track(
      SearchPaginationRequestedEvent(provider: widget.provider, queryLength: _queryLength, page: nextPage),
    );
    try {
      final more = await _search.fetchPage(widget.provider, widget.query, refresh: false, filters: widget.filters);
      if (!mounted) {
        return;
      }
      setState(() {
        _results = <FeedItemEntity>[..._results, ...more];
        _currentPage = nextPage;
        _hasMore = more.isNotEmpty;
      });
      _trackResultsLoaded(page: nextPage, result: _loadedResult);
    } catch (error, stackTrace) {
      logger.e('Failed to load search results page.', error: error, stackTrace: stackTrace);
      if (mounted) {
        setState(() => _loadMoreFailed = true);
      }
      _trackResultsLoaded(page: nextPage, result: EventResultValue.failure);
    } finally {
      if (mounted) {
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
      _trackResultsLoaded(page: 1, result: _loadedResult);
    });
  }

  Future<void> refreshList() async {
    if (!_hasExternalResults) {
      return;
    }
    try {
      final fresh = await _search.fetchPage(widget.provider, widget.query, refresh: true, filters: widget.filters);
      if (!mounted) {
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
      ),
    );
    context.router.push(
      WallpaperDetailRoute(
        entity: wallpaper,
        analyticsSurface: AnalyticsSurfaceValue.searchWallpaperScreen,
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
      ),
    );
    context.router.push(
      WallpaperDetailRoute(
        entity: wallpaper,
        analyticsSurface: AnalyticsSurfaceValue.searchWallpaperScreen,
        heroTag: prismHeroTag(widget.prismResults, index, wallpaper.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool showFooter = _hasMore && _results.length >= 24;
    final int columns = wallpaperGridColumns(MediaQuery.sizeOf(context).width);
    final int decodeHeight = gridTileDecodeHeight(context, crossAxisCount: columns);
    return RefreshIndicator(
      backgroundColor: Theme.of(context).primaryColor,
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
            if (widget.prismResults.isNotEmpty)
              SliverToBoxAdapter(
                child: _FromPrismRow(results: widget.prismResults, onOpen: _openPrismWallpaper),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(5, 4, 5, 4),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columns, childAspectRatio: 0.5),
                delegate: SliverChildBuilderDelegate((context, index) {
                  if (showFooter && index == _results.length) {
                    return SeeMoreButton(seeMoreLoader: seeMoreLoader, failed: _loadMoreFailed, func: _requestNextPage);
                  }
                  final FeedItemEntity wallpaper = _results[index];
                  return KeyedSubtree(
                    key: ValueKey<String>(wallpaper.id),
                    child: Semantics(
                      button: true,
                      label: wallpaperSemanticLabel(_authorName(wallpaper)),
                      // The image is the InkWell's child, so its Retry button stays tappable.
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          splashColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
                          highlightColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
                          enableFeedback: false,
                          onTap: () {
                            PrismHaptics.tap();
                            _openWallpaper(wallpaper, index);
                          },
                          onLongPress: () {
                            PrismHaptics.impact();
                            unawaited(showWallpaperQuickActions(context, wallpaper));
                          },
                          child: PrismImageTile(
                            url: wallpaper.thumbnailUrl,
                            fallbackUrl: wallpaper.fullUrl,
                            memCacheHeight: decodeHeight,
                            heroTag: prismHeroTag(this, index, wallpaper.id),
                          ),
                        ),
                      ),
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

class _FromPrismRow extends StatelessWidget {
  const _FromPrismRow({required this.results, required this.onOpen});

  final List<FeedItemEntity> results;
  final void Function(FeedItemEntity wallpaper, int index) onOpen;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Text('From Prism', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        ),
        SizedBox(
          height: 176,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: results.length,
            separatorBuilder: (_, _) => const SizedBox(width: 6),
            itemBuilder: (context, index) {
              final FeedItemEntity wallpaper = results[index];
              return KeyedSubtree(
                key: ValueKey<String>('prism-${wallpaper.id}'),
                child: Semantics(
                  button: true,
                  label: wallpaperSemanticLabel(_authorName(wallpaper)),
                  child: AspectRatio(
                    aspectRatio: 0.5,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        splashColor: theme.colorScheme.secondary.withValues(alpha: 0.3),
                        highlightColor: theme.colorScheme.secondary.withValues(alpha: 0.1),
                        onTap: () {
                          PrismHaptics.tap();
                          onOpen(wallpaper, index);
                        },
                        child: PrismImageTile(
                          url: wallpaper.thumbnailUrl,
                          fallbackUrl: wallpaper.fullUrl,
                          memCacheHeight: 400,
                          heroTag: prismHeroTag(results, index, wallpaper.id),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
