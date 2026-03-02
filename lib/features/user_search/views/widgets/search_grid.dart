import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/widgets/animated/loader.dart';
import 'package:Prism/core/widgets/focussedMenu/searchFocusedMenu.dart';
import 'package:Prism/data/pexels/provider/pexelsWithoutProvider.dart' as pData;
import 'package:Prism/data/share/createDynamicLink.dart';
import 'package:Prism/data/wallhaven/provider/wallhavenWithoutProvider.dart' as wData;
import 'package:Prism/features/navigation/views/widgets/inherited_scroll_controller_provider.dart';
import 'package:Prism/features/theme_mode/views/theme_mode_bloc_utils.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/main.dart' as main;
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SearchGrid extends StatefulWidget {
  final String query;
  final String? selectedProvider;
  const SearchGrid({required this.query, required this.selectedProvider});
  @override
  _SearchGridState createState() => _SearchGridState();
}

class _SearchGridState extends State<SearchGrid> with TickerProviderStateMixin {
  AnimationController? _controller;
  late AnimationController shakeController;
  late Animation<Color?> animation;
  int? longTapIndex;
  GlobalKey<RefreshIndicatorState> refreshHomeKey = GlobalKey<RefreshIndicatorState>();

  bool seeMoreLoader = false;
  int _currentPage = 1;

  SearchProviderValue get _providerValue {
    if (widget.selectedProvider == "Pexels") {
      return SearchProviderValue.pexels;
    }
    return SearchProviderValue.wallhaven;
  }

  int get _queryLength => widget.query.trim().length;

  int get _resultCount => widget.selectedProvider == "Pexels" ? pData.wallsPS.length : wData.wallsS.length;

  void _trackResultsLoaded({required int page, required EventResultValue result}) {
    analytics.track(
      SearchResultsLoadedEvent(
        provider: _providerValue,
        queryLength: _queryLength,
        resultCount: _resultCount,
        page: page,
        result: result,
      ),
    );
  }

  Future<bool> _requestPage({required int page}) async {
    analytics.track(SearchPaginationRequestedEvent(provider: _providerValue, queryLength: _queryLength, page: page));
    try {
      if (widget.selectedProvider == "WallHaven") {
        await wData.getWallsbyQueryPage(
          widget.query,
          main.prefs.get('WHcategories') as int?,
          main.prefs.get('WHpurity') as int?,
        );
      } else if (widget.selectedProvider == "Pexels") {
        await pData.getWallsPbyQueryPage(widget.query);
      }
      _trackResultsLoaded(page: page, result: _resultCount > 0 ? EventResultValue.success : EventResultValue.empty);
      return true;
    } catch (error, stackTrace) {
      logger.e('Failed to load search results page.', error: error, stackTrace: stackTrace);
      _trackResultsLoaded(page: page, result: EventResultValue.failure);
      return false;
    }
  }

