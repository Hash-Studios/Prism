import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/user_search/biz/bloc/search_discovery_bloc.j.dart';
import 'package:Prism/features/user_search/data/wallpaper_search_service.dart';
import 'package:Prism/features/user_search/views/widgets/prism_search_field.dart';
import 'package:Prism/features/user_search/views/widgets/search_discovery_widget.dart';
import 'package:Prism/features/user_search/views/widgets/search_grid.dart';
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
  /// Most searched first. The order is fixed so the row is easy to scan.
  static const List<String> tags = <String>[
    'Anime',
    'Abstract',
    'Nature',
    'Space',
    'Minimalism',
    'Cars',
    'Night',
    'Mountains',
    'Cyber',
    'Landscapes',
    'Art',
    'Games',
    'Fantasy',
    'Flowers',
    'Beach',
    'Winter',
    'Patterns',
    'Geometry',
    'Comics',
    'Illustrations',
    'Street',
    'Epic',
    'Field',
    'Chocolate',
    'Train',
    'Walking',
    'Food',
    'Design',
    'Love',
    'Wildlife',
    'Stock',
    'Trees',
    'Planets',
    'Ninja',
    'Summer',
    'Titan',
    'White',
    '8bit',
    'Fashion',
    'Fitness',
    'Fruits',
    'Futuristic',
    'Gems',
    'Graffiti',
    'Halloween',
    'Hipster',
    'Holidays',
    'Industry',
    'Interiors',
    'Kids',
    'Macro',
    'People',
    'Plants',
    'Portraits',
    'Retro',
    'Robots',
    'Science',
    'Sports',
    'Technics',
    'Textures',
    'Transport',
    'Travel',
    'Wedding',
    'Zombies',
    'Cute',
    'Fairy',
    'Fairytale',
    'Funny',
    'Geometric',
    'Graphic',
  ];

  final TextEditingController searchController = TextEditingController();
  final FocusNode _focus = FocusNode();
  final GlobalKey _fieldKey = GlobalKey();
  Future<WallpaperSearchPage>? _search;
  String _submittedQuery = '';
  bool isSubmitted = false;

  int _queryWordCount(String query) {
    return query.trim().split(RegExp(r'\s+')).where((segment) => segment.trim().isNotEmpty).length;
  }

  void _trackSearchSubmitted({required String query, required bool fromSuggestion, required String sourceContext}) {
    final String trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) return;
    analytics.track(
      SearchSubmittedEvent(
        provider: SearchProviderValue.wallhaven,
        queryLength: trimmedQuery.length,
        queryWordCount: _queryWordCount(trimmedQuery),
        sourceContext: sourceContext,
        fromSuggestion: fromSuggestion,
      ),
    );
  }

  void _triggerSearch(String query) {
    setState(() {
      isSubmitted = true;
      _submittedQuery = query;
      _search = getIt<WallpaperSearchService>().search(query);
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    _focus.dispose();
    super.dispose();
  }

  Widget _header() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const PrismHeader(title: 'Search', showBack: false),
        Padding(
          padding: const EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.xxs, PrismSpace.page, PrismSpace.sm),
          child: PrismSearchField(
            key: _fieldKey,
            controller: searchController,
            focusNode: _focus,
            hint: 'Search wallpapers',
            onChanged: (text) {
              if (text.trim().isEmpty && isSubmitted) {
                setState(() => isSubmitted = false);
              }
            },
            onSubmitted: (text) {
              final String query = text.trim();
              if (query.isEmpty) return;
              _trackSearchSubmitted(query: query, fromSuggestion: false, sourceContext: 'search_textfield');
              _triggerSearch(query);
            },
          ),
        ),
      ],
    );
  }

  Widget _results(BuildContext context) {
    return FutureBuilder<WallpaperSearchPage>(
      future: _search,
      builder: (context, snapshot) {
        final WallpaperSearchPage? page = snapshot.data;
        if (snapshot.hasError) {
          return GlintState(
            kind: GlintStateKind.error,
            title: "Couldn't search wallpapers",
            body: 'Check your connection and try again.',
            actionLabel: 'Try again',
            onAction: () => _triggerSearch(_submittedQuery),
          );
        }
        if (page == null) {
          return const LoadingCards();
        }
        if (page.results.isEmpty) {
          return const GlintState(
            kind: GlintStateKind.empty,
            title: 'No wallpapers found',
            body: 'Try a shorter or a different word.',
          );
        }
        return SearchGrid(
          key: ValueKey<Future<WallpaperSearchPage>?>(_search),
          query: _submittedQuery,
          provider: page.provider,
          initialResults: page.results,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        bottom: false,
        child: BlocProvider<SearchDiscoveryBloc>(
          create: (_) => getIt<SearchDiscoveryBloc>()..add(const SearchDiscoveryEvent.fetchRequested()),
          child: isSubmitted
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _header(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(PrismSpace.page, 0, PrismSpace.page, PrismSpace.xs),
                      child: Text(
                        'Results for "$_submittedQuery"',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: PrismTextStyles.caption(context),
                      ),
                    ),
                    Expanded(child: _results(context)),
                  ],
                )
              : SearchDiscoveryWidget(
                  header: _header(),
                  tags: tags,
                  selectedTag: searchController.text,
                  onTagPressed: (tag) {
                    analytics.track(
                      SearchTagSelectedEvent(provider: SearchProviderValue.wallhaven, tag: tag.toLowerCase()),
                    );
                    _trackSearchSubmitted(query: tag, fromSuggestion: true, sourceContext: 'search_tag');
                    searchController.text = tag;
                    _triggerSearch(tag);
                  },
                ),
        ),
      ),
    );
  }
}
