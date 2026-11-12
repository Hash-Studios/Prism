import 'dart:async';
import 'dart:typed_data';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/analytics_correlation.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/color/prism_palette.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/personalization/personalized_feed_settings.dart';
import 'package:Prism/core/platform/wallpaper_capability.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/wallpaper/ai_content_filter.dart';
import 'package:Prism/core/widgets/home/refreshable_glint_state.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/hints/domain/feature_hint.dart';
import 'package:Prism/features/hints/views/feature_hint.dart';
import 'package:Prism/features/user_search/biz/bloc/search_discovery_bloc.j.dart';
import 'package:Prism/features/user_search/data/photo_search_service.dart';
import 'package:Prism/features/user_search/data/recent_searches_store.dart';
import 'package:Prism/features/user_search/data/search_filters.dart';
import 'package:Prism/features/user_search/data/search_tags.dart';
import 'package:Prism/features/user_search/data/wallpaper_search_service.dart';
import 'package:Prism/features/user_search/domain/entities/photo_query.dart';
import 'package:Prism/features/user_search/views/widgets/photo_search_chip.dart';
import 'package:Prism/features/user_search/views/widgets/prism_search_field.dart';
import 'package:Prism/features/user_search/views/widgets/search_discovery_widget.dart';
import 'package:Prism/features/user_search/views/widgets/search_filter_sheet.dart';
import 'package:Prism/features/user_search/views/widgets/search_grid.dart';
import 'package:Prism/features/user_search/views/widgets/search_request_prompt.dart';
import 'package:Prism/features/wall_requests/views/widgets/wall_request_sheet.dart';
import 'package:Prism/features/wallpaper_detail/biz/tag_search_launcher.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

