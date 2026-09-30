import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/widgets/animated/shake_once.dart';
import 'package:Prism/core/widgets/home/wallpapers/see_more_button.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/data/share/create_dynamic_link.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/user_search/data/wallpaper_search_service.dart';
import 'package:Prism/logger/logger.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

String? _authorName(FeedItemEntity wallpaper) => wallpaper.when(
  prism: (_, wall) => wall.core.authorName,
  wallhaven: (_, _) => null,
  pexels: (_, wall) => wall.core.authorName,
);

class SearchGrid extends StatefulWidget {
  const SearchGrid({super.key, required this.query, required this.provider, required this.initialResults});

  final String query;
  final SearchProviderValue provider;
  final List<FeedItemEntity> initialResults;

  @override
  State<SearchGrid> createState() => _SearchGridState();
}

class _SearchGridState extends State<SearchGrid> {
  final WallpaperSearchService _search = getIt<WallpaperSearchService>();
  final ShakeController _shake = ShakeController();
  final GlobalKey<RefreshIndicatorState> refreshHomeKey = GlobalKey<RefreshIndicatorState>();
  late List<FeedItemEntity> _results = widget.initialResults;
  bool seeMoreLoader = false;
  bool _hasMore = true;
  int _currentPage = 1;

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
    });
    final int nextPage = _currentPage + 1;
    analytics.track(
      SearchPaginationRequestedEvent(provider: widget.provider, queryLength: _queryLength, page: nextPage),
    );
    try {
      final more = await _search.fetchPage(widget.provider, widget.query, refresh: false);
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

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  Future<void> refreshList() async {
    refreshHomeKey.currentState?.show();
    try {
      final fresh = await _search.fetchPage(widget.provider, widget.query, refresh: true);
      if (!mounted) {
        return;
      }
      setState(() {
        if (fresh.isNotEmpty) {
          _results = fresh;
        }
        _currentPage = 1;
        _hasMore = fresh.isNotEmpty;
      });
      _trackResultsLoaded(page: 1, result: _loadedResult);
    } catch (error, stackTrace) {
      logger.e('Failed to refresh search results.', error: error, stackTrace: stackTrace);
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

  void _shareWallpaper(FeedItemEntity wallpaper, int index) {
    _shake.shake(index);
    HapticFeedback.vibrate();
    createDynamicLink(wallpaper.id, wallpaper.source, wallpaper.fullUrl, wallpaper.thumbnailUrl);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool showSeeMore = _hasMore && _results.length >= 24;
    return RefreshIndicator(
      color: cs.primary,
      backgroundColor: cs.surfaceContainerHigh,
      key: refreshHomeKey,
      onRefresh: refreshList,
      child: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification scrollInfo) {
          if (scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
            unawaited(_requestNextPage());
          }
          return false;
        },
        child: GridView.builder(
          padding: PrismWallGrid.padding.copyWith(top: PrismSpace.xxs, bottom: PrismSpace.bottomBarClearance),
          itemCount: _results.length + (showSeeMore ? 1 : 0),
          gridDelegate: PrismWallGrid.delegate(context),
          itemBuilder: (context, index) {
            if (showSeeMore && index == _results.length) {
              return SeeMoreButton(seeMoreLoader: seeMoreLoader, func: _requestNextPage);
            }
            final FeedItemEntity wallpaper = _results[index];
            return ShakeOnce(
              controller: _shake,
              target: index,
              child: PrismWallTile(
                url: wallpaper.thumbnailUrl,
                heroTag: prismHeroTag(this, index, wallpaper.id),
                semanticLabel: wallpaperSemanticLabel(_authorName(wallpaper)),
                onTap: () => _openWallpaper(wallpaper, index),
                onLongPress: () => _shareWallpaper(wallpaper, index),
              ),
            );
          },
        ),
      ),
    );
  }
}
