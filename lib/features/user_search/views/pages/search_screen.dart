import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/widgets/glint/glint_state.dart';
import 'package:Prism/core/widgets/home/refreshable_glint_state.dart';
import 'package:Prism/core/widgets/home/wallpapers/loading.dart';
import 'package:Prism/features/user_search/biz/bloc/search_discovery_bloc.j.dart';
import 'package:Prism/features/user_search/data/recent_searches_store.dart';
import 'package:Prism/features/user_search/data/search_filters.dart';
import 'package:Prism/features/user_search/data/search_tags.dart';
import 'package:Prism/features/user_search/data/wallpaper_search_service.dart';
import 'package:Prism/features/user_search/views/widgets/search_discovery_widget.dart';
import 'package:Prism/features/user_search/views/widgets/search_filter_sheet.dart';
import 'package:Prism/features/user_search/views/widgets/search_grid.dart';
import 'package:Prism/features/wallpaper_detail/biz/tag_search_launcher.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
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
  late final RecentSearchesStore _recents = RecentSearchesStore(getIt<SettingsLocalDataSource>());
  late List<String> _recentSearches = _recents.read();
  // One bloc for the screen, so "Trending right now" does not reload each time the user returns from a search.
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
    if (trimmed.isEmpty) return;
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
    unawaited(_recents.add(trimmed).then((recents) => mounted ? setState(() => _recentSearches = recents) : null));
  }

  void _backToDiscover() {
    setState(() {
      isSubmitted = false;
      _search = null;
    });
    _discoveryBloc.add(const SearchDiscoveryEvent.fetchRequested());
  }

  void _clearQuery() {
    searchController.clear();
    if (isSubmitted) {
      _backToDiscover();
    } else {
      setState(() {});
    }
  }

  Future<void> _openFilters() async {
    final SearchFilters? picked = await showSearchFilterSheet(context, _filters);
    if (picked == null || picked == _filters || !mounted) return;
    setState(() => _filters = picked);
    if (isSubmitted) _triggerSearch(_submittedQuery);
  }

  Future<void> _clearRecents() async {
    await _recents.clear();
    if (mounted) setState(() => _recentSearches = const <String>[]);
  }

  void _resetFilters() {
    setState(() => _filters = const SearchFilters());
    _triggerSearch(_submittedQuery);
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
    unawaited(_discoveryBloc.close());
    super.dispose();
  }

  Widget _results() {
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
          return GlintState(
            kind: GlintStateKind.empty,
            title: 'No wallpapers found for "$_submittedQuery"',
            body: _filters == const SearchFilters() ? null : 'Try fewer filters.',
            actionLabel: _filters == const SearchFilters() ? null : 'Reset filters',
            onAction: _resetFilters,
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
    final ThemeData theme = Theme.of(context);
    final TextStyle? fieldStyle = theme.textTheme.headlineSmall?.copyWith(
      fontFamily: 'Satoshi',
      color: theme.colorScheme.secondary,
    );
    return PopScope(
      canPop: !isSubmitted,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _backToDiscover();
      },
      child: Scaffold(
        backgroundColor: theme.primaryColor,
        appBar: AppBar(
          backgroundColor: theme.primaryColor,
          elevation: 0,
          surfaceTintColor: theme.primaryColor,
          automaticallyImplyLeading: false,
          titleSpacing: 0,
          title: Row(
            children: <Widget>[
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 10, 4, 4),
                  child: TextField(
                    cursorColor: theme.colorScheme.error,
                    style: fieldStyle,
                    controller: searchController,
                    textInputAction: TextInputAction.search,
                    onChanged: (text) {
                      if (text.trim().isEmpty && isSubmitted) {
                        _backToDiscover();
                      } else {
                        setState(() {});
                      }
                    },
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.only(left: 24, top: 12),
                      border: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      hintText: 'Search...',
                      hintStyle: fieldStyle,
                      suffixIcon: searchController.text.isEmpty
                          ? Icon(JamIcons.search, color: theme.colorScheme.secondary)
                          : IconButton(
                              tooltip: 'Clear search',
                              onPressed: _clearQuery,
                              icon: Icon(Icons.close_rounded, color: theme.colorScheme.secondary),
                            ),
                    ),
                    onSubmitted: (tex) {
                      final String query = tex.trim();
                      if (query.isEmpty) return;
                      _triggerSearch(query, sourceContext: 'search_textfield');
                    },
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Filters',
                onPressed: _openFilters,
                icon: Badge(
                  isLabelVisible: _filters != const SearchFilters(),
                  smallSize: 8,
                  child: Icon(Icons.tune_rounded, color: theme.colorScheme.secondary),
                ),
              ),
              const SizedBox(width: 6),
            ],
          ),
        ),
        body: isSubmitted
            ? _results()
            : BlocProvider<SearchDiscoveryBloc>.value(
                value: _discoveryBloc,
                child: SearchDiscoveryWidget(
                  tags: curatedSearchTags,
                  selectedTag: searchController.text,
                  recentSearches: _recentSearches,
                  onClearRecents: () => unawaited(_clearRecents()),
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
    );
  }
}