@RoutePage()
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController searchController = TextEditingController();
  final FocusNode _focus = FocusNode();
  final GlobalKey _fieldKey = GlobalKey();
  late final SettingsLocalDataSource _settingsLocal = getIt<SettingsLocalDataSource>();
  late final RecentSearchesStore _recents = RecentSearchesStore(_settingsLocal);
  late List<String> _recentSearches = _recents.read();
  // One bloc for the screen, so "Trending now" does not reload each time the user returns from a search.
  late final SearchDiscoveryBloc _discoveryBloc = getIt<SearchDiscoveryBloc>()
    ..add(const SearchDiscoveryEvent.fetchRequested());
  Future<WallpaperSearchPage>? _search;
  String _submittedQuery = '';
  String? _searchId;
  SearchFilters _filters = const SearchFilters();

  /// The picked photo while its results are on screen. Its results replace the text and colour search.
  PhotoQuery? _photo;

  /// The text query of a photo search page, which the grid uses for the next pages.
  String _photoPageQuery = '';
  int _photoResultGeneration = 0;
  int _photoPickGeneration = 0;
  bool _photoPending = false;
  bool isSubmitted = false;
  late bool _showAi;

  void _onFeedSettingsChanged() {
    final bool showAi = AiContentFilter.showsAi(_settingsLocal);
    if (showAi == _showAi) return;
    _showAi = showAi;
    if (!mounted || !isSubmitted) return;
    if (_photo case final PhotoQuery photo) {
      _showPhotoResults(photo, _searchId ?? AnalyticsCorrelation.newId());
    } else if (!_photoPending) {
      _triggerSearch(_submittedQuery, sourceContext: 'search_ai_setting');
    }
  }

  int _queryWordCount(String query) {
    return query.trim().split(RegExp(r'\s+')).where((segment) => segment.trim().isNotEmpty).length;
  }

  void _trackSearchSubmitted({
    required SearchProviderValue provider,
    required String query,
    required bool fromSuggestion,
    required String sourceContext,
    required String searchId,
  }) {
    final String trimmedQuery = query.trim();
    analytics.track(
      SearchSubmittedEvent(
        provider: provider,
        queryLength: trimmedQuery.length,
        queryWordCount: _queryWordCount(trimmedQuery),
        sourceContext: sourceContext,
        fromSuggestion: fromSuggestion,
        searchId: searchId,
      ),
    );
  }

  void _triggerSearch(String query, {String? sourceContext, bool fromSuggestion = false}) {
    final String trimmed = query.trim();
    if (trimmed.isEmpty && !_filters.listsWithoutQuery) return;
    _photoResultGeneration++;
    _photoPickGeneration++;
    _photoPending = false;
    if (_filters.color != null) CoinsService.instance.reportQuestEvent(QuestEvent.colourSearch);
    final String searchId = AnalyticsCorrelation.newId();
    final List<String> kinds = <String>[
      for (final PrismWallKind kind in PrismWallKind.values)
        if (_filters.kinds.contains(kind)) kind.wire,
    ];
    final Future<WallpaperSearchPage> search = getIt<WallpaperSearchService>().search(trimmed, filters: _filters)
      ..ignore();
    setState(() {
      isSubmitted = true;
      _submittedQuery = trimmed;
      _searchId = searchId;
      _search = search;
      _photo = null;
    });
    _trackSearchSubmitted(
      provider: SearchProviderValue.auto,
      query: trimmed,
      fromSuggestion: fromSuggestion,
      sourceContext: sourceContext ?? 'search_retry_or_filter',
      searchId: searchId,
    );
    unawaited(
      search.then(
        (page) {
          if (!mounted || _searchId != searchId) {
            unawaited(
              analytics.track(
                SearchResultsLoadedEvent(
                  provider: page.provider,
                  queryLength: trimmed.length,
                  resultCount: 0,
                  page: 1,
                  result: EventResultValue.cancelled,
                  searchId: searchId,
                  reason: 'superseded',
                ),
              ),
            );
            return;
          }
          final int count = page.results.length + page.prismResults.length;
          if (kinds.isNotEmpty) {
            unawaited(analytics.track(SearchKindResultsEvent(kinds: kinds, resultCount: count, searchId: searchId)));
          }
          unawaited(
            analytics.track(
              SearchResultsLoadedEvent(
                provider: page.provider,
                queryLength: trimmed.length,
                resultCount: count,
                page: 1,
                result: count == 0 ? EventResultValue.empty : EventResultValue.success,
                searchId: searchId,
              ),
            ),
          );
        },
        onError: (Object _) {
          if (!mounted || _searchId != searchId) {
            unawaited(
              analytics.track(
                SearchResultsLoadedEvent(
                  provider: SearchProviderValue.auto,
                  queryLength: trimmed.length,
                  resultCount: 0,
                  page: 1,
                  result: EventResultValue.cancelled,
                  searchId: searchId,
                  reason: 'superseded',
                ),
              ),
            );
            return;
          }
          unawaited(
            analytics.track(
              SearchResultsLoadedEvent(
                provider: SearchProviderValue.auto,
                queryLength: trimmed.length,
                resultCount: 0,
                page: 1,
                result: EventResultValue.failure,
                searchId: searchId,
              ),
            ),
          );
        },
      ),
    );
    if (trimmed.isNotEmpty) {
      unawaited(_recents.add(trimmed).then((recents) => mounted ? setState(() => _recentSearches = recents) : null));
    }
  }

  void _backToDiscover() {
    _photoResultGeneration++;
    _photoPickGeneration++;
    _photoPending = false;
    setState(() {
      isSubmitted = false;
      _searchId = null;
      _search = null;
      _photo = null;
      if (_submittedQuery.isEmpty) {
        _filters = _filters.copyWith(
          clearColor: true,
          depthOnly: false,
          spatialOnly: false,
          kinds: const <PrismWallKind>{},
        );
      }
    });
    _discoveryBloc.add(const SearchDiscoveryEvent.fetchRequested());
  }

  Future<void> _openFilters() async {
    final SearchFilters? picked = await showSearchFilterSheet(context, _filters);
    if (picked == null || picked == _filters || !mounted) return;
    setState(() => _filters = picked);
    analytics.track(SearchFilterAppliedEvent(filters: picked.activeNames));
    if (_photoPending && _photo == null) return;
    if (_photo case final PhotoQuery photo) {
      _showPhotoResults(photo, _searchId ?? AnalyticsCorrelation.newId());
      return;
    }
    final String query = (isSubmitted ? _submittedQuery : searchController.text).trim();
    if (query.isEmpty && !picked.listsWithoutQuery) {
      if (isSubmitted) _backToDiscover();
    } else if (isSubmitted || query.isEmpty) {
      _triggerSearch(query);
    }
  }

  Future<void> _searchByPhoto() async {
    final int pickGeneration = ++_photoPickGeneration;
    final PhotoSearchService photos = getIt<PhotoSearchService>();
    final bool signedIn = app_state.prismUser.loggedIn;
    if (signedIn && !_settingsLocal.get<bool>(PersistenceKeys.photoSearchPrivacySeen, defaultValue: false)) {
      final bool accepted = await showPrismConfirm(
        context,
        title: context.l10n.searchByPhoto,
        message: context.l10n.searchPhotoPrivacy,
        confirmLabel: context.l10n.searchPhotoChoose,
      );
      if (!accepted || !mounted || pickGeneration != _photoPickGeneration) return;
      await _settingsLocal.set(PersistenceKeys.photoSearchPrivacySeen, true);
    }
    final Uint8List? original;
    try {
      original = await photos.pick();
    } catch (_) {
      if (mounted && pickGeneration == _photoPickGeneration) {
        toasts.error(context.l10n.searchPhotoCouldNotOpen);
      }
      return;
    }
    if (original == null || !mounted || pickGeneration != _photoPickGeneration) return;
    final String searchId = AnalyticsCorrelation.newId();
    analytics.track(PhotoSearchStartedEvent(signedIn: signedIn, searchId: searchId));
    searchController.clear();
    _focus.unfocus();
    final Future<WallpaperSearchPage> search = _readPhoto(photos, original, signedIn, searchId)..ignore();
    setState(() {
      isSubmitted = true;
      _submittedQuery = '';
      _searchId = searchId;
      _search = search;
      _photo = null;
      _photoPending = true;
      _filters = _filters.copyWith(
        clearColor: true,
        depthOnly: false,
        spatialOnly: false,
        source: SearchSource.all,
        kinds: const <PrismWallKind>{},
      );
    });
  }

  Future<WallpaperSearchPage> _readPhoto(
    PhotoSearchService photos,
    Uint8List original,
    bool signedIn,
    String searchId,
  ) async {
    final PhotoQuery photo;
    try {
      photo = await photos.queryFor(original, signedIn: signedIn);
    } catch (_) {
      if (mounted && _searchId == searchId) {
        _photoPending = false;
        toasts.error(context.l10n.searchPhotoCouldNotOpen);
        _backToDiscover();
      }
      rethrow;
    }
    switch (photo.labelsStatus) {
      case PhotoLabelsStatus.found:
        analytics.track(PhotoSearchLabelsReturnedEvent(labelCount: photo.labels.length, searchId: searchId));
      case PhotoLabelsStatus.capped:
        analytics.track(PhotoSearchLabelsCappedEvent(searchId: searchId));
      case PhotoLabelsStatus.guest || PhotoLabelsStatus.unavailable:
        break;
    }
    if (!mounted || _searchId != searchId) throw StateError('A newer search replaced this photo search.');
    _photoPending = false;
    return _photoResults(photo, searchId);
  }

  /// Shows the results for [photo] with the current filters.
  void _showPhotoResults(PhotoQuery photo, String searchId) {
    final Future<WallpaperSearchPage> search = _photoResults(photo, searchId)..ignore();
    setState(() {
      isSubmitted = true;
      _searchId = searchId;
      _search = search;
    });
  }

  Future<WallpaperSearchPage> _photoResults(PhotoQuery photo, String searchId) async {
    final int resultGeneration = ++_photoResultGeneration;
    if (mounted && _searchId == searchId && resultGeneration == _photoResultGeneration) {
      setState(() => _photo = photo);
    }
    final result = await getIt<WallpaperSearchService>().searchByPhoto(photo, filters: _filters);
    if (mounted && _searchId == searchId && resultGeneration == _photoResultGeneration) {
      setState(() => _photoPageQuery = result.query);
    }
    return result.page;
  }

  void _retrySearch() {
    if (_photo case final PhotoQuery photo) {
      _showPhotoResults(photo, AnalyticsCorrelation.newId());
    } else {
      _triggerSearch(_submittedQuery);
    }
  }

  void _searchByColor(PrismPaletteColor color) {
    searchController.clear();
    setState(() => _filters = _filters.copyWith(color: color));
    _triggerSearch('', sourceContext: 'search_color');
  }

  void _searchByDepth() {
    searchController.clear();
    setState(() => _filters = _filters.copyWith(depthOnly: true, spatialOnly: false));
    _triggerSearch('', sourceContext: 'search_depth');
  }

  void _searchBySpatial() {
    searchController.clear();
    setState(() => _filters = _filters.copyWith(spatialOnly: true, depthOnly: false));
    _triggerSearch('', sourceContext: 'search_spatial');
  }

  void _searchLiveWalls() {
    searchController.clear();
    setState(() => _filters = _filters.copyWith(kinds: const <PrismWallKind>{PrismWallKind.live}));
    _triggerSearch('', sourceContext: 'search_live');
  }

  /// Applies [next] to the search on screen. A browse with nothing left to list goes back to discovery.
  void _applyFilters(SearchFilters next) {
    setState(() => _filters = next);
    if (_submittedQuery.isEmpty && !_filters.listsWithoutQuery) {
      _backToDiscover();
    } else {
      _triggerSearch(_submittedQuery);
    }
  }

  void _clearColor() => _applyFilters(_filters.copyWith(clearColor: true));

  void _clearDepth() => _applyFilters(_filters.copyWith(depthOnly: false));

  void _clearSpatial() => _applyFilters(_filters.copyWith(spatialOnly: false));

  Future<void> _clearRecents() async {
    await _recents.clear();
    if (mounted) setState(() => _recentSearches = const <String>[]);
  }

  void _resetFilters() => _applyFilters(const SearchFilters());

  /// Runs a search that another screen or a link asked for, for example a tag chip on the wallpaper detail screen.
  /// A link brings its own filters. A link with no query and no filter to list sets the filters and stays here.
  void _consumePendingSearch() {
    final SearchRequest? request = pendingSearch.value;
    if (request == null || !mounted) return;
    pendingSearch.value = null;
    searchController.text = request.query;
    final SearchFilters? filters = request.filters;
    if (filters == null) {
      _triggerSearch(request.query, sourceContext: 'wallpaper_tag', fromSuggestion: true);
      return;
    }
    if (request.query.isEmpty && !filters.listsWithoutQuery) {
      if (isSubmitted) _backToDiscover();
      setState(() => _filters = filters);
      return;
    }
    setState(() => _filters = filters);
    _triggerSearch(request.query, sourceContext: 'search_link');
  }

  void _onFocusChanged() => setState(() {});

  /// The Cancel button beside the focused field: clears the query, closes the keyboard and returns to discovery.
  void _cancelSearch() {
    searchController.clear();
    _focus.unfocus();
    if (isSubmitted) _backToDiscover();
  }

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChanged);
    _showAi = AiContentFilter.showsAi(_settingsLocal);
    personalizedFeedSettingsRevision.addListener(_onFeedSettingsChanged);
    pendingSearch.addListener(_consumePendingSearch);
    if (pendingSearch.value != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _consumePendingSearch());
    }
  }

  @override
  void dispose() {
    personalizedFeedSettingsRevision.removeListener(_onFeedSettingsChanged);
    pendingSearch.removeListener(_consumePendingSearch);
    searchController.dispose();
    _focus
      ..removeListener(_onFocusChanged)
      ..dispose();
    unawaited(_discoveryBloc.close());
    super.dispose();
  }

  Widget _header(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        PrismHeader(title: context.l10n.accountSearch, showBack: false),
        Padding(
          padding: const EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.xxs, PrismSpace.xs, PrismSpace.sm),
          child: Row(
            children: <Widget>[
              Expanded(
                child: PrismSearchField(
                  key: _fieldKey,
                  controller: searchController,
                  focusNode: _focus,
                  hint: context.l10n.accountSearchWallpapers,
                  onChanged: (text) {
                    if (text.trim().isEmpty && isSubmitted) {
                      _backToDiscover();
                    } else {
                      setState(() {});
                    }
                  },
                  onSubmitted: (text) {
                    final String query = text.trim();
                    if (query.isEmpty) return;
                    _triggerSearch(query, sourceContext: 'search_textfield');
                  },
                ),
              ),
              // Like iOS: on focus the photo and filter buttons fade and slide out in the first 100 ms, then Cancel
              // slides in over the next 120 ms, so the two never overlap. The field resizes with them. Unfocus runs
              // the same order the other way.
              AnimatedSize(
                duration: context.motion(PrismDurations.fast),
                curve: PrismCurves.enter,
                alignment: AlignmentDirectional.centerStart,
                child: AnimatedSwitcher(
                  duration: context.motion(const Duration(milliseconds: 220)),
                  reverseDuration: context.motion(const Duration(milliseconds: 100)),
                  switchInCurve: const Interval(100 / 220, 1, curve: PrismCurves.enter),
                  switchOutCurve: PrismCurves.exitReverse,
                  layoutBuilder: (current, previous) =>
                      Stack(alignment: AlignmentDirectional.centerEnd, children: <Widget>[...previous, ?current]),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(begin: const Offset(0.4, 0), end: Offset.zero).animate(animation),
                      child: child,
                    ),
                  ),
                  child: _focus.hasFocus
                      ? Padding(
                          key: const ValueKey<String>('cancel'),
                          padding: const EdgeInsetsDirectional.only(start: PrismSpace.xxs, end: PrismSpace.xs),
                          child: PrismButton(
                            label: context.l10n.accountCancel,
                            variant: PrismButtonVariant.ghost,
                            size: PrismButtonSize.compact,
                            onPressed: _cancelSearch,
                          ),
                        )
                      : Row(
                          key: const ValueKey<String>('actions'),
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const SizedBox(width: PrismSpace.xxs),
                            FeatureHint(
                              id: HintId.photoSearch,
                              child: PrismIconButton(
                                icon: Icons.image_search_rounded,
                                tooltip: context.l10n.searchByPhoto,
                                onPressed: () => unawaited(_searchByPhoto()),
                              ),
                            ),
                            // The count grows with the text size and clips at the screen edge, while the icon does not.
                            MediaQuery.withClampedTextScaling(
                              maxScaleFactor: 1.5,
                              child: Badge.count(
                                count: _filters.activeNames.length,
                                isLabelVisible: _filters.activeNames.isNotEmpty,
                                alignment: AlignmentDirectional.topEnd,
                                offset: const Offset(-10, 4),
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                textColor: Theme.of(context).colorScheme.onPrimary,
                                child: PrismIconButton(
                                  icon: Icons.tune_rounded,
                                  tooltip: context.l10n.searchFiltersCount(_filters.activeNames.length),
                                  onPressed: _openFilters,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _results(BuildContext context) {
    return FutureBuilder<WallpaperSearchPage>(
      future: _search,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LoadingCards();
        }
        if (snapshot.hasError) {
          return RefreshableGlintState(
            kind: GlintStateKind.error,
            title: context.l10n.accountCouldNotSearchRightNow,
            body: context.l10n.accountCheckConnectionTryAgain,
            actionLabel: context.l10n.accountTryAgain,
            onAction: _retrySearch,
            onRefresh: () async => _retrySearch(),
          );
        }
        final WallpaperSearchPage? page = snapshot.data;
        if (page == null) {
          return const LoadingCards();
        }
        final PhotoQuery? photo = _photo;
        if (page.results.isEmpty && page.prismResults.isEmpty && photo != null) {
          return GlintState(
            kind: GlintStateKind.empty,
            title: context.l10n.searchPhotoNoMatches,
            body: context.l10n.searchPhotoNoMatchesBody,
            actionLabel: context.l10n.searchPhotoChooseAnother,
            onAction: () => unawaited(_searchByPhoto()),
          );
        }
        if (page.results.isEmpty && page.prismResults.isEmpty) {
          final bool filtered = _filters != const SearchFilters();
          final List<String> activeFilters = <String>[
            if (_filters.color != null) _filters.color!.name.toLowerCase(),
            if (_filters.depthOnly) context.l10n.accountDepthEffect,
            if (_filters.spatialOnly) context.l10n.accountSpatialScene,
            for (final PrismWallKind kind in PrismWallKind.values)
              if (_filters.kinds.contains(kind)) prismWallKindLabel(context.l10n, kind),
            if (_filters.source == SearchSource.prism) context.l10n.searchFilterPrismOnly,
          ];
          final String emptyTitle = _submittedQuery.isNotEmpty
              ? filtered
                    ? context.l10n.accountNoWallpapersForQueryWithFilters(_submittedQuery)
                    : context.l10n.accountNoWallpapersFoundForQuery(_submittedQuery)
              : filtered
              ? context.l10n.accountNoWallpapersForFilters(activeFilters.join(' '))
              : context.l10n.accountNoWallpapersFound;
          if (!filtered && _submittedQuery.isNotEmpty) {
            return GlintState(
              kind: GlintStateKind.empty,
              title: emptyTitle,
              body: context.l10n.searchRequestPrompt,
              actionLabel: context.l10n.searchRequestAction,
              onAction: () => unawaited(
                showWallRequestSheet(context, source: WallRequestSourceValue.search, initialText: _submittedQuery),
              ),
            );
          }
          return GlintState(
            kind: GlintStateKind.empty,
            title: emptyTitle,
            body: filtered ? context.l10n.accountTryFewerFilters : context.l10n.accountTryShorterOrDifferentWord,
            actionLabel: filtered ? context.l10n.accountResetFilters : null,
            onAction: filtered ? _resetFilters : null,
          );
        }
        return SearchGrid(
          key: ValueKey<Future<WallpaperSearchPage>?>(_search),
          query: photo == null ? _submittedQuery : _photoPageQuery,
          searchId: _searchId,
          trackInitialResults: false,
          provider: page.provider,
          initialResults: page.results,
          prismResults: page.prismResults,
          filters: photo == null
              ? _filters
              : _filters.copyWith(
                  color: photo.topColor,
                  depthOnly: false,
                  spatialOnly: false,
                  source: SearchSource.all,
                  kinds: const <PrismWallKind>{},
                ),
          isLocal: page.isLocal,
          fromPhoto: photo != null,
          footer: photo == null && _submittedQuery.isNotEmpty && page.results.length + page.prismResults.length <= 5
              ? SearchRequestPrompt(query: _submittedQuery)
              : null,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !isSubmitted,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _backToDiscover();
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: SafeArea(
          bottom: false,
          child: BlocProvider<SearchDiscoveryBloc>.value(
            value: _discoveryBloc,
            child: isSubmitted
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _header(context),
                      AnimatedSwitcher(
                        duration: context.motion(PrismDurations.fast),
                        switchInCurve: PrismCurves.enter,
                        switchOutCurve: PrismCurves.exitReverse,
                        child: _photo == null
                            ? const SizedBox.shrink()
                            : Padding(
                                key: ValueKey<PhotoQuery>(_photo!),
                                padding: const EdgeInsets.fromLTRB(PrismSpace.page, 0, PrismSpace.page, PrismSpace.sm),
                                child: PhotoSearchChip(photo: _photo!, onClear: _backToDiscover),
                              ),
                      ),
                      _ActiveFilters(
                        filters: _filters,
                        onClearColor: _clearColor,
                        onClearDepth: _clearDepth,
                        onClearSpatial: _clearSpatial,
                        onChanged: _applyFilters,
                        onClearAll: _resetFilters,
                      ),
                      Expanded(child: _results(context)),
                    ],
                  )
                : SearchDiscoveryWidget(
                    header: _header(context),
                    dimmed: _focus.hasFocus,
                    tags: curatedSearchTags,
                    selectedTag: searchController.text,
                    recentSearches: _recentSearches,
                    onClearRecents: () => unawaited(_clearRecents()),
                    onColorPressed: _searchByColor,
                    onDepthPressed: showDepthEffectUi ? _searchByDepth : null,
                    onSpatialPressed: _searchBySpatial,
                    onLiveWallsPressed: _searchLiveWalls,
                    onRecentPressed: (query) {
                      searchController.text = query;
                      _triggerSearch(query, sourceContext: 'search_recent', fromSuggestion: true);
                    },
                    onTagPressed: (tag) {
                      analytics.track(
                        SearchTagSelectedEvent(provider: SearchProviderValue.wallhaven, tag: tag.toLowerCase()),
                      );
                      searchController.text = tag;
                      _triggerSearch(tag, sourceContext: 'search_tag', fromSuggestion: true);
                    },
                  ),
          ),
        ),
      ),
    );
  }
}

/// The filters that are on, as chips. A tap on a chip removes that filter. Clear all turns every filter off. With a
/// kind filter on, one line says why only Prism walls show.
class _ActiveFilters extends StatelessWidget {
  const _ActiveFilters({
    required this.filters,
    required this.onClearColor,
    required this.onClearDepth,
    required this.onClearSpatial,
    required this.onChanged,
    required this.onClearAll,
  });

  final SearchFilters filters;
  final VoidCallback onClearColor;
  final VoidCallback onClearDepth;
  final VoidCallback onClearSpatial;
  final ValueChanged<SearchFilters> onChanged;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    Widget removable(String label, VoidCallback onTap) => Tooltip(
      message: l10n.searchRemoveFilter(label),
      child: PrismChip(label: label, selected: true, onTap: onTap),
    );
    final List<Widget> chips = <Widget>[
      if (filters.color case final PrismPaletteColor color)
        Tooltip(
          message: l10n.accountClearColour,
          child: PrismChip(
            label: prismPaletteColorDisplayName(color, l10n),
            selected: true,
            leading: _ColourDot(color.color),
            onTap: onClearColor,
          ),
        ),
      if (filters.depthOnly)
        Tooltip(
          message: l10n.accountClearDepthEffect,
          child: PrismChip(label: l10n.accountDepthEffect, selected: true, onTap: onClearDepth),
        ),
      if (filters.spatialOnly)
        Tooltip(
          message: l10n.accountClearSpatialScene,
          child: PrismChip(label: l10n.accountSpatialScene, selected: true, onTap: onClearSpatial),
        ),
      for (final PrismWallKind kind in PrismWallKind.values)
        if (filters.kinds.contains(kind))
          removable(
            prismWallKindLabel(l10n, kind),
            () => onChanged(filters.copyWith(kinds: <PrismWallKind>{...filters.kinds}..remove(kind))),
          ),
      if (filters.source == SearchSource.prism)
        removable(l10n.searchFilterPrismOnly, () => onChanged(filters.copyWith(source: SearchSource.all))),
    ];
    if (filters.activeNames.isEmpty) return const SizedBox.shrink();
    // At large text the chips and the note can be taller than the screen. They scroll in at most a third of it, so
    // the results keep the rest.
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height / 3),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(PrismSpace.page, 0, PrismSpace.page, PrismSpace.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: PrismSpace.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                ...chips,
                PrismButton(
                  label: l10n.searchFilterClearAll,
                  variant: PrismButtonVariant.ghost,
                  size: PrismButtonSize.compact,
                  onPressed: onClearAll,
                ),
              ],
            ),
            if (filters.kinds.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: PrismSpace.xxs),
                child: Text(l10n.searchKindsPrismOnlyNote, style: PrismTextStyles.caption(context)),
              ),
          ],
        ),
      ),
    );
  }
}

/// A small round colour sample, used in the active colour chip.
class _ColourDot extends StatelessWidget {
  const _ColourDot(this.color);

  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.4)),
      ),
      child: const SizedBox(width: 14, height: 14),
    );
  }
}