  Future<void> _requestNextPage() async {
    if (seeMoreLoader) {
      return;
    }
    setState(() {
      seeMoreLoader = true;
    });
    final int nextPage = _currentPage + 1;
    final bool success = await _requestPage(page: nextPage);
    if (!mounted) {
      return;
    }
    setState(() {
      if (success) {
        _currentPage = nextPage;
      }
    });
    Future<void>.delayed(const Duration(seconds: 2)).then((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        seeMoreLoader = false;
      });
    });
  }

  @override
  void initState() {
    super.initState();
    shakeController = AnimationController(duration: const Duration(milliseconds: 300), vsync: this);
    _controller = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);
    animation =
        context.prismModeStyleForWindow(listen: false) == "Dark"
              ? TweenSequence<Color?>([
                  TweenSequenceItem(
                    weight: 1.0,
                    tween: ColorTween(begin: Colors.white10, end: const Color(0x22FFFFFF)),
                  ),
                  TweenSequenceItem(
                    weight: 1.0,
                    tween: ColorTween(begin: const Color(0x22FFFFFF), end: Colors.white10),
                  ),
                ]).animate(_controller!)
              : TweenSequence<Color?>([
                  TweenSequenceItem(
                    weight: 1.0,
                    tween: ColorTween(
                      begin: Colors.black.withValues(alpha: .1),
                      end: Colors.black.withValues(alpha: .14),
                    ),
                  ),
                  TweenSequenceItem(
                    weight: 1.0,
                    tween: ColorTween(
                      begin: Colors.black.withValues(alpha: .14),
                      end: Colors.black.withValues(alpha: .1),
                    ),
                  ),
                ]).animate(_controller!)
          ..addListener(() {
            setState(() {});
          });
    _controller!.repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _trackResultsLoaded(page: 1, result: _resultCount > 0 ? EventResultValue.success : EventResultValue.empty);
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    shakeController.dispose();
    super.dispose();
  }

  Future<void> refreshList() async {
    refreshHomeKey.currentState?.show();
    _currentPage = 1;
    try {
      if (widget.selectedProvider == "WallHaven") {
        wData.wallsS = [];
        await wData.getWallsbyQuery(
          widget.query,
          main.prefs.get('WHcategories') as int?,
          main.prefs.get('WHpurity') as int?,
        );
      } else if (widget.selectedProvider == "Pexels") {
        pData.wallsPS = [];
        await pData.getWallsPbyQuery(widget.query);
      }
      _trackResultsLoaded(page: 1, result: _resultCount > 0 ? EventResultValue.success : EventResultValue.empty);
    } catch (error, stackTrace) {
      logger.e('Failed to refresh search results.', error: error, stackTrace: stackTrace);
      _trackResultsLoaded(page: 1, result: EventResultValue.failure);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Animation<double> offsetAnimation =
        Tween(begin: 0.0, end: 8.0).chain(CurveTween(curve: Curves.easeOutCubic)).animate(shakeController)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              shakeController.reverse();
            }
          });
    final ScrollController? controller = InheritedDataProvider.of(context)!.scrollController;
    return RefreshIndicator(
      backgroundColor: Theme.of(context).primaryColor,
      key: refreshHomeKey,
      onRefresh: refreshList,
      child: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification scrollInfo) {
          if (scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
            if (!seeMoreLoader) {
              unawaited(_requestNextPage());
            }
          }
          return false;
        },
        child: GridView.builder(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(5, 4, 5, 4),
          itemCount: widget.selectedProvider == "WallHaven"
              ? wData.wallsS.isEmpty
                    ? 24
                    : wData.wallsS.length
              : pData.wallsPS.isEmpty
              ? 24
              : pData.wallsPS.length,
          shrinkWrap: true,
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: MediaQuery.of(context).orientation == Orientation.portrait ? 300 : 250,
            childAspectRatio: 0.6625,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemBuilder: (context, index) {
            if (widget.selectedProvider == "WallHaven") {
              if (index == wData.wallsS.length - 1 && index >= 23) {
                return MaterialButton(
                  color: context.prismModeStyleForContext() == "Dark"
                      ? Colors.white10
                      : Colors.black.withValues(alpha: .1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  onPressed: () async {
                    await _requestNextPage();
                  },
                  child: !seeMoreLoader ? const Text("See more") : Loader(),
                );
              }
            } else if (widget.selectedProvider == "Pexels") {
              if (index == pData.wallsPS.length - 1 && index >= 23) {
                return MaterialButton(
                  color: context.prismModeStyleForContext() == "Dark"
                      ? Colors.white10
                      : Colors.black.withValues(alpha: .1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  onPressed: () async {
                    await _requestNextPage();
                  },
                  child: !seeMoreLoader ? const Text("See more") : Loader(),
                );
              }
            }

            return SearchFocusedMenuHolder(
              selectedProvider: widget.selectedProvider,
              query: widget.query,
              index: index,
              child: AnimatedBuilder(
                animation: offsetAnimation,
                builder: (buildContext, child) {
                  if (offsetAnimation.value < 0.0) {
                    logger.d('${offsetAnimation.value + 8.0}');
                  }
                  return Padding(
                    padding: index == longTapIndex
                        ? EdgeInsets.symmetric(vertical: offsetAnimation.value / 2, horizontal: offsetAnimation.value)
                        : EdgeInsets.zero,
                    child: Stack(
                      children: [
                        Container(
                          decoration: widget.selectedProvider == "WallHaven"
                              ? wData.wallsS.isEmpty
                                    ? BoxDecoration(color: animation.value, borderRadius: BorderRadius.circular(20))
                                    : BoxDecoration(
                                        color: animation.value,
                                        borderRadius: BorderRadius.circular(20),
                                        image: DecorationImage(
                                          image: CachedNetworkImageProvider(
                                            wData.wallsS[index].thumbs!["original"].toString(),
                                          ),
                                          fit: BoxFit.cover,
                                        ),
                                      )
                              : pData.wallsPS.isEmpty
                              ? BoxDecoration(color: animation.value, borderRadius: BorderRadius.circular(20))
                              : BoxDecoration(
                                  color: animation.value,
                                  borderRadius: BorderRadius.circular(20),
                                  image: DecorationImage(
                                    image: CachedNetworkImageProvider(pData.wallsPS[index].src!["medium"].toString()),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                        ),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              splashColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
                              highlightColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
                              onTap: () {
                                if (widget.selectedProvider == "WallHaven") {
                                  if (wData.wallsS == []) {
                                  } else {
                                    analytics.track(
                                      SearchResultOpenedEvent(
                                        provider: _providerValue,
                                        itemType: ItemTypeValue.wallpaper,
                                        itemId: wData.wallsS[index].id?.toString() ?? '',
                                        index: index,
                                        queryLength: _queryLength,
                                      ),
                                    );
                                    context.router.push(
                                      WallpaperRoute(
                                        provider: "WallHaven",
                                        index: index,
                                        link: wData.wallsS[index].thumbs!["small"].toString(),
                                      ),
                                    );
                                  }
                                } else if (widget.selectedProvider == "Pexels") {
                                  if (pData.wallsPS == []) {
                                  } else {
                                    analytics.track(
                                      SearchResultOpenedEvent(
                                        provider: _providerValue,
                                        itemType: ItemTypeValue.wallpaper,
                                        itemId: pData.wallsPS[index].id?.toString() ?? '',
                                        index: index,
                                        queryLength: _queryLength,
                                      ),
                                    );
                                    context.router.push(
                                      SearchWallpaperRoute(
                                        selectedProvider: widget.selectedProvider ?? "Pexels",
                                        query: widget.query,
                                        index: index,
                                        link: pData.wallsPS[index].src!["medium"].toString(),
                                      ),
                                    );
                                  }
                                }
                              },
                              onLongPress: () {
                                setState(() {
                                  longTapIndex = index;
                                });
                                shakeController.forward(from: 0.0);
                                if (widget.selectedProvider == "WallHaven") {
                                  if (wData.wallsS == []) {
                                  } else {
                                    HapticFeedback.vibrate();
                                    createDynamicLink(
                                      wData.wallsS[index].id!,
                                      "WallHaven",
                                      wData.wallsS[index].path,
                                      wData.wallsS[index].thumbs!["original"].toString(),
                                    );
                                  }
                                } else if (widget.selectedProvider == "Pexels") {
                                  if (wData.wallsS == []) {
                                  } else {
                                    HapticFeedback.vibrate();
                                    createDynamicLink(
                                      pData.wallsPS[index].id!,
                                      "Pexels",
                                      pData.wallsPS[index].src!["original"].toString(),
                                      pData.wallsPS[index].src!["medium"].toString(),
                                    );
                                  }
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
