import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/color/prism_palette.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/widgets/home/refreshable_glint_state.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/user_search/biz/bloc/search_discovery_bloc.j.dart';
import 'package:Prism/features/user_search/data/recent_searches_store.dart';
import 'package:Prism/features/user_search/data/search_filters.dart';
import 'package:Prism/features/user_search/data/search_tags.dart';
import 'package:Prism/features/user_search/data/wallpaper_search_service.dart';
import 'package:Prism/features/user_search/views/widgets/prism_search_field.dart';
import 'package:Prism/features/user_search/views/widgets/search_discovery_widget.dart';
import 'package:Prism/features/user_search/views/widgets/search_filter_sheet.dart';
import 'package:Prism/features/user_search/views/widgets/search_grid.dart';
import 'package:Prism/features/wallpaper_detail/biz/tag_search_launcher.dart';
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
  late final RecentSearchesStore _recents = RecentSearchesStore(getIt<SettingsLocalDataSource>());
  late List<String> _recentSearches = _recents.read();
  // One bloc for the screen, so "Trending now" does not reload each time the user returns from a search.
  late final SearchDiscoveryBloc _discoveryBloc = getIt<SearchDiscoveryBloc>()
    ..add(const SearchDiscoveryEvent.fetchRequested());
  Future<WallpaperSearchPage>? _search;
  String _submittedQuery = '';
  SearchFilters _filters = const SearchFilters();
  bool isSubmitted = false;

  int _queryWordCount(String query) {
    return query.trim().split(RegExp(r'\s+')).where((segment) => segment.trim().isNotEmpty).length;
  }

  void _trackSearchSubmitted({
    required SearchProviderValue provider,
    required String query,
    required bool fromSuggestion,
    required String sourceContext,
  }) {
    final String trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) return;
    analytics.track(
      SearchSubmittedEvent(
        provider: provider,
        queryLength: trimmedQuery.length,
        queryWordCount: _queryWordCount(trimmedQuery),
        sourceContext: sourceContext,
        fromSuggestion: fromSuggestion,
      ),
    );
  }

  void _triggerSearch(String query, {String? sourceContext, bool fromSuggestion = false}) {
    final String trimmed = query.trim();
    if (trimmed.isEmpty && _filters.color == null) return;
    if (_filters.color != null) CoinsService.instance.reportQuestEvent(QuestEvent.colourSearch);
    final Future<WallpaperSearchPage> search = getIt<WallpaperSearchService>().search(trimmed, filters: _filters)
      ..ignore();
    setState(() {
      isSubmitted = true;
      _submittedQuery = trimmed;
      _search = search;
    });
    if (sourceContext != null) {
      unawaited(
        search.then(
          (page) => _trackSearchSubmitted(
            provider: page.provider,
            query: trimmed,
            fromSuggestion: fromSuggestion,
            sourceContext: sourceContext,
          ),
          onError: (Object _) => _trackSearchSubmitted(
            provider: SearchProviderValue.wallhaven,
            query: trimmed,
            fromSuggestion: fromSuggestion,
            sourceContext: sourceContext,
          ),
        ),
      );
    }
    if (trimmed.isNotEmpty) {
      unawaited(_recents.add(trimmed).then((recents) => mounted ? setState(() => _recentSearches = recents) : null));
    }
  }

  void _backToDiscover() {
    setState(() {
      isSubmitted = false;
      _search = null;
      if (_submittedQuery.isEmpty) _filters = _filters.copyWith(clearColor: true);
    });
    _discoveryBloc.add(const SearchDiscoveryEvent.fetchRequested());
  }

  Future<void> _openFilters() async {
    final SearchFilters? picked = await showSearchFilterSheet(context, _filters);
    if (picked == null || picked == _filters || !mounted) return;
    setState(() => _filters = picked);
    final String query = (isSubmitted ? _submittedQuery : searchController.text).trim();
    if (query.isEmpty && picked.color == null) {
      if (isSubmitted) _backToDiscover();
    } else if (isSubmitted || query.isEmpty) {
      _triggerSearch(query);
    }
  }

  void _searchByColor(PrismPaletteColor color) {
    searchController.clear();
    setState(() => _filters = _filters.copyWith(color: color));
    _triggerSearch('', sourceContext: 'search_color');
  }

  void _clearColor() {
    setState(() => _filters = _filters.copyWith(clearColor: true));
    if (_submittedQuery.isEmpty) {
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
    pendingTagSearch.addListener(_consumePendingTag);
    if (pendingTagSearch.value != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _consumePendingTag());
    }
  }

  @override
  void dispose() {
    pendingTagSearch.removeListener(_consumePendingTag);
    searchController.dispose();
    _focus.dispose();
    unawaited(_discoveryBloc.close());
    super.dispose();
  }

  Widget _header() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const PrismHeader(title: 'Search', showBack: false),
        Padding(
          padding: const EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.xxs, PrismSpace.xs, PrismSpace.sm),
          child: Row(
            children: <Widget>[
              Expanded(
                child: PrismSearchField(
                  key: _fieldKey,
                  controller: searchController,
                  focusNode: _focus,
                  hint: 'Search wallpapers',
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
              Badge(
                isLabelVisible: _filters != const SearchFilters(),
                smallSize: 8,
                alignment: AlignmentDirectional.topEnd,
                offset: const Offset(-8, 8),
                child: PrismIconButton(icon: Icons.tune_rounded, tooltip: 'Filters', onPressed: _openFilters),
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
          return const LoadingCards(useFeedLayout: true);
        }
        if (snapshot.hasError) {
          return RefreshableGlintState(
            kind: GlintStateKind.error,
            title: "Couldn't search right now",
            body: 'Check your connection and try again.',
            actionLabel: 'Try again',
            onAction: () => _triggerSearch(_submittedQuery),
            onRefresh: () async => _triggerSearch(_submittedQuery),
          );
        }
        final WallpaperSearchPage? page = snapshot.data;
        if (page == null) {
          return const LoadingCards(useFeedLayout: true);
        }
        if (page.results.isEmpty && page.prismResults.isEmpty) {
          final bool filtered = _filters != const SearchFilters();
          return GlintState(
            kind: GlintStateKind.empty,
            title: _submittedQuery.isEmpty
                ? 'No ${_filters.color?.name.toLowerCase()} wallpapers found'
                : 'No wallpapers found for "$_submittedQuery"',
            body: filtered ? 'Try fewer filters.' : 'Try a shorter or a different word.',
            actionLabel: filtered ? 'Reset filters' : null,
            onAction: filtered ? _resetFilters : null,
          );
        }
        return SearchGrid(
          key: ValueKey<Future<WallpaperSearchPage>?>(_search),
          query: _submittedQuery,
          provider: page.provider,
          initialResults: page.results,
          prismResults: page.prismResults,
          filters: _filters,
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
                      _header(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(PrismSpace.page, 0, PrismSpace.page, PrismSpace.xs),
                        child: Row(
                          children: <Widget>[
                            if (_submittedQuery.isNotEmpty)
                              Expanded(
                                child: Text(
                                  'Results for "$_submittedQuery"',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: PrismTextStyles.caption(context),
                                ),
                              ),
                            if (_filters.color != null)
                              Tooltip(
                                message: 'Clear colour',
                                child: PrismChip(
                                  label: _filters.color!.name,
                                  selected: true,
                                  leading: _ColourDot(_filters.color!.color),
                                  onTap: _clearColor,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Expanded(child: _results(context)),
                    ],
                  )
                : SearchDiscoveryWidget(
                    header: _header(),
                    tags: curatedSearchTags,
                    selectedTag: searchController.text,
                    recentSearches: _recentSearches,
                    onClearRecents: () => unawaited(_clearRecents()),
                    onColorPressed: _searchByColor,
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
