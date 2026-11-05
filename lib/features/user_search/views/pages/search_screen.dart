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
  bool isSubmitted = false;
  late bool _showAi;

  void _onFeedSettingsChanged() {
    final bool showAi = AiContentFilter.showsAi(_settingsLocal);
    if (showAi == _showAi) return;
    _showAi = showAi;
    if (mounted && isSubmitted) _triggerSearch(_submittedQuery, sourceContext: 'search_ai_setting');
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
    if (_filters.color != null) CoinsService.instance.reportQuestEvent(QuestEvent.colourSearch);
    final String searchId = AnalyticsCorrelation.newId();
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
    setState(() {
      isSubmitted = false;
      _searchId = null;
      _search = null;
      _photo = null;
      if (_submittedQuery.isEmpty) {
        _filters = _filters.copyWith(clearColor: true, depthOnly: false, spatialOnly: false);
      }
    });
    _discoveryBloc.add(const SearchDiscoveryEvent.fetchRequested());
  }

  Future<void> _openFilters() async {
    final SearchFilters? picked = await showSearchFilterSheet(context, _filters);
    if (picked == null || picked == _filters || !mounted) return;
    setState(() => _filters = picked);
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
    final PhotoSearchService photos = getIt<PhotoSearchService>();
    final bool signedIn = app_state.prismUser.loggedIn;
    if (signedIn && !_settingsLocal.get<bool>(PersistenceKeys.photoSearchPrivacySeen, defaultValue: false)) {
      final bool accepted = await showPrismConfirm(
        context,
        title: context.l10n.searchByPhoto,
        message: context.l10n.searchPhotoPrivacy,
        confirmLabel: context.l10n.searchPhotoChoose,
      );
      if (!accepted || !mounted) return;
      await _settingsLocal.set(PersistenceKeys.photoSearchPrivacySeen, true);
    }
    final Uint8List? original = await photos.pick();
    if (original == null || !mounted) return;
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
      _filters = _filters.copyWith(clearColor: true, depthOnly: false, spatialOnly: false);
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
    setState(() => _photo = photo);
    final result = await getIt<WallpaperSearchService>().searchByPhoto(photo, filters: _filters);
    if (mounted && _searchId == searchId) setState(() => _photoPageQuery = result.query);
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

  void _clearColor() {
    setState(() => _filters = _filters.copyWith(clearColor: true));
    if (_submittedQuery.isEmpty && !_filters.listsWithoutQuery) {
      _backToDiscover();
    } else {
      _triggerSearch(_submittedQuery);
    }
  }

  void _clearDepth() {
    setState(() => _filters = _filters.copyWith(depthOnly: false));
    if (_submittedQuery.isEmpty && !_filters.listsWithoutQuery) {
      _backToDiscover();
    } else {
      _triggerSearch(_submittedQuery);
    }
  }

  void _clearSpatial() {
    setState(() => _filters = _filters.copyWith(spatialOnly: false));
    if (_submittedQuery.isEmpty && !_filters.listsWithoutQuery) {
      _backToDiscover();
    } else {
      _triggerSearch(_submittedQuery);
    }
  }

  Future<void> _clearRecents() async {
    await _recents.clear();
    if (mounted) setState(() => _recentSearches = const <String>[]);
  }

  void _resetFilters() {
    setState(() => _filters = const SearchFilters());
    if (_submittedQuery.isEmpty) {
      _backToDiscover();
    } else {
      _triggerSearch(_submittedQuery);
    }
  }

  /// Runs a search that another screen asked for, for example a tag chip on the wallpaper detail screen.
  void _consumePendingTag() {
    final String? tag = pendingTagSearch.value;
    if (tag == null || !mounted) return;
    pendingTagSearch.value = null;
    searchController.text = tag;
    _triggerSearch(tag, sourceContext: 'wallpaper_tag', fromSuggestion: true);
  }

  @override
  void initState() {
    super.initState();
    _showAi = AiContentFilter.showsAi(_settingsLocal);
    personalizedFeedSettingsRevision.addListener(_onFeedSettingsChanged);
    pendingTagSearch.addListener(_consumePendingTag);
    if (pendingTagSearch.value != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _consumePendingTag());
    }
  }

  @override
  void dispose() {
    personalizedFeedSettingsRevision.removeListener(_onFeedSettingsChanged);
    pendingTagSearch.removeListener(_consumePendingTag);
    searchController.dispose();
    _focus.dispose();
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
              const SizedBox(width: PrismSpace.xxs),
              PrismIconButton(
                icon: Icons.image_search_rounded,
                tooltip: context.l10n.searchByPhoto,
                onPressed: () => unawaited(_searchByPhoto()),
              ),
              Badge(
                isLabelVisible: _filters != const SearchFilters(),
                smallSize: 8,
                alignment: AlignmentDirectional.topEnd,
                offset: const Offset(-8, 8),
                child: PrismIconButton(
                  icon: Icons.tune_rounded,
                  tooltip: context.l10n.accountFilters,
                  onPressed: _openFilters,
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
              : _filters.copyWith(color: photo.topColor, depthOnly: false, spatialOnly: false),
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
                      Padding(
                        padding: const EdgeInsets.fromLTRB(PrismSpace.page, 0, PrismSpace.page, PrismSpace.xs),
                        child: Row(
                          children: <Widget>[
                            if (_submittedQuery.isNotEmpty)
                              Expanded(
                                child: Text(
                                  context.l10n.accountResultsForQuery(_submittedQuery),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: PrismTextStyles.caption(context),
                                ),
                              ),
                            if (_filters.color != null)
                              Tooltip(
                                message: context.l10n.accountClearColour,
                                child: PrismChip(
                                  label: prismPaletteColorDisplayName(_filters.color!, context.l10n),
                                  selected: true,
                                  leading: _ColourDot(_filters.color!.color),
                                  onTap: _clearColor,
                                ),
                              ),
                            if (_filters.color != null && _filters.depthOnly) const SizedBox(width: PrismSpace.xs),
                            if (_filters.depthOnly)
                              Tooltip(
                                message: context.l10n.accountClearDepthEffect,
                                child: PrismChip(
                                  label: context.l10n.accountDepthEffect,
                                  selected: true,
                                  onTap: _clearDepth,
                                ),
                              ),
                            if (_filters.color != null && _filters.spatialOnly) const SizedBox(width: PrismSpace.xs),
                            if (_filters.spatialOnly)
                              Tooltip(
                                message: context.l10n.accountClearSpatialScene,
                                child: PrismChip(
                                  label: context.l10n.accountSpatialScene,
                                  selected: true,
                                  onTap: _clearSpatial,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Expanded(child: _results(context)),
                    ],
                  )
                : SearchDiscoveryWidget(
                    header: _header(context),
                    tags: curatedSearchTags,
                    selectedTag: searchController.text,
                    recentSearches: _recentSearches,
                    onClearRecents: () => unawaited(_clearRecents()),
                    onColorPressed: _searchByColor,
                    onDepthPressed: showDepthEffectUi ? _searchByDepth : null,
                    onSpatialPressed: _searchBySpatial,
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
